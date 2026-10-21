import mongoose, { FilterQuery, ClientSession } from 'mongoose';
import { PlaceModel, IPlace, IPlaceName, IGeoCoordinates } from './place.model';
import { PlaceLevel } from '../../shared/constants';
import { AppError } from '../../shared/errors/AppError';

export interface CreatePlaceRepoData {
  level: PlaceLevel;
  canonicalName: string;
  names: IPlaceName[];
  parentId?: string | null;
  geoCoordinates?: IGeoCoordinates;
  createdBy?: string | null;
}

export interface UpdatePlaceRepoData {
  level?: PlaceLevel;
  canonicalName?: string;
  names?: IPlaceName[];
  parentId?: string | null;
  geoCoordinates?: IGeoCoordinates;
  updatedBy?: string | null;
}

export interface ListPlacesFilter {
  level?: PlaceLevel;
  parentId?: string | null;
  search?: string;
}

export interface PaginationOptions {
  page: number;
  limit: number;
}

export class PlaceRepository {
  /**
   * Executes a unit of work inside a managed MongoDB transaction with session propagation.
   * Automatically handles transaction commit and driver-level transient error retries.
   * Fails explicitly if the deployment does not support transactions (e.g. standalone MongoDB).
   */
  async withTransaction<T>(work: (session: ClientSession) => Promise<T>): Promise<T> {
    const session = await mongoose.startSession();
    try {
      let result: T;
      await session.withTransaction(
        async () => {
          result = await work(session);
        },
        {
          readPreference: 'primary',
          readConcern: { level: 'local' },
          writeConcern: { w: 'majority' },
        }
      );
      return result!;
    } catch (error: any) {
      if (
        error?.code === 20 ||
        error?.codeName === 'IllegalOperation' ||
        (typeof error?.message === 'string' &&
          error.message.includes('Transaction numbers are only allowed on a replica set member or mongos'))
      ) {
        throw new AppError(
          'MongoDB multi-document transactions are not supported by the current deployment. A replica set is required for hierarchy integrity.',
          500,
          'TRANSACTIONS_NOT_SUPPORTED',
          true
        );
      }
      throw error;
    } finally {
      await session.endSession();
    }
  }

  /**
   * Atomically increments the version key (__v) of a document within a transaction session.
   * This acquires an exclusive write lock on the document in WiredTiger, forcing write-conflict
   * detection when concurrent transactions attempt to delete, reparent, or alter its level.
   */
  async touch(id: string, session?: ClientSession): Promise<IPlace | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return null;
    }
    const query = PlaceModel.findByIdAndUpdate(
      id,
      { $inc: { __v: 1 } },
      { new: true }
    );
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async create(data: CreatePlaceRepoData, session?: ClientSession): Promise<IPlace> {
    const canonicalNameLower = data.canonicalName.trim().toLowerCase();
    const parentId =
      data.parentId && mongoose.Types.ObjectId.isValid(data.parentId)
        ? new mongoose.Types.ObjectId(data.parentId)
        : null;
    const createdBy =
      data.createdBy && mongoose.Types.ObjectId.isValid(data.createdBy)
        ? new mongoose.Types.ObjectId(data.createdBy)
        : null;

    const place = new PlaceModel({
      level: data.level,
      canonicalName: data.canonicalName.trim(),
      canonicalNameLower,
      names: data.names,
      parentId,
      geoCoordinates: data.geoCoordinates,
      createdBy,
    });

    return await place.save({ session });
  }

  async findById(id: string, session?: ClientSession): Promise<IPlace | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return null;
    }
    const query = PlaceModel.findById(id);
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async findDuplicate(
    canonicalName: string,
    level: PlaceLevel,
    parentId?: string | null,
    session?: ClientSession
  ): Promise<IPlace | null> {
    const canonicalNameLower = canonicalName.trim().toLowerCase();
    const parentObjectId =
      parentId && mongoose.Types.ObjectId.isValid(parentId)
        ? new mongoose.Types.ObjectId(parentId)
        : null;

    const query = PlaceModel.findOne({
      canonicalNameLower,
      level,
      parentId: parentObjectId,
    });
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async list(
    filter: ListPlacesFilter,
    pagination: PaginationOptions,
    session?: ClientSession
  ): Promise<{ places: IPlace[]; total: number }> {
    const query: FilterQuery<IPlace> = {};

    if (filter.level) {
      query.level = filter.level;
    }

    if (filter.parentId !== undefined) {
      if (filter.parentId === null || filter.parentId === 'null') {
        query.parentId = null;
      } else if (mongoose.Types.ObjectId.isValid(filter.parentId)) {
        query.parentId = new mongoose.Types.ObjectId(filter.parentId);
      }
    }

    if (filter.search) {
      const sanitizedSearch = filter.search.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const searchRegex = new RegExp(sanitizedSearch, 'i');
      query.$or = [
        { canonicalName: searchRegex },
        { 'names.name': searchRegex },
      ];
    }

    const skip = (pagination.page - 1) * pagination.limit;

    const findQuery = PlaceModel.find(query)
      .sort({ canonicalName: 1 })
      .skip(skip)
      .limit(pagination.limit);
    const countQuery = PlaceModel.countDocuments(query);

    if (session) {
      findQuery.session(session);
      countQuery.session(session);
    }

    const [places, total] = await Promise.all([
      findQuery.exec(),
      countQuery.exec(),
    ]);

    return { places, total };
  }

  async findChildren(parentId: string, session?: ClientSession): Promise<IPlace[]> {
    if (!mongoose.Types.ObjectId.isValid(parentId)) {
      return [];
    }
    const query = PlaceModel.find({
      parentId: new mongoose.Types.ObjectId(parentId),
    }).sort({ canonicalName: 1 });
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async countChildren(parentId: string, session?: ClientSession): Promise<number> {
    if (!mongoose.Types.ObjectId.isValid(parentId)) {
      return 0;
    }
    const query = PlaceModel.countDocuments({
      parentId: new mongoose.Types.ObjectId(parentId),
    });
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async update(
    id: string,
    data: UpdatePlaceRepoData,
    session?: ClientSession
  ): Promise<IPlace | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return null;
    }

    const updateFields: Record<string, any> = {};

    if (data.level) updateFields.level = data.level;
    if (data.canonicalName) {
      updateFields.canonicalName = data.canonicalName.trim();
      updateFields.canonicalNameLower = data.canonicalName.trim().toLowerCase();
    }
    if (data.names) updateFields.names = data.names;
    if (data.parentId !== undefined) {
      updateFields.parentId =
        data.parentId && mongoose.Types.ObjectId.isValid(data.parentId)
          ? new mongoose.Types.ObjectId(data.parentId)
          : null;
    }
    if (data.geoCoordinates !== undefined) {
      updateFields.geoCoordinates = data.geoCoordinates;
    }
    if (data.updatedBy && mongoose.Types.ObjectId.isValid(data.updatedBy)) {
      updateFields.updatedBy = new mongoose.Types.ObjectId(data.updatedBy);
    }

    const query = PlaceModel.findByIdAndUpdate(
      id,
      { $set: updateFields },
      { new: true, runValidators: true }
    );
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async delete(id: string, session?: ClientSession): Promise<boolean> {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return false;
    }
    const query = PlaceModel.findByIdAndDelete(id);
    if (session) {
      query.session(session);
    }
    const result = await query.exec();
    return !!result;
  }

  async getAncestors(
    id: string,
    session?: ClientSession
  ): Promise<Array<{ id: string; level: PlaceLevel; canonicalName: string }>> {
    const ancestors: Array<{ id: string; level: PlaceLevel; canonicalName: string }> = [];
    let currentId: string | null = id;
    const visited = new Set<string>();

    while (currentId && !visited.has(currentId) && visited.size < 10) {
      visited.add(currentId);
      const place = await this.findById(currentId, session);
      if (!place) break;

      const parentIdStr = place.parentId ? place.parentId.toString() : null;
      if (parentIdStr) {
        const parentPlace = await this.findById(parentIdStr, session);
        if (parentPlace) {
          const parentObjId = parentPlace._id ? parentPlace._id.toString() : parentPlace.id;
          ancestors.unshift({
            id: parentObjId,
            level: parentPlace.level,
            canonicalName: parentPlace.canonicalName,
          });
          currentId = parentIdStr;
        } else {
          break;
        }
      } else {
        break;
      }
    }

    return ancestors;
  }
}

export const placeRepository = new PlaceRepository();
