import { Response, NextFunction } from 'express';
import { PollService, pollService } from './service';
import { AuthenticatedRequest } from '../../shared/types';
import { AuthenticationError } from '../../shared/errors/AppError';

export class PollController {
  constructor(private readonly service: PollService = pollService) {}

  createPoll = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }
      const body = (req as any).validatedBody || req.body;
      const poll = await this.service.createPoll(req.user.userId, req.user.displayName || 'Anonymous', body);
      res.status(201).json({ data: poll });
    } catch (error) {
      next(error);
    }
  };

  getPollById = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = (req as any).validatedParams || req.params;
      const currentUserId = req.user?.userId;
      const poll = await this.service.getPollById(id, currentUserId);
      res.status(200).json({ data: poll });
    } catch (error) {
      next(error);
    }
  };

  listPolls = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      const query = (req as any).validatedQuery || req.query;
      const result = await this.service.listPolls(query);
      res.status(200).json({ data: result.data, pagination: result.pagination });
    } catch (error) {
      next(error);
    }
  };

  castVote = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError('Authentication required to vote');
      }
      const { id } = (req as any).validatedParams || req.params;
      const body = (req as any).validatedBody || req.body;
      const poll = await this.service.castVote(id, req.user.userId, body);
      res.status(200).json({ data: poll });
    } catch (error) {
      next(error);
    }
  };

  closePoll = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }
      const { id } = (req as any).validatedParams || req.params;
      const poll = await this.service.closePoll(id, req.user.userId, req.user.role);
      res.status(200).json({ data: poll });
    } catch (error) {
      next(error);
    }
  };

  reportPoll = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }
      const { id } = (req as any).validatedParams || req.params;
      const body = (req as any).validatedBody || req.body;
      const result = await this.service.reportPoll(id, req.user.userId, body);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };

  moderatePoll = async (req: AuthenticatedRequest, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) {
        throw new AuthenticationError('Authentication required');
      }
      const { id } = (req as any).validatedParams || req.params;
      const body = (req as any).validatedBody || req.body;
      const result = await this.service.moderatePoll(id, req.user.role, body);
      res.status(200).json({ data: result });
    } catch (error) {
      next(error);
    }
  };
}

export const pollController = new PollController();
