import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { env } from '../config/env';
import { getJwtPublicKey } from '../config/keys';
import { AuthenticationError, ServiceUnavailableError, AppError } from '../shared/errors/AppError';
import { AuthenticatedRequest } from '../shared/types';
import { USER_ROLES, UserRole } from '../shared/constants';
import { UserModel } from '../modules/auth/user.model';

export async function authenticate(req: AuthenticatedRequest, _res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next(new AuthenticationError('No token provided'));
  }

  const token = authHeader.split(' ')[1];
  if (!token || !token.trim()) {
    return next(new AuthenticationError('No token provided'));
  }

  // 1. Inspect unverified header for algorithm isolation
  let decodedHeader: jwt.JwtHeader | undefined;
  try {
    const complete = jwt.decode(token, { complete: true });
    if (!complete || typeof complete !== 'object' || !complete.header) {
      return next(new AuthenticationError('Invalid or expired token'));
    }
    decodedHeader = complete.header;
  } catch {
    return next(new AuthenticationError('Invalid or expired token'));
  }

  const alg = decodedHeader?.alg;
  let decodedPayload: any;

  if (alg === 'RS256') {
    try {
      const publicKey = getJwtPublicKey();
      decodedPayload = jwt.verify(token, publicKey, {
        algorithms: ['RS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      });
    } catch {
      return next(new AuthenticationError('Invalid or expired token'));
    }
  } else if (alg === 'HS256') {
    if (env.NODE_ENV === 'production') {
      return next(new AuthenticationError('Invalid or expired token'));
    }

    const fallbackAllowed =
      process.env.JWT_ALLOW_HS256_FALLBACK === 'true' ||
      env.JWT_ALLOW_HS256_FALLBACK === true;

    if (!fallbackAllowed) {
      return next(new AuthenticationError('Invalid or expired token'));
    }

    try {
      decodedPayload = jwt.verify(token, env.JWT_ACCESS_SECRET, {
        algorithms: ['HS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      });
    } catch {
      return next(new AuthenticationError('Invalid or expired token'));
    }
  } else {
    // Unsupported algorithms (e.g., 'none', 'ES256', etc.)
    return next(new AuthenticationError('Invalid or expired token'));
  }

  // 2. Validate and map user identity claims
  const rawUserId = decodedPayload.userId || decodedPayload.sub;
  if (!rawUserId || typeof rawUserId !== 'string' || !rawUserId.trim()) {
    return next(new AuthenticationError('Invalid or expired token'));
  }

  const rawRole = typeof decodedPayload.role === 'string' ? decodedPayload.role.trim() : '';
  const normalizedRole = (rawRole.toUpperCase() in USER_ROLES)
    ? (rawRole.toUpperCase() as UserRole)
    : undefined;

  if (!normalizedRole || !Object.values(USER_ROLES).includes(normalizedRole)) {
    return next(new AuthenticationError('Invalid or expired token'));
  }

  const email = typeof decodedPayload.email === 'string' ? decodedPayload.email.trim() : '';
  const displayName = typeof decodedPayload.displayName === 'string' ? decodedPayload.displayName.trim() : '';

  // 3. Validate tokenVersion JWT claim: must be a finite, non-negative integer
  const rawTokenVersion = decodedPayload.tokenVersion;
  if (
    typeof rawTokenVersion !== 'number' ||
    !Number.isFinite(rawTokenVersion) ||
    !Number.isInteger(rawTokenVersion) ||
    rawTokenVersion < 0
  ) {
    return next(new AuthenticationError('Invalid or expired token'));
  }
  const tokenVersion = rawTokenVersion;

  // 4. Authoritative database user verification (always fails closed)
  if (mongoose.connection.readyState !== 1) {
    return next(new ServiceUnavailableError('Authentication service unavailable'));
  }

  // Expected identity scheme: MongoDB ObjectId. Malformed or non-ObjectId identity fails closed.
  if (!mongoose.Types.ObjectId.isValid(rawUserId.trim())) {
    return next(new AuthenticationError('Invalid or expired token'));
  }

  try {
    const userDoc: any = await UserModel.findById(rawUserId.trim())
      .select('isActive role tokenVersion')
      .lean()
      .exec();

    if (!userDoc) {
      return next(new AuthenticationError('User account not found'));
    }
    if (!userDoc.isActive) {
      return next(new AuthenticationError('User account is disabled'));
    }

    const expectedTokenVersion = userDoc.tokenVersion !== undefined ? userDoc.tokenVersion : 1;
    if (tokenVersion !== expectedTokenVersion) {
      return next(new AuthenticationError('Token has been revoked'));
    }

    // Role synchronization: use active DB role if present
    req.user = {
      userId: rawUserId.trim(),
      email,
      role: userDoc.role || normalizedRole,
      displayName,
      tokenVersion: expectedTokenVersion,
    };
    return next();
  } catch (err) {
    if (err instanceof AppError) {
      return next(err);
    }
    return next(new ServiceUnavailableError('Authentication service unavailable'));
  }
}
