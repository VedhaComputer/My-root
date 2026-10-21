import { Request } from 'express';
import { ClientSession } from 'mongoose';
import { PlaceRepository, placeRepository } from './repository';
import { PlaceGatewayService, placeGatewayService } from './gateway';
import { CreatePlaceInput, UpdatePlaceInput, QueryPlacesInput } from './validation';
import { PLACE_LEVELS, PlaceLevel } from '../../shared/constants';
import {
  NotFoundError,
  ConflictError,
  BusinessRuleError,
} from '../../shared/errors/AppError';
import { IPlace } from './place.model';

export const ALLOWED_PARENT_LEVELS: Record<PlaceLevel, PlaceLevel[]> = {
  [PLACE_LEVELS.COUNTRY]: [],
  [PLACE_LEVELS.STATE]: [PLACE_LEVELS.COUNTRY],
  [PLACE_LEVELS.DISTRICT]: [PLACE_LEVELS.STATE],
  [PLACE_LEVELS.TEHSIL]: [PLACE_LEVELS.DISTRICT],
  [PLACE_LEVELS.CITY_TOWN]: [PLACE_LEVELS.TEHSIL],
  [PLACE_LEVELS.VILLAGE]: [PLACE_LEVELS.TEHSIL],
};

export interface PlacePathItem {
  id: string;
  level: PlaceLevel;
  canonicalName: string;
}

export interface PlaceDetailResult {
  id: string;
  level: PlaceLevel;
  canonicalName: string;
  names: Array<{ language: string; name: string }>;
  parentId: string | null;
  parentPath: PlacePathItem[];
  geoCoordinates?: { lat: number; lng: number };
  createdAt?: string;
  updatedAt?: string;
}

export class PlaceService {
  private repo: PlaceRepository;
  private gateway: PlaceGatewayService;

  constructor(
    repo: PlaceRepository = placeRepository,
    gateway: PlaceGatewayService = placeGatewayService
  ) {
    this.repo = repo;
    this.gateway = gateway;
  }

  async createPlace(
    input: CreatePlaceInput,
    userId?: string
  ): Promise<PlaceDetailResult> {
    return await this.repo.withTransaction(async (session: ClientSession) => {
      await this.validateHierarchyAndLockParent(input.level as PlaceLevel, input.parentId ?? null, session);

      const existing = await this.repo.findDuplicate(
        input.canonicalName,
        input.level as PlaceLevel,
        input.parentId ?? null,
        session
      );
      if (existing) {
        throw new ConflictError(
          'A place with this canonical name already exists at this level under the same parent'
        );
      }

      const created = await this.repo.create(
        {
          level: input.level as PlaceLevel,
          canonicalName: input.canonicalName,
          names: input.names,
          parentId: input.parentId ?? null,
          geoCoordinates: input.geoCoordinates,
          createdBy: userId ?? null,
        },
        session
      );

      const placeId = created._id ? created._id.toString() : created.id;
      return await this.getPlaceById(placeId, session);
    });
  }

  async getPlaceById(id: string, session?: ClientSession, req?: Request): Promise<PlaceDetailResult> {
    const place = await this.repo.findById(id, session);
    if (place) {
      const placeId = place._id ? place._id.toString() : place.id;
      const parentPath = await this.repo.getAncestors(placeId, session);
      const parentIdStr = place.parentId ? place.parentId.toString() : null;

      return {
        id: placeId,
        level: place.level,
        canonicalName: place.canonicalName,
        names: (place.names || []).map((n) => ({ language: n.language, name: n.name })),
        parentId: parentIdStr,
        parentPath,
        geoCoordinates: place.geoCoordinates,
        createdAt: place.createdAt ? place.createdAt.toISOString() : undefined,
        updatedAt: place.updatedAt ? place.updatedAt.toISOString() : undefined,
      };
    }

    if (this.gateway.isProxyEnabled()) {
      try {
        const response = await this.gateway.executeProxy('GET', `/places/${encodeURIComponent(id)}`, req);
        if (response && response.status === 200 && response.body?.data) {
          const data = response.body.data;
          return {
            id: data.id || data._id || id,
            level: data.level,
            canonicalName: data.canonicalName,
            names: (data.names || []).map((n: any) => ({ language: n.language, name: n.name })),
            parentId: data.parentId ?? null,
            parentPath: (data.parentPath || []).map((p: any) => ({
              id: p.id || p._id,
              level: p.level,
              canonicalName: p.canonicalName,
            })),
            geoCoordinates: data.geoCoordinates,
            createdAt: data.createdAt,
            updatedAt: data.updatedAt,
          };
        }
      } catch {
        // upstream lookup failed
      }
    }

    throw new NotFoundError('Place');
  }

  async listPlaces(query: QueryPlacesInput): Promise<{
    data: IPlace[];
    pagination: { page: number; limit: number; total: number; pages: number };
  }> {
    const page = typeof query.page === 'number' ? query.page : Math.max(1, parseInt(String(query.page || '1'), 10) || 1);
    const limit = typeof query.limit === 'number' ? query.limit : Math.min(100, Math.max(1, parseInt(String(query.limit || '20'), 10) || 20));

    const { places, total } = await this.repo.list(
      {
        level: query.level as PlaceLevel | undefined,
        parentId: query.parentId,
        search: query.search,
      },
      { page, limit }
    );

    const pages = Math.ceil(total / limit) || 1;

    return {
      data: places,
      pagination: {
        page,
        limit,
        total,
        pages,
      },
    };
  }

  async getChildren(parentId: string): Promise<IPlace[]> {
    const parent = await this.repo.findById(parentId);
    if (!parent) {
      throw new NotFoundError('Parent place');
    }
    return await this.repo.findChildren(parentId);
  }

  async updatePlace(
    id: string,
    input: UpdatePlaceInput,
    userId?: string
  ): Promise<PlaceDetailResult> {
    return await this.repo.withTransaction(async (session: ClientSession) => {
      // 1. Touch place being updated to acquire write lock
      const place = await this.repo.touch(id, session);
      if (!place) {
        throw new NotFoundError('Place');
      }

      const targetLevel = (input.level as PlaceLevel) || place.level;
      const targetParentId =
        input.parentId !== undefined
          ? input.parentId
          : place.parentId
          ? place.parentId.toString()
          : null;

      // Validate self-parenting
      if (targetParentId && targetParentId === id) {
        throw new BusinessRuleError('A place cannot be its own parent');
      }

      // Cycle detection if parent changed
      if (targetParentId) {
        await this.detectCycle(id, targetParentId, session);
      }

      // Validate hierarchy level rules and lock new parent if specified
      if (targetLevel === PLACE_LEVELS.COUNTRY) {
        if (targetParentId) {
          throw new BusinessRuleError('A country cannot have a parent place');
        }
      } else {
        if (!targetParentId) {
          throw new BusinessRuleError(
            `Places of level ${targetLevel} must specify a valid parent place`
          );
        }
        // Touch target parent to acquire write lock against concurrent deletion/level change
        const targetParent = await this.repo.touch(targetParentId, session);
        if (!targetParent) {
          throw new NotFoundError('Parent place');
        }
        const allowedParents = ALLOWED_PARENT_LEVELS[targetLevel];
        if (!allowedParents.includes(targetParent.level)) {
          throw new BusinessRuleError(
            `Invalid hierarchy: a place of level '${targetLevel}' cannot have a parent of level '${targetParent.level}'. Allowed parent level(s): ${allowedParents.join(', ')}`
          );
        }
      }

      // Validate that changing level does not invalidate existing children
      if (input.level && input.level !== place.level) {
        const children = await this.repo.findChildren(id, session);
        for (const child of children) {
          const allowedParents = ALLOWED_PARENT_LEVELS[child.level];
          if (!allowedParents.includes(targetLevel)) {
            throw new BusinessRuleError(
              `Cannot change place level to '${targetLevel}': existing sub-place '${child.canonicalName}' of level '${child.level}' cannot have a parent of level '${targetLevel}'`
            );
          }
        }
      }

      // Duplicate check within transaction session
      const targetCanonicalName = input.canonicalName || place.canonicalName;
      const existing = await this.repo.findDuplicate(
        targetCanonicalName,
        targetLevel,
        targetParentId,
        session
      );
      if (existing) {
        const existingId = existing._id ? existing._id.toString() : existing.id;
        if (existingId !== id) {
          throw new ConflictError(
            'A place with this canonical name already exists at this level under the same parent'
          );
        }
      }

      await this.repo.update(
        id,
        {
          level: targetLevel,
          canonicalName: input.canonicalName,
          names: input.names,
          parentId: targetParentId,
          geoCoordinates: input.geoCoordinates,
          updatedBy: userId ?? null,
        },
        session
      );

      return await this.getPlaceById(id, session);
    });
  }

  async deletePlace(id: string): Promise<void> {
    await this.repo.withTransaction(async (session: ClientSession) => {
      // 1. Touch and acquire write lock on the place to be deleted
      const place = await this.repo.touch(id, session);
      if (!place) {
        throw new NotFoundError('Place');
      }

      // 2. Count children within transaction session
      const childrenCount = await this.repo.countChildren(id, session);
      if (childrenCount > 0) {
        throw new BusinessRuleError(
          'Cannot delete place: sub-places exist under this place'
        );
      }

      // 3. Delete within transaction session
      await this.repo.delete(id, session);
    });
  }

  private async validateHierarchyAndLockParent(
    level: PlaceLevel,
    parentId: string | null,
    session?: ClientSession
  ): Promise<void> {
    const allowedParents = ALLOWED_PARENT_LEVELS[level];

    if (level === PLACE_LEVELS.COUNTRY) {
      if (parentId) {
        throw new BusinessRuleError('A country cannot have a parent place');
      }
      return;
    }

    // Non-country levels require a valid parent
    if (!parentId) {
      throw new BusinessRuleError(`Places of level ${level} must specify a valid parent place`);
    }

    // Touch the parent to acquire a write intent lock within the transaction session.
    // This forces write-conflict detection in WiredTiger if concurrent deletion/reparenting occurs.
    const parent = await this.repo.touch(parentId, session);
    if (!parent) {
      throw new NotFoundError('Parent place');
    }

    if (!allowedParents.includes(parent.level)) {
      throw new BusinessRuleError(
        `Invalid hierarchy: a place of level '${level}' cannot have a parent of level '${parent.level}'. Allowed parent level(s): ${allowedParents.join(', ')}`
      );
    }
  }

  private async detectCycle(
    placeId: string,
    newParentId: string,
    session?: ClientSession
  ): Promise<void> {
    let current: string | null = newParentId;
    const visited = new Set<string>();

    while (current && !visited.has(current) && visited.size < 15) {
      if (current === placeId) {
        throw new BusinessRuleError(
          'Cycle detected in place hierarchy: cannot set a descendant as parent'
        );
      }
      visited.add(current);
      const parentDoc = await this.repo.findById(current, session);
      if (!parentDoc || !parentDoc.parentId) {
        break;
      }
      current = parentDoc.parentId.toString();
    }
  }
}

export const placeService = new PlaceService();
