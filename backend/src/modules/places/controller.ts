import { Request, Response, NextFunction } from 'express';
import { PlaceService, placeService } from './service';
import { PlaceGatewayService, placeGatewayService } from './gateway';
import { placeAttributeRepository, PlaceAttributeRepository } from './placeAttribute.repository';
import { placeProgressService, PlaceProgressService } from './placeProgress.service';
import { AuthenticatedRequest } from '../../shared/types';

export class PlaceController {
  private service: PlaceService;
  private gateway: PlaceGatewayService;
  private attrRepo: PlaceAttributeRepository;
  private progressService: PlaceProgressService;

  constructor(
    service: PlaceService = placeService,
    gateway: PlaceGatewayService = placeGatewayService,
    attrRepo: PlaceAttributeRepository = placeAttributeRepository,
    progressService: PlaceProgressService = placeProgressService
  ) {
    this.service = service;
    this.gateway = gateway;
    this.attrRepo = attrRepo;
    this.progressService = progressService;
  }

  listPlaces = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    if (this.gateway.isProxyEnabled()) {
      return this.gateway.listPlaces(req, res, next);
    }
    try {
      const query = (req as any).validatedQuery || req.query;
      const result = await this.service.listPlaces(query);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  getPlaceById = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    if (this.gateway.isProxyEnabled()) {
      return this.gateway.getPlaceById(req, res, next);
    }
    try {
      const { id } = req.params;
      const result = await this.service.getPlaceById(id);
      res.status(200).json({ data: result, ...result });
    } catch (error) {
      next(error);
    }
  };

  getChildren = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    if (this.gateway.isProxyEnabled()) {
      return this.gateway.getChildren(req, res, next);
    }
    try {
      const { id } = req.params;
      const result = await this.service.getChildren(id);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  createPlace = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    if (this.gateway.isProxyEnabled()) {
      return this.gateway.createPlace(req, res, next);
    }
    try {
      const result = await this.service.createPlace(req.body, req.user?.userId);
      res.status(201).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  updatePlace = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    if (this.gateway.isProxyEnabled()) {
      return this.gateway.updatePlace(req, res, next);
    }
    try {
      const { id } = req.params;
      const result = await this.service.updatePlace(id, req.body, req.user?.userId);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  deletePlace = async (
    _req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    if (this.gateway.isProxyEnabled()) {
      return this.gateway.deletePlace(_req, res, next);
    }
    try {
      const { id } = _req.params;
      await this.service.deletePlace(id);
      res.status(200).json({ message: 'Place deleted successfully' });
    } catch (error) {
      next(error);
    }
  };

  getPlaceAttributes = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { id } = req.params;
      const rawCategory = (req as any).validatedQuery?.category ?? req.query.category;
      const safeCategory =
        typeof rawCategory === 'string' && /^[a-zA-Z0-9_-]+$/.test(rawCategory)
          ? rawCategory
          : undefined;

      const user = (req as AuthenticatedRequest).user ?? null;
      const attributes = await this.attrRepo.findByPlaceId(id, safeCategory, user);
      res.status(200).json({ data: attributes });
    } catch (error) {
      next(error);
    }
  };

  addPlaceAttribute = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { id } = req.params;
      const attribute = await this.attrRepo.create({
        ...req.body,
        placeId: id,
        submittedBy: req.user!.userId,
        userRole: req.user?.role,
      });
      res.status(201).json({ data: attribute });
    } catch (error) {
      next(error);
    }
  };

  correctPlaceAttribute = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { attrId } = req.params;
      const attribute = await this.attrRepo.correctAttribute(
        attrId,
        req.body,
        req.user!.userId,
        req.user?.role,
        req.ip
      );
      res.status(200).json({ data: attribute });
    } catch (error) {
      next(error);
    }
  };

  reviewPlaceAttribute = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { attrId } = req.params;
      const { decision, reviewNotes } = req.body;
      const attribute = await this.attrRepo.reviewAttribute(
        attrId,
        decision,
        req.user!.userId,
        req.user!.role,
        reviewNotes
      );
      res.status(200).json({ data: attribute });
    } catch (error) {
      next(error);
    }
  };

  getAttributeHistory = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { attrId } = req.params;
      const history = await this.attrRepo.getAttributeHistory(attrId);
      res.status(200).json({ data: history });
    } catch (error) {
      next(error);
    }
  };

  getPlaceProgress = async (
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { id } = req.params;
      const progress = await this.progressService.calculatePlaceProgress(id, req);
      res.status(200).json({ data: progress });
    } catch (error) {
      next(error);
    }
  };
}

export const placeController = new PlaceController();
