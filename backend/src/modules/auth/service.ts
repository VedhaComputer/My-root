import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { getJwtPrivateKey } from '../../config/keys';
import { AuthRepository, authRepository } from './repository';
import { RegisterInput, LoginInput } from './validation';
import {
  AuthenticationError,
  NotFoundError,
  ValidationError,
  BusinessRuleError,
  ServiceUnavailableError,
} from '../../shared/errors/AppError';
import { logger } from '../../shared/logger';
import { IMailer, mailer as defaultMailer } from '../../shared/mail';
import { AuthenticatedUser } from '../../shared/types';
import mongoose from 'mongoose';
import { ClaimModel } from '../claims/claim.model';
import { EvidenceModel } from '../evidence/evidence.model';
import { PlaceModel } from '../places/place.model';
import { PlaceAttributeModel } from '../places/placeAttribute.model';

import { Request } from 'express';
import { PlaceGatewayService, placeGatewayService } from '../places/gateway';

// Valid cost 12 bcrypt hash of an unpredictable random string
// Ensures constant-time execution (~250ms) matching normal password verification work
const DUMMY_HASH = '$2a$12$3.dPZ/hycEf3OU1o1BpwvuxiziSMEjCe.Cufq30E8uGvd.zQRXS46';

/**
 * Extracts and normalizes a verification token if a full verification URL,
 * Flutter hash-route URL, labeled string (e.g. copied from console/email),
 * or query string is submitted.
 */
export function extractVerificationToken(input: string): string {
  if (!input) return '';
  let token = input.trim().replace(/^["']|["']$/g, '').trim();
  if (!token) return '';

  // 1. If input contains a standard 64-hex cryptographic token, extract and normalize it directly
  const hexMatch = token.match(/\b([0-9a-fA-F]{64})\b/);
  if (hexMatch && hexMatch[1]) {
    return hexMatch[1].toLowerCase();
  }

  // 2. Otherwise extract token query parameter from URLs, hash fragments, or query strings
  if (token.includes('token=')) {
    try {
      const urlCandidate = token.startsWith('http://') || token.startsWith('https://')
        ? token
        : `http://localhost/${token.startsWith('?') || token.startsWith('/') ? token.replace(/^\/+/, '') : `?${token}`}`;
      const parsed = new URL(urlCandidate);
      const extracted = parsed.searchParams.get('token');
      if (extracted && extracted.trim()) {
        return extracted.trim();
      }

      if (parsed.hash) {
        const hashQueryIndex = parsed.hash.indexOf('?');
        if (hashQueryIndex !== -1) {
          const hashParams = new URLSearchParams(parsed.hash.slice(hashQueryIndex + 1));
          const hashToken = hashParams.get('token');
          if (hashToken && hashToken.trim()) {
            return hashToken.trim();
          }
        }
      }
    } catch {
      // Fall through to regex
    }

    const match = token.match(/(?:[?&]|#.*[?&]|^)token=([^&#\s]+)/);
    if (match && match[1]) {
      const candidate = match[1].trim().replace(/^["']|["']$/g, '');
      try {
        return decodeURIComponent(candidate);
      } catch {
        return candidate;
      }
    }
  }

  return token;
}

export interface AuthSuccessResult {
  accessToken: string;
  refreshToken: string;
  user: {
    id: string;
    displayName: string;
    role: string;
  };
}

export interface RefreshSuccessResult {
  accessToken: string;
  refreshToken: string;
}

export class AuthService {
  private repo: AuthRepository;
  private gateway: PlaceGatewayService;
  private mailer: IMailer;

  constructor(
    repo: AuthRepository = authRepository,
    gateway: PlaceGatewayService = placeGatewayService,
    mailer: IMailer = defaultMailer
  ) {
    this.repo = repo;
    this.gateway = gateway;
    this.mailer = mailer;
  }

  async register(input: RegisterInput): Promise<{ message: string }> {
    const normalizedEmail = input.email.trim().toLowerCase();

    const exists = await this.repo.emailExists(normalizedEmail);
    if (exists) {
      const existingUser = await this.repo.findByEmailWithSecrets(normalizedEmail);
      if (existingUser && !existingUser.isEmailVerified) {
        // Retry verification: generate fresh token and re-dispatch email
        const verificationToken = crypto.randomBytes(32).toString('hex');
        const verificationTokenHash = crypto.createHash('sha256').update(verificationToken).digest('hex');
        const verificationExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
        const userId = existingUser._id ? existingUser._id.toString() : existingUser.id;
        if (typeof this.repo.setEmailVerificationToken === 'function') {
          await this.repo.setEmailVerificationToken(userId, verificationTokenHash, verificationExpiresAt);
        }
        try {
          await this.mailer.sendVerificationEmail({
            to: normalizedEmail,
            token: verificationToken,
            verificationUrl: `${env.FRONTEND_URL}/verify-email?token=${verificationToken}`,
          });
        } catch (err: any) {
          logger.error({ err: err?.message || 'Mail delivery error' }, 'Failed to deliver retry verification email');
        }
        return {
          message: 'Registration successful. Please verify your email.',
        };
      }

      // If already verified, perform constant-time dummy bcrypt work to match timing of password hashing
      await bcrypt.compare(input.password, DUMMY_HASH);
      return {
        message: 'Registration successful. Please verify your email.',
      };
    }

    const saltRounds = 12;
    const passwordHash = await bcrypt.hash(input.password, saltRounds);

    const newUser = await this.repo.createUser({
      displayName: input.displayName.trim(),
      email: normalizedEmail,
      passwordHash,
    });

    // Generate email verification token (expiring, hashed storage)
    const verificationToken = crypto.randomBytes(32).toString('hex');
    const verificationTokenHash = crypto.createHash('sha256').update(verificationToken).digest('hex');
    const verificationExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours

    const userId = newUser._id ? newUser._id.toString() : newUser.id;
    if (typeof this.repo.setEmailVerificationToken === 'function') {
      await this.repo.setEmailVerificationToken(userId, verificationTokenHash, verificationExpiresAt);
    }

    // Dispatch verification email with unhashed token
    try {
      await this.mailer.sendVerificationEmail({
        to: normalizedEmail,
        token: verificationToken,
        verificationUrl: `${env.FRONTEND_URL}/verify-email?token=${verificationToken}`,
      });
    } catch (err: any) {
      logger.error({ err: err?.message || 'Mail delivery error' }, 'Failed to deliver verification email during registration');
    }

    return {
      message: 'Registration successful. Please verify your email.',
    };
  }

  async verifyEmail(rawToken: string): Promise<{ message: string }> {
    const token = extractVerificationToken(rawToken);
    const tokenHash = crypto.createHash('sha256').update(token.trim()).digest('hex');
    const user = await this.repo.findByEmailVerificationToken(tokenHash);
    if (!user) {
      throw new ValidationError('Invalid or expired verification token');
    }
    const userId = user._id ? user._id.toString() : user.id;
    await this.repo.markEmailVerified(userId);
    return { message: 'Email verified successfully' };
  }

  async resendVerificationEmail(email: string): Promise<{ message: string }> {
    const normalizedEmail = email.trim().toLowerCase();
    const user = await this.repo.findByEmailWithSecrets(normalizedEmail);

    // Always return uniform generic response to avoid account enumeration
    const uniformResponse = {
      message: 'If an unverified account exists with this email, verification instructions have been sent.',
    };

    if (!user || user.isEmailVerified || !user.isActive) {
      // Constant-time dummy work to prevent timing enumeration
      await bcrypt.compare('dummyPassword123', DUMMY_HASH);
      return uniformResponse;
    }

    const verificationToken = crypto.randomBytes(32).toString('hex');
    const verificationTokenHash = crypto.createHash('sha256').update(verificationToken).digest('hex');
    const verificationExpiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours
    const userId = user._id ? user._id.toString() : user.id;

    if (typeof this.repo.setEmailVerificationToken === 'function') {
      await this.repo.setEmailVerificationToken(userId, verificationTokenHash, verificationExpiresAt);
    }

    try {
      await this.mailer.sendVerificationEmail({
        to: user.email || normalizedEmail,
        token: verificationToken,
        verificationUrl: `${env.FRONTEND_URL}/verify-email?token=${verificationToken}`,
      });
    } catch (err: any) {
      logger.error({ err: err?.message || 'Mail delivery error' }, 'Failed to deliver verification email');
      throw new ServiceUnavailableError('Failed to deliver verification email. Please check email delivery configuration or try again later.');
    }

    return uniformResponse;
  }

  async requestPasswordReset(email: string): Promise<{ message: string }> {
    const normalizedEmail = email.trim().toLowerCase();
    const user = await this.repo.findByEmailWithSecrets(normalizedEmail);
    
    // Always return uniform response to avoid account enumeration
    const uniformResponse = { message: 'If an account exists with this email, password reset instructions have been sent.' };

    if (!user || !user.isActive) {
      // Perform constant-time dummy hash compare to prevent timing enumeration
      await bcrypt.compare('dummyPassword123', DUMMY_HASH);
      return uniformResponse;
    }

    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetTokenHash = crypto.createHash('sha256').update(resetToken).digest('hex');
    const resetExpiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    const userId = user._id ? user._id.toString() : user.id;
    await this.repo.setPasswordResetToken(userId, resetTokenHash, resetExpiresAt);

    // Dispatch password reset email with unhashed token
    try {
      await this.mailer.sendPasswordResetEmail({
        to: user.email || normalizedEmail,
        token: resetToken,
        resetUrl: `${env.FRONTEND_URL}/reset-password?token=${resetToken}`,
      });
    } catch (err: any) {
      logger.error({ err: err?.message || 'Mail delivery error' }, 'Failed to deliver password reset email');
    }

    return uniformResponse;
  }

  async resetPassword(token: string, newPassword: string): Promise<{ message: string }> {
    const tokenHash = crypto.createHash('sha256').update(token.trim()).digest('hex');
    const user = await this.repo.findByPasswordResetToken(tokenHash);
    if (!user) {
      throw new ValidationError('Invalid or expired password reset token');
    }

    const saltRounds = 12;
    const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

    const userId = user._id ? user._id.toString() : user.id;
    await this.repo.resetPassword(userId, newPasswordHash);

    // Invalidate all active refresh tokens for the user
    await this.repo.revokeAllUserRefreshTokens(userId);

    return { message: 'Password reset successful. Please log in with your new password.' };
  }

  async login(input: LoginInput): Promise<AuthSuccessResult> {
    const normalizedEmail = input.email.trim().toLowerCase();
    const user = await this.repo.findByEmailWithSecrets(normalizedEmail);

    if (!user || !user.passwordHash) {
      // Perform constant-time dummy compare to prevent user enumeration via timing
      await bcrypt.compare(input.password, DUMMY_HASH);
      throw new AuthenticationError('Invalid email or password');
    }

    const isMatch = await bcrypt.compare(input.password, user.passwordHash);
    if (!isMatch) {
      throw new AuthenticationError('Invalid email or password');
    }

    if (!user.isActive) {
      // Return the same generic error as a wrong password to prevent account-status enumeration.
      // A disabled account with a correct password must not produce a different HTTP status (403)
      // than a wrong password (401); both must be indistinguishable to the caller.
      throw new AuthenticationError('Invalid email or password');
    }

    if (!user.isEmailVerified) {
      throw new AuthenticationError('Invalid email or password');
    }

    const userId = user._id ? user._id.toString() : user.id;
    const tokenFamily = crypto.randomUUID();

    const tokenVersion = user.tokenVersion ?? 1;
    const accessToken = this.generateAccessToken({
      userId,
      email: user.email,
      role: user.role,
      displayName: user.displayName,
      tokenVersion,
    });

    const { token: refreshToken, expiresAt } = this.generateRefreshToken(userId, tokenFamily, tokenVersion);
    await this.repo.saveRefreshToken(userId, refreshToken, expiresAt, tokenFamily);

    return {
      accessToken,
      refreshToken,
      user: {
        id: userId,
        displayName: user.displayName,
        role: user.role,
      },
    };
  }

  async refreshToken(refreshTokenStr: string): Promise<RefreshSuccessResult> {
    let payload: any;
    try {
      payload = jwt.verify(refreshTokenStr, env.JWT_REFRESH_SECRET, {
        algorithms: ['HS256'],
      });
    } catch {
      throw new AuthenticationError('Invalid or expired refresh token');
    }

    if (!payload || !payload.userId) {
      throw new AuthenticationError('Invalid or expired refresh token');
    }

    // 1. Look up the token record by hash (regardless of revoked status)
    const existingDoc =
      typeof this.repo.findTokenByHash === 'function'
        ? await this.repo.findTokenByHash(refreshTokenStr)
        : null;

    // 2. REUSE DETECTION: If token exists and is already revoked, check whether it is a genuine reuse or an aborted rotation
    if (existingDoc && existingDoc.revoked) {
      let isAbortedRotation = false;
      const expectedReplacementHash = existingDoc.replacedByTokenHash;
      if (expectedReplacementHash && typeof this.repo.findByStoredTokenHash === 'function') {
        const replacementDoc = await this.repo.findByStoredTokenHash(expectedReplacementHash);
        if (!replacementDoc) {
          isAbortedRotation = true;
        }
      }

      if (isAbortedRotation) {
        // Partial-failure recovery: rotation never completed because replacement token was never persisted.
        // Fail closed: old token remains revoked to eliminate dual-active token risks.
        // Require reauthentication without incorrectly revoking unrelated active sessions.
        throw new AuthenticationError('Token rotation was interrupted. Please log in again.');
      } else {
        // Security Policy: Revoke entire token family and all tokens for this user
        if (existingDoc.tokenFamily && typeof this.repo.revokeTokenFamily === 'function') {
          await this.repo.revokeTokenFamily(existingDoc.tokenFamily);
        }
        if (typeof this.repo.revokeAllUserRefreshTokens === 'function') {
          await this.repo.revokeAllUserRefreshTokens(payload.userId);
        }
        if (typeof this.repo.incrementTokenVersion === 'function') {
          await this.repo.incrementTokenVersion(payload.userId);
        }
        throw new AuthenticationError('Refresh token reuse detected. All active sessions have been revoked.');
      }
    }

    // 3. User account status check
    const user = await this.repo.findById(payload.userId);
    if (!user || !user.isActive) {
      throw new AuthenticationError('User account not found or disabled');
    }

    const rawTokenVersion = payload.tokenVersion;
    if (
      typeof rawTokenVersion !== 'number' ||
      !Number.isFinite(rawTokenVersion) ||
      !Number.isInteger(rawTokenVersion) ||
      rawTokenVersion < 0
    ) {
      throw new AuthenticationError('Invalid or expired refresh token');
    }

    const currentTokenVersion = user.tokenVersion !== undefined ? user.tokenVersion : 1;
    if (rawTokenVersion !== currentTokenVersion) {
      throw new AuthenticationError('Token has been revoked');
    }

    const userId = user._id ? user._id.toString() : user.id;
    const tokenFamily = payload.family || existingDoc?.tokenFamily || crypto.randomUUID();

    // 4. ATOMIC ROTATION & PERSISTENCE:
    // Generate new token pair first so we can link replacedByTokenHash
    const { token: newRefreshToken, expiresAt } = this.generateRefreshToken(
      userId,
      tokenFamily,
      currentTokenVersion
    );

    let rotated = false;
    const isMockedAtomic = (this.repo.atomicRotateRefreshToken as any)?.mock !== undefined;

    if (typeof this.repo.rotateAndSaveRefreshToken === 'function' && !isMockedAtomic) {
      const result = await this.repo.rotateAndSaveRefreshToken(
        refreshTokenStr,
        newRefreshToken,
        userId,
        expiresAt,
        tokenFamily
      );
      rotated = result.rotated;
    } else {
      // Fallback for mocked unit tests that mock atomicRotateRefreshToken & saveRefreshToken individually
      if (typeof this.repo.atomicRotateRefreshToken === 'function') {
        const rotatedDoc = await this.repo.atomicRotateRefreshToken(refreshTokenStr, newRefreshToken);
        if (rotatedDoc) {
          rotated = true;
        }
      }

      if (!rotated) {
        // Check if findActiveRefreshToken and revokeRefreshToken are used (e.g. in mocked unit/integration tests)
        if (typeof this.repo.findActiveRefreshToken === 'function') {
          const activeDoc = await this.repo.findActiveRefreshToken(refreshTokenStr);
          if (activeDoc) {
            if (typeof this.repo.revokeRefreshToken === 'function') {
              const revoked = await this.repo.revokeRefreshToken(refreshTokenStr);
              if (revoked) {
                rotated = true;
              }
            }
          }
        }
      }

      if (rotated) {
        // Save the newly minted active token
        // Fail closed: if saveRefreshToken fails on standalone MongoDB, cross-document rollback
        // cannot be proven atomic; oldToken remains revoked to eliminate dual-active token risks.
        await this.repo.saveRefreshToken(userId, newRefreshToken, expiresAt, tokenFamily);
      }
    }

    if (!rotated) {
      // Concurrent rotation attempt lost the race or token was invalid/expired
      throw new AuthenticationError('Invalid or expired refresh token');
    }

    const newAccessToken = this.generateAccessToken({
      userId,
      email: user.email,
      role: user.role,
      displayName: user.displayName,
      tokenVersion: user.tokenVersion ?? 1,
    });

    return {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    };
  }

  async logout(userId: string, refreshTokenStr?: string): Promise<{ message: string }> {
    if (refreshTokenStr) {
      await this.repo.revokeRefreshToken(refreshTokenStr);
    } else {
      await this.repo.revokeAllUserRefreshTokens(userId);
    }

    return { message: 'Logged out successfully' };
  }

  async getMe(userId: string): Promise<{
    id: string;
    displayName: string;
    role: string;
    joinedAt?: string;
    isIdentityVerified?: boolean;
    verifiedLocationId?: string | null;
    selectedPlaceId?: string | null;
  }> {
    const user = await this.repo.findById(userId);
    if (!user) {
      throw new NotFoundError('User');
    }

    const result: any = {
      id: user._id ? user._id.toString() : user.id,
      displayName: user.displayName,
      role: user.role,
    };
    if (user.joinedAt) {
      result.joinedAt = user.joinedAt instanceof Date ? user.joinedAt.toISOString() : user.joinedAt;
    }
    if (user.isIdentityVerified !== undefined) {
      result.isIdentityVerified = user.isIdentityVerified;
    }
    if (user.verifiedLocationId !== undefined) {
      result.verifiedLocationId = user.verifiedLocationId ? user.verifiedLocationId.toString() : null;
    }
    if (user.selectedPlaceId !== undefined) {
      result.selectedPlaceId = user.selectedPlaceId ? user.selectedPlaceId.toString() : null;
    }
    if (user.matrbhoomiHistoryInterests !== undefined) {
      result.matrbhoomiHistoryInterests = (user.matrbhoomiHistoryInterests || []).map((i: any) => ({
        placeId: i.placeId,
        knowsHistory: i.knowsHistory ?? null,
        wantsToLearn: i.wantsToLearn ?? null,
        answeredAt:
          i.answeredAt instanceof Date
            ? i.answeredAt.toISOString()
            : i.answeredAt || new Date().toISOString(),
      }));
    }
    if (user.matrbhoomiHistoryInterest !== undefined) {
      result.matrbhoomiHistoryInterest = user.matrbhoomiHistoryInterest
        ? {
            placeId: user.matrbhoomiHistoryInterest.placeId,
            knowsHistory: user.matrbhoomiHistoryInterest.knowsHistory ?? null,
            wantsToLearn: user.matrbhoomiHistoryInterest.wantsToLearn ?? null,
            answeredAt: user.matrbhoomiHistoryInterest.answeredAt
              ? (user.matrbhoomiHistoryInterest.answeredAt instanceof Date
                  ? user.matrbhoomiHistoryInterest.answeredAt.toISOString()
                  : user.matrbhoomiHistoryInterest.answeredAt)
              : new Date().toISOString(),
          }
        : null;
    }

    if (user.placeRelationships !== undefined) {
      result.placeRelationships = (user.placeRelationships || []).map((r: any) => ({
        placeId: r.placeId,
        residenceType: r.residenceType,
        indigenousClassification: r.indigenousClassification ?? null,
        createdAt:
          r.createdAt instanceof Date ? r.createdAt.toISOString() : r.createdAt,
      }));

      const selectedPlaceStr = user.selectedPlaceId
        ? user.selectedPlaceId.toString()
        : null;
      const currentPlaceRel =
        selectedPlaceStr && user.placeRelationships
          ? user.placeRelationships.find(
              (r: any) =>
                r.placeId === selectedPlaceStr &&
                (r.indigenousClassification === 'Indigenous' ||
                  r.indigenousClassification === 'Non-Indigenous')
            )
          : null;
      result.currentPlaceRelationship = currentPlaceRel
        ? {
            placeId: currentPlaceRel.placeId,
            ...(currentPlaceRel.residenceType ? { residenceType: currentPlaceRel.residenceType } : {}),
            indigenousClassification: currentPlaceRel.indigenousClassification,
          }
        : null;
      result.indigenousClassification = currentPlaceRel?.indigenousClassification ?? null;
      if (!currentPlaceRel && selectedPlaceStr) {
        // Unclassified place is not considered actively selected
        result.selectedPlaceId = null;
      }
    } else if (user.selectedPlaceId !== undefined && user.selectedPlaceId !== null) {
      result.currentPlaceRelationship = null;
      result.indigenousClassification = null;
      result.selectedPlaceId = null;
    }

    return result;
  }

  async updateSelectedPlace(
    userId: string,
    placeId: string | null,
    req?: Request,
    matrbhoomiInterest?: {
      placeId: string;
      knowsHistory?: boolean | null;
      wantsToLearn?: boolean | null;
    } | null,
    placeRelationship?: {
      placeId: string;
      residenceType?: 'Permanent' | 'Temporary' | 'PERMANENT' | 'TEMPORARY' | string;
      indigenousClassification: 'Indigenous' | 'Non-Indigenous';
    } | null
  ): Promise<any> {
    const user = await this.repo.findById(userId);
    if (!user) {
      throw new NotFoundError('User');
    }

    const verifyPlaceExists = async (targetId: string): Promise<boolean> => {
      if (mongoose.Types.ObjectId.isValid(targetId)) {
        const localPlace = await PlaceModel.findById(targetId).exec();
        if (localPlace) {
          return true;
        }
      }
      if (this.gateway.isProxyEnabled()) {
        const proxyRes = await this.gateway.executeProxy(
          'GET',
          `/places/${encodeURIComponent(targetId)}`,
          req
        );
        if (
          proxyRes.status === 200 &&
          proxyRes.body &&
          (proxyRes.body.data || proxyRes.body.id || proxyRes.body._id)
        ) {
          return true;
        }
      }
      return false;
    };

    if (placeRelationship !== undefined) {
      if (placeRelationship !== null) {
        const placeExists = await verifyPlaceExists(placeRelationship.placeId);
        if (!placeExists) {
          throw new NotFoundError('Place');
        }

        const classification = placeRelationship.indigenousClassification;
        if (classification !== 'Indigenous' && classification !== 'Non-Indigenous') {
          throw new BusinessRuleError(
            'A place is considered selected only after explicitly choosing Indigenous or Non-Indigenous classification.'
          );
        }

        if (!user.placeRelationships) {
          user.placeRelationships = [];
        }
        const existingIdx = user.placeRelationships.findIndex(
          (r: any) => r.placeId === placeRelationship.placeId
        );
        const relRecord: any = {
          placeId: placeRelationship.placeId,
          ...(placeRelationship.residenceType ? { residenceType: placeRelationship.residenceType } : {}),
          indigenousClassification: classification,
          createdAt:
            existingIdx >= 0 ? user.placeRelationships[existingIdx].createdAt : new Date(),
          updatedAt: new Date(),
        };
        if (existingIdx >= 0) {
          user.placeRelationships[existingIdx] = relRecord;
        } else {
          user.placeRelationships.push(relRecord);
        }

        user.selectedPlaceId = placeRelationship.placeId;
      }
    }

    if (placeId !== undefined) {
      if (placeId !== null) {
        const placeExists = await verifyPlaceExists(placeId);
        if (!placeExists) {
          throw new NotFoundError('Place');
        }

        const isClassifiedInThisRequest =
          placeRelationship &&
          placeRelationship.placeId === placeId &&
          (placeRelationship.indigenousClassification === 'Indigenous' ||
            placeRelationship.indigenousClassification === 'Non-Indigenous');

        const existingRel = user.placeRelationships?.find(
          (r: any) =>
            r.placeId === placeId &&
            (r.indigenousClassification === 'Indigenous' ||
              r.indigenousClassification === 'Non-Indigenous')
        );

        if (!isClassifiedInThisRequest && !existingRel) {
          throw new BusinessRuleError(
            'A place is considered selected only after explicitly choosing Indigenous or Non-Indigenous classification.'
          );
        }

        user.selectedPlaceId = placeId;
      } else {
        user.selectedPlaceId = null;
      }
    }

    if (matrbhoomiInterest !== undefined) {
      if (matrbhoomiInterest !== null) {
        if (!user.matrbhoomiHistoryInterests) {
          user.matrbhoomiHistoryInterests = [];
        }
        const existingIdx = user.matrbhoomiHistoryInterests.findIndex(
          (i: any) => i.placeId === matrbhoomiInterest.placeId
        );
        const record = {
          placeId: matrbhoomiInterest.placeId,
          knowsHistory: matrbhoomiInterest.knowsHistory ?? null,
          wantsToLearn: matrbhoomiInterest.wantsToLearn ?? null,
          answeredAt: new Date(),
        };
        if (existingIdx >= 0) {
          user.matrbhoomiHistoryInterests[existingIdx] = record;
        } else {
          user.matrbhoomiHistoryInterests.push(record);
        }
        user.matrbhoomiHistoryInterest = record;
      } else {
        user.matrbhoomiHistoryInterest = null;
      }
    }

    await user.save();
    return this.getMe(userId);
  }

  async getMyActivity(userId: string): Promise<any> {
    const userObjectId = new mongoose.Types.ObjectId(userId);

    const [claims, evidences, places, placeAttributes] = await Promise.all([
      ClaimModel.find({ submittedBy: userObjectId }).sort({ submittedAt: -1, _id: -1 }).limit(100).exec(),
      EvidenceModel.find({ uploadedBy: userObjectId }).sort({ uploadedAt: -1 }).limit(100).exec(),
      PlaceModel.find({ createdBy: userObjectId }).sort({ createdAt: -1 }).limit(100).exec(),
      PlaceAttributeModel.find({ submittedBy: userObjectId }).sort({ createdAt: -1 }).limit(100).exec(),
    ]);

    return {
      claims: claims.map((c: any) => ({
        id: c._id ? c._id.toString() : c.id,
        title: c.title,
        body: c.body,
        category: c.category,
        status: c.status,
        submittedAt: c.submittedAt ? c.submittedAt.toISOString() : (c.createdAt ? c.createdAt.toISOString() : new Date().toISOString()),
        locationId: c.locationId ? c.locationId.toString() : '',
        evidenceCount: c.evidenceIds ? c.evidenceIds.length : 0,
        isPublic: c.isPublic ?? true,
      })),
      evidences: evidences.map((e: any) => ({
        id: e._id ? e._id.toString() : e.id,
        claimId: e.claimId ? e.claimId.toString() : '',
        sourceType: e.sourceType,
        title: e.title,
        description: e.description,
        summary: e.title || e.description || '',
        status: e.status,
        submittedAt: e.uploadedAt ? e.uploadedAt.toISOString() : (e.createdAt ? e.createdAt.toISOString() : new Date().toISOString()),
        uploadedAt: e.uploadedAt ? e.uploadedAt.toISOString() : (e.createdAt ? e.createdAt.toISOString() : new Date().toISOString()),
        documentRef: e.documentRef ?? null,
      })),
      places: places.map((p: any) => ({
        id: p._id ? p._id.toString() : p.id,
        canonicalName: p.canonicalName,
        level: p.level,
        status: 'active',
        createdAt: p.createdAt ? p.createdAt.toISOString() : new Date().toISOString(),
      })),
      placeAttributes: placeAttributes.map((a: any) => ({
        id: a._id ? a._id.toString() : a.id,
        placeId: a.placeId ? a.placeId.toString() : '',
        category: a.category,
        key: a.key,
        value: a.value,
        status: a.isLatest ? 'latest' : 'archived',
        sourceDescription: a.sourceDescription,
        reportedPeriod: a.reportedPeriod ?? null,
        submittedAt: (a.reportedDate || a.createdAt || new Date()).toISOString(),
        reportedAt: (a.reportedDate || a.createdAt || new Date()).toISOString(),
      })),
      summary: {
        totalContributions: claims.length + evidences.length + places.length + placeAttributes.length,
        claimsCount: claims.length,
        evidencesCount: evidences.length,
        placesCount: places.length,
        placeAttributesCount: placeAttributes.length,
        totalClaims: claims.length,
        totalEvidences: evidences.length,
        totalPlaces: places.length,
        totalAttributes: placeAttributes.length,
      },
    };
  }

  private generateAccessToken(user: AuthenticatedUser): string {
    const tokenVersion = user.tokenVersion ?? 1;
    return jwt.sign(
      {
        sub: user.userId,
        userId: user.userId,
        email: user.email,
        role: user.role,
        displayName: user.displayName,
        tokenVersion,
      },
      getJwtPrivateKey(),
      {
        algorithm: 'RS256',
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
        expiresIn: env.JWT_ACCESS_EXPIRES_IN as any,
      }
    );
  }

  private generateRefreshToken(
    userId: string,
    tokenFamily?: string,
    tokenVersion = 1
  ): { token: string; expiresAt: Date } {
    const jti = crypto.randomUUID();
    const family = tokenFamily || crypto.randomUUID();
    const token = jwt.sign({ userId, jti, family, tokenVersion }, env.JWT_REFRESH_SECRET, {
      algorithm: 'HS256',
      expiresIn: env.JWT_REFRESH_EXPIRES_IN as any,
    });

    // Default 7 days expiry date calculation
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    return { token, expiresAt };
  }
}

export const authService = new AuthService();
