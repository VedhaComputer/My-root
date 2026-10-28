import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { env } from '../config/env';
import { getJwtPublicKey } from '../config/keys';
import { AuthenticationError, ServiceUnavailableError, AppError } from '../shared/errors/AppError';
import { AuthenticatedRequest } from '../shared/types';
import { USER_ROLES, UserRole } from '../shared/constants';
import { UserModel } from '../modules/auth/user.model';
import { logger, sanitizeCorrelationId } from '../shared/logger';

function logAuthFailure(req: AuthenticatedRequest, category: string, reason: string): void {
  const correlationId = sanitizeCorrelationId(req.headers['x-correlation-id']);
  const hasAuthHeader = Boolean(req.headers.authorization && req.headers.authorization.startsWith('Bearer '));
  logger.warn(
    {
      correlationId,
      path: req.originalUrl || req.path,
      method: req.method,
      hasAuthHeader,
      category,
      reason,
    },
    `[Auth] Authentication rejected: ${category}`
  );
}

export async function authenticate(req: AuthenticatedRequest, _res: Response, next: NextFunction): Promise<void> {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    logAuthFailure(req, 'NO_AUTH_HEADER', 'Missing or non-Bearer authorization header');
    return next(new AuthenticationError('No token provided'));
  }

  const token = authHeader.split(' ')[1];
  if (!token || !token.trim()) {
    logAuthFailure(req, 'EMPTY_TOKEN', 'Token payload is empty');
    return next(new AuthenticationError('No token provided'));
  }

  // 1. Inspect unverified header for algorithm isolation
  let decodedHeader: jwt.JwtHeader | undefined;
  try {
    const complete = jwt.decode(token, { complete: true });
    if (!complete || typeof complete !== 'object' || !complete.header) {
      logAuthFailure(req, 'TOKEN_DECODE_FAILED', 'Failed to decode JWT header structure');
      return next(new AuthenticationError('Invalid or expired token'));
    }
    decodedHeader = complete.header;
  } catch {
    logAuthFailure(req, 'TOKEN_DECODE_FAILED', 'Exception raised while decoding JWT header');
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
      logAuthFailure(req, 'RS256_VERIFICATION_FAILED', 'JWT signature/issuer/audience/expiry validation failed');
      return next(new AuthenticationError('Invalid or expired token'));
    }
  } else if (alg === 'HS256') {
    if (env.NODE_ENV === 'production') {
      logAuthFailure(req, 'HS256_PRODUCTION_DISALLOWED', 'HS256 fallback strictly forbidden in production');
      return next(new AuthenticationError('Invalid or expired token'));
    }

    const fallbackAllowed =
      process.env.JWT_ALLOW_HS256_FALLBACK === 'true' ||
      env.JWT_ALLOW_HS256_FALLBACK === true;

    if (!fallbackAllowed) {
      logAuthFailure(req, 'HS256_FALLBACK_DISALLOWED', 'HS256 algorithm fallback is not enabled');
      return next(new AuthenticationError('Invalid or expired token'));
    }

    try {
      decodedPayload = jwt.verify(token, env.JWT_ACCESS_SECRET, {
        algorithms: ['HS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      });
    } catch {
      logAuthFailure(req, 'HS256_VERIFICATION_FAILED', 'HS256 signature/issuer/audience/expiry validation failed');
      return next(new AuthenticationError('Invalid or expired token'));
    }
  } else {
    // Unsupported algorithms (e.g., 'none', 'ES256', etc.)
    logAuthFailure(req, 'UNSUPPORTED_ALGORITHM', `Token algorithm "${alg}" is unsupported`);
    return next(new AuthenticationError('Invalid or expired token'));
  }

  // 2. Validate and map user identity claims
  const rawUserId = decodedPayload.userId || decodedPayload.sub;
  if (!rawUserId || typeof rawUserId !== 'string' || !rawUserId.trim()) {
    logAuthFailure(req, 'INVALID_USER_ID', 'Token subject/userId claim is missing or empty');
    return next(new AuthenticationError('Invalid or expired token'));
  }

  const rawRole = typeof decodedPayload.role === 'string' ? decodedPayload.role.trim() : '';
  const normalizedRole = (rawRole.toUpperCase() in USER_ROLES)
    ? (rawRole.toUpperCase() as UserRole)
    : undefined;

  if (!normalizedRole || !Object.values(USER_ROLES).includes(normalizedRole)) {
    logAuthFailure(req, 'INVALID_ROLE', 'Token role claim is missing or unrecognized');
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
    logAuthFailure(req, 'INVALID_TOKEN_VERSION', 'Token tokenVersion claim is not a finite non-negative integer');
    return next(new AuthenticationError('Invalid or expired token'));
  }
  const tokenVersion = rawTokenVersion;

  // 4. Authoritative database user verification (always fails closed)
  if (mongoose.connection.readyState !== 1) {
    return next(new ServiceUnavailableError('Authentication service unavailable'));
  }

  // Expected identity scheme: MongoDB ObjectId. Malformed or non-ObjectId identity fails closed.
  if (!mongoose.Types.ObjectId.isValid(rawUserId.trim())) {
    logAuthFailure(req, 'MALFORMED_USER_ID', 'User ID claim is not a valid MongoDB ObjectId');
    return next(new AuthenticationError('Invalid or expired token'));
  }

  try {
    const userDoc: any = await UserModel.findById(rawUserId.trim())
      .select('isActive role tokenVersion selectedPlaceId placeRelationships')
      .lean()
      .exec();

    if (!userDoc) {
      logAuthFailure(req, 'USER_NOT_FOUND', 'User record not found in database');
      return next(new AuthenticationError('User account not found'));
    }
    if (!userDoc.isActive) {
      logAuthFailure(req, 'USER_DISABLED', 'User account is marked inactive');
      return next(new AuthenticationError('User account is disabled'));
    }

    const expectedTokenVersion = userDoc.tokenVersion !== undefined ? userDoc.tokenVersion : 1;
    if (tokenVersion !== expectedTokenVersion) {
      logAuthFailure(req, 'TOKEN_REVOKED', `Token version ${tokenVersion} does not match database version ${expectedTokenVersion}`);
      return next(new AuthenticationError('Token has been revoked'));
    }

    let effectiveSelectedPlaceId: string | null = null;
    let effectiveClassification: string | null = null;

    if (userDoc.selectedPlaceId) {
      const selectedStr = userDoc.selectedPlaceId.toString();
      const rel = Array.isArray(userDoc.placeRelationships)
        ? userDoc.placeRelationships.find((r: any) => r.placeId === selectedStr)
        : null;
      if (
        rel &&
        (rel.indigenousClassification === 'Indigenous' ||
          rel.indigenousClassification === 'Non-Indigenous')
      ) {
        effectiveSelectedPlaceId = selectedStr;
        effectiveClassification = rel.indigenousClassification;
      }
    }

    // Role synchronization: use active DB role if present
    req.user = {
      userId: rawUserId.trim(),
      email,
      role: userDoc.role || normalizedRole,
      displayName,
      tokenVersion: expectedTokenVersion,
      ...(userDoc.selectedPlaceId !== undefined
        ? { selectedPlaceId: effectiveSelectedPlaceId }
        : {}),
      ...(effectiveClassification ? { indigenousClassification: effectiveClassification } : {}),
    };
    return next();
  } catch (err) {
    if (err instanceof AppError) {
      return next(err);
    }
    return next(new ServiceUnavailableError('Authentication service unavailable'));
  }
}
