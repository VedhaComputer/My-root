import { Request, Response, NextFunction } from 'express';
import { AuthService, authService } from './service';
import { AuthenticatedRequest } from '../../shared/types';
import { AuthenticationError } from '../../shared/errors/AppError';

export class AuthController {
  private service: AuthService;

  constructor(service: AuthService = authService) {
    this.service = service;
  }

  register = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const result = await this.service.register(req.body);
      res.status(201).json(result);
    } catch (error) {
      next(error);
    }
  };

  login = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const result = await this.service.login(req.body);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  refreshToken = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { refreshToken } = req.body;
      const result = await this.service.refreshToken(refreshToken);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  verifyEmail = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { token } = req.body;
      const result = await this.service.verifyEmail(token);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  resendVerificationEmail = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email } = req.body;
      const result = await this.service.resendVerificationEmail(email);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  requestPasswordReset = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email } = req.body;
      const result = await this.service.requestPasswordReset(email);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  resetPassword = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { token, newPassword } = req.body;
      const result = await this.service.resetPassword(token, newPassword);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  logout = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const refreshToken = req.body?.refreshToken;
      const result = await this.service.logout(req.user.userId, refreshToken);
      res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  };

  getMe = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const result = await this.service.getMe(req.user.userId);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  getMyActivity = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const result = await this.service.getMyActivity(req.user.userId);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  updateMe = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError();
      }
      const placeId =
        req.body.selectedPlaceId !== undefined ? req.body.selectedPlaceId : req.body.placeId;
      const matrbhoomiInterest = req.body.matrbhoomiHistoryInterest;
      const result = await this.service.updateSelectedPlace(
        req.user.userId,
        placeId,
        req,
        matrbhoomiInterest
      );
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };
}

export const authController = new AuthController();
