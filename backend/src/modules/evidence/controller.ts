import { Response, NextFunction } from 'express';
import { EvidenceService, evidenceService } from './service';
import { AuthenticatedRequest } from '../../shared/types';
import { AuthenticationError, AuthorizationError } from '../../shared/errors/AppError';
import { USER_ROLES } from '../../shared/constants';

export class EvidenceController {
  constructor(private service: EvidenceService = evidenceService) {}

  submitEvidence = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      if (req.user.role !== USER_ROLES.ADMIN) {
        if (req.user.selectedPlaceId === null) {
          throw new AuthorizationError(
            'No place selected. Guest / View-only mode does not allow contributing evidence.'
          );
        }
      }
      const result = await this.service.submitEvidence(req.body, req.user.userId, req.ip);
      res.status(201).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  getEvidenceForClaim = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { claimId } = req.params;
      const result = await this.service.getEvidenceForClaim(claimId, req.user);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  getEvidenceById = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { id } = req.params;
      const result = await this.service.getEvidenceById(id, req.user);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  reviewEvidence = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const { id } = req.params;
      const result = await this.service.reviewEvidence(
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
}

export const evidenceController = new EvidenceController();

