import { Response, NextFunction } from 'express';
import { AuthenticatedRequest } from '../shared/types';
import { UserRole, hasMinimumRole } from '../shared/constants';
import { AuthenticationError, AuthorizationError } from '../shared/errors/AppError';

export function authorize(minimumRole: UserRole) {
  return (req: AuthenticatedRequest, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      return next(new AuthenticationError());
    }
    if (!hasMinimumRole(req.user.role, minimumRole)) {
      return next(new AuthorizationError(`Requires ${minimumRole} role or higher`));
    }
    next();
  };
}
