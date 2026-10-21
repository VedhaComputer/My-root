import { Response, NextFunction } from 'express';
import { ClaimService, claimService } from './service';
import { AuthenticatedRequest } from '../../shared/types';
import { AuthenticationError } from '../../shared/errors/AppError';

export class ClaimController {
  private service: ClaimService;

  constructor(service: ClaimService = claimService) {
    this.service = service;
  }

  listClaims = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const query = (req as any).validatedQuery || req.query;
      const result = await this.service.listClaims(
        query,
        req.user?.userId,
        req.user?.role
      );
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  getReviewQueue = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const query = (req as any).validatedQuery || req.query;
      const result = await this.service.getReviewQueue(
        query,
        req.user.userId,
        req.user.role
      );
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  getClaimById = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { id } = req.params;
      const result = await this.service.getClaimById(
        id,
        req.user?.userId,
        req.user?.role,
        undefined,
        req
      );
      res.status(200).json({ data: result, ...result });
    } catch (error) {
      next(error);
    }
  };

  createClaim = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const result = await this.service.createClaim(req.body, req.user.userId, req);
      res.status(201).json({ data: result, ...result });
    } catch (error) {
      next(error);
    }
  };

  updateClaim = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id } = req.params;
      const result = await this.service.updateClaim(id, req.body, req.user.userId, req);
      res.status(200).json({ data: result, ...result });
    } catch (error) {
      next(error);
    }
  };

  submitClaim = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id } = req.params;
      const result = await this.service.submitClaim(id, req.user.userId, req.ip);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  archiveClaim = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id } = req.params;
      const result = await this.service.archiveClaim(
        id,
        req.user.userId,
        req.user.role,
        req.ip
      );
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  requestCorrection = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id } = req.params;
      const result = await this.service.requestClaimCorrection(
        id,
        req.body,
        req.user.userId,
        req.ip,
        req.user.role
      );
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  reviewCorrection = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id, correctionId } = req.params;
      const result = await this.service.reviewClaimCorrection(
        id,
        correctionId,
        req.body,
        req.user.userId,
        req.user.role,
        req.ip
      );
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  getCorrections = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { id } = req.params;
      const result = await this.service.getClaimCorrections(
        id,
        req.user?.userId,
        req.user?.role
      );
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  verifyConsent = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id } = req.params;
      const result = await this.service.verifyClaimConsent(
        id,
        req.body,
        req.user.userId,
        req.user.role,
        req.ip
      );
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  reviewClaim = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id } = req.params;
      const result = await this.service.reviewClaim(
        id,
        req.body,
        req.user.userId,
        req.user.role,
        req.ip
      );
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };
  submitFeedback = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id } = req.params;
      const result = await this.service.submitHistoryFeedback(
        id,
        req.body,
        req.user.userId,
        req.user.role
      );
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };
}

export const claimController = new ClaimController();

