import { Response, NextFunction } from 'express';
import { VerificationService, verificationService } from './service';
import { AuthenticatedRequest } from '../../shared/types';
import { AuthenticationError } from '../../shared/errors/AppError';

export class VerificationController {
  constructor(private service: VerificationService = verificationService) {}

  submitReview = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const result = await this.service.submitReview(req.body, req.user.userId, req.ip);
      res.status(201).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  getReviewsForClaim = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const { claimId } = req.params;
      const result = await this.service.getReviewsForClaim(claimId, req.user);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };
}

export const verificationController = new VerificationController();
