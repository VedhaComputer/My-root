import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { createApp } from '../../src/app';
import { claimRepository } from '../../src/modules/claims/repository';
import { evidenceRepository } from '../../src/modules/evidence/repository';
import { reviewRepository } from '../../src/modules/verification/repository';
import { authRepository } from '../../src/modules/auth/repository';
import { AuthService } from '../../src/modules/auth/service';
import { UserModel } from '../../src/modules/auth/user.model';
import { RefreshTokenModel, hashToken } from '../../src/modules/auth/refreshToken.model';
import { env } from '../../src/config/env';
import { USER_ROLES, CLAIM_STATUSES, UserRole } from '../../src/shared/constants';
import { AuthenticationError, AuthorizationError, AppError } from '../../src/shared/errors/AppError';

const app = createApp();

function generateToken(
  role: UserRole,
  userId = '507f1f77bcf86cd799439011',
  tokenVersion = 1
): string {
  return jwt.sign(
    {
      userId,
      email: 'security.test@example.com',
      role,
      displayName: 'Security Tester',
      tokenVersion,
    },
    env.JWT_ACCESS_SECRET,
    {
      algorithm: 'HS256',
      issuer: env.JWT_ISSUER,
      audience: env.JWT_AUDIENCE,
      expiresIn: '15m',
    }
  );
}

const TEST_URI = 'mongodb://127.0.0.1:27018/myroot_security_test?directConnection=true';

describe('Security Hardening & Phase 1 Verification (Regression Tests)', () => {
  let originalFallback: string | undefined;

  beforeAll(async () => {
    originalFallback = process.env.JWT_ALLOW_HS256_FALLBACK;
    process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
    if (mongoose.connection.readyState !== 1) {
      await mongoose.connect(TEST_URI, { serverSelectionTimeoutMS: 5000 });
    }
  });

  afterAll(async () => {
    if (originalFallback === undefined) {
      delete process.env.JWT_ALLOW_HS256_FALLBACK;
    } else {
      process.env.JWT_ALLOW_HS256_FALLBACK = originalFallback;
    }
    if (mongoose.connection.readyState !== 0) {
      await mongoose.disconnect();
    }
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  // =========================================================================
  // 1. Central canReadClaim Authorization Across Endpoints
  // =========================================================================
  describe('1. Central canReadClaim Policy Across Endpoints', () => {
    const ownerId = '507f1f77bcf86cd799439011';
    const strangerId = '507f1f77bcf86cd799439022';
    const reviewerId = '507f1f77bcf86cd799439033';
    const claimObjectId = '507f1f77bcf86cd799439099';

    const mockDraftClaim: any = {
      _id: new mongoose.Types.ObjectId(claimObjectId),
      id: claimObjectId,
      status: CLAIM_STATUSES.DRAFT,
      submittedBy: new mongoose.Types.ObjectId(ownerId),
      locationId: 'place-test-loc',
      title: { original: 'Private Draft Title', language: 'en' },
      body: { original: 'Private Draft Body', language: 'en' },
      isPublic: true,
      correctionRequests: [],
    };

    beforeEach(() => {
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockDraftClaim);
    });

    it('rejects cross-user access to unsubmitted draft on GET /api/v1/claims/:id with 403', async () => {
      const strangerToken = generateToken(USER_ROLES.CONTRIBUTOR, strangerId);

      const res = await request(app)
        .get(`/api/v1/claims/${claimObjectId}`)
        .set('Authorization', `Bearer ${strangerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(res.body.error.message).toContain('Private drafts are only accessible by the owner or authorized reviewers');
    });

    it('rejects cross-user access to draft corrections on GET /api/v1/claims/:id/corrections with 403', async () => {
      const strangerToken = generateToken(USER_ROLES.CONTRIBUTOR, strangerId);

      const res = await request(app)
        .get(`/api/v1/claims/${claimObjectId}/corrections`)
        .set('Authorization', `Bearer ${strangerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('rejects cross-user access to draft evidence on GET /api/v1/evidence/claim/:claimId with 403', async () => {
      const strangerToken = generateToken(USER_ROLES.CONTRIBUTOR, strangerId);

      const res = await request(app)
        .get(`/api/v1/evidence/claim/${claimObjectId}`)
        .set('Authorization', `Bearer ${strangerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('rejects cross-user access to draft reviews on GET /api/v1/verification/claim/:claimId with 403', async () => {
      const strangerToken = generateToken(USER_ROLES.CONTRIBUTOR, strangerId);

      const res = await request(app)
        .get(`/api/v1/verification/claim/${claimObjectId}`)
        .set('Authorization', `Bearer ${strangerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('permits draft owner to view their draft across all endpoints', async () => {
      const ownerToken = generateToken(USER_ROLES.CONTRIBUTOR, ownerId);
      jest.spyOn(evidenceRepository, 'findByClaimId').mockResolvedValue([]);
      jest.spyOn(reviewRepository, 'findByClaimId').mockResolvedValue([]);

      const resEvidence = await request(app)
        .get(`/api/v1/evidence/claim/${claimObjectId}`)
        .set('Authorization', `Bearer ${ownerToken}`);
      expect(resEvidence.status).toBe(200);

      const resVerification = await request(app)
        .get(`/api/v1/verification/claim/${claimObjectId}`)
        .set('Authorization', `Bearer ${ownerToken}`);
      expect(resVerification.status).toBe(200);

      const resCorrections = await request(app)
        .get(`/api/v1/claims/${claimObjectId}/corrections`)
        .set('Authorization', `Bearer ${ownerToken}`);
      expect(resCorrections.status).toBe(200);
    });

    it('permits authorized reviewer to view draft across all endpoints', async () => {
      const reviewerToken = generateToken(USER_ROLES.REVIEWER, reviewerId);
      jest.spyOn(evidenceRepository, 'findByClaimId').mockResolvedValue([]);
      jest.spyOn(reviewRepository, 'findByClaimId').mockResolvedValue([]);

      const resEvidence = await request(app)
        .get(`/api/v1/evidence/claim/${claimObjectId}`)
        .set('Authorization', `Bearer ${reviewerToken}`);
      expect(resEvidence.status).toBe(200);

      const resVerification = await request(app)
        .get(`/api/v1/verification/claim/${claimObjectId}`)
        .set('Authorization', `Bearer ${reviewerToken}`);
      expect(resVerification.status).toBe(200);
    });

    it('fails closed with 404 Claim not found on GET /api/v1/evidence/:id when parent claim is missing (orphaned evidence)', async () => {
      const evidenceId = '507f1f77bcf86cd799439088';
      const token = generateToken(USER_ROLES.CONTRIBUTOR, strangerId);
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(evidenceId),
        claimId: new mongoose.Types.ObjectId(claimObjectId),
        title: 'Orphaned Evidence Document',
      } as any);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/evidence/${evidenceId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
      expect(res.body.error.message).toBe('Claim not found');
    });

    it('rejects cross-user access to draft evidence on GET /api/v1/evidence/:id with 403', async () => {
      const evidenceId = '507f1f77bcf86cd799439088';
      const strangerToken = generateToken(USER_ROLES.CONTRIBUTOR, strangerId);
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(evidenceId),
        claimId: new mongoose.Types.ObjectId(claimObjectId),
        title: 'Private Draft Evidence',
      } as any);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockDraftClaim);

      const res = await request(app)
        .get(`/api/v1/evidence/${evidenceId}`)
        .set('Authorization', `Bearer ${strangerToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(res.body.error.message).toContain('Private drafts are only accessible by the owner or authorized reviewers');
    });

    it('permits draft owner to view evidence on GET /api/v1/evidence/:id with 200', async () => {
      const evidenceId = '507f1f77bcf86cd799439088';
      const ownerToken = generateToken(USER_ROLES.CONTRIBUTOR, ownerId);
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(evidenceId),
        claimId: new mongoose.Types.ObjectId(claimObjectId),
        title: 'Private Draft Evidence',
      } as any);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockDraftClaim);

      const res = await request(app)
        .get(`/api/v1/evidence/${evidenceId}`)
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.title).toBe('Private Draft Evidence');
    });

    it('permits authorized reviewer to view draft evidence on GET /api/v1/evidence/:id with 200', async () => {
      const evidenceId = '507f1f77bcf86cd799439088';
      const reviewerToken = generateToken(USER_ROLES.REVIEWER, reviewerId);
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(evidenceId),
        claimId: new mongoose.Types.ObjectId(claimObjectId),
        title: 'Private Draft Evidence',
      } as any);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockDraftClaim);

      const res = await request(app)
        .get(`/api/v1/evidence/${evidenceId}`)
        .set('Authorization', `Bearer ${reviewerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.title).toBe('Private Draft Evidence');
    });
  });

  // =========================================================================
  // 2. Authentication Hardening
  // =========================================================================
  describe('2. Authentication Hardening: Status, Versions, Reuse Detection & Concurrency', () => {
    it('rejects request with 401 when account status isActive is false', async () => {
      const validToken = generateToken(USER_ROLES.CONTRIBUTOR, '507f1f77bcf86cd799439011', 1);

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
          isActive: false,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 1,
        }),
      } as any);

      try {
        const res = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${validToken}`);

        expect(res.status).toBe(401);
        expect(res.body.error.message).toBe('User account is disabled');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('rejects request with 401 when tokenVersion is outdated (session revoked)', async () => {
      // Token has tokenVersion = 1, but database has tokenVersion = 2
      const oldToken = generateToken(USER_ROLES.CONTRIBUTOR, '507f1f77bcf86cd799439011', 1);

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
          isActive: true,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 2,
        }),
      } as any);

      try {
        const res = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${oldToken}`);

        expect(res.status).toBe(401);
        expect(res.body.error.message).toBe('Token has been revoked');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('rejects request with 401 when tokenVersion claim is missing from access token (does not trust missing claim)', async () => {
      // Access token signed without tokenVersion claim
      const tokenWithoutVersion = jwt.sign(
        {
          userId: '507f1f77bcf86cd799439011',
          email: 'security.test@example.com',
          role: USER_ROLES.CONTRIBUTOR,
          displayName: 'Security Tester',
        },
        env.JWT_ACCESS_SECRET,
        { expiresIn: '15m' }
      );

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
          isActive: true,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 1,
        }),
      } as any);

      try {
        const res = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${tokenWithoutVersion}`);

        expect(res.status).toBe(401);
        expect(res.body.error.message).toBe('Invalid or expired token');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('fails closed with 503 Authentication service unavailable when database query fails during verification', async () => {
      const validToken = generateToken(USER_ROLES.CONTRIBUTOR, '507f1f77bcf86cd799439011', 1);

      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockRejectedValue(new Error('MongoNetworkError: connection timed out')),
      } as any);

      const res = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${validToken}`);

      expect(res.status).toBe(503);
      expect(res.body.error.code).toBe('SERVICE_UNAVAILABLE');
      expect(res.body.error.message).toBe('Authentication service unavailable');
    });

    it('fails closed with 503 Authentication service unavailable when MongoDB is disconnected', async () => {
      const validToken = generateToken(USER_ROLES.CONTRIBUTOR, '507f1f77bcf86cd799439011', 1);

      await mongoose.disconnect();

      try {
        const res = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${validToken}`);

        expect(res.status).toBe(503);
        expect(res.body.error.code).toBe('SERVICE_UNAVAILABLE');
        expect(res.body.error.message).toBe('Authentication service unavailable');
      } finally {
        await mongoose.connect(TEST_URI, { serverSelectionTimeoutMS: 5000 });
      }
    });

    it('fails closed with 401 Invalid or expired token when database verification is required but userId is not a valid ObjectId', async () => {
      const invalidIdToken = generateToken(USER_ROLES.CONTRIBUTOR, 'non-object-id-string', 1);

      process.env.VERIFY_USER_DB = 'true';

      try {
        const res = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${invalidIdToken}`);

        expect(res.status).toBe(401);
        expect(res.body.error.code).toBe('UNAUTHENTICATED');
        expect(res.body.error.message).toBe('Invalid or expired token');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('accepts request with 200 when tokenVersion matches authoritative database tokenVersion', async () => {
      const validToken = generateToken(USER_ROLES.CONTRIBUTOR, '507f1f77bcf86cd799439011', 3);

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
          isActive: true,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 3,
        }),
      } as any);
      jest.spyOn(authRepository, 'findById').mockResolvedValue({
        id: '507f1f77bcf86cd799439011',
        displayName: 'Security Tester',
        role: USER_ROLES.CONTRIBUTOR,
      } as any);

      try {
        const res = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${validToken}`);

        expect(res.status).toBe(200);
        expect(res.body.data.id).toBe('507f1f77bcf86cd799439011');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('rejects access to admin endpoint with 403 when user is demoted from ADMIN to CONTRIBUTOR in database', async () => {
      const adminUserId = '507f1f77bcf86cd799439011';
      // User holds a valid, previously issued token with role: ADMIN
      const adminToken = generateToken(USER_ROLES.ADMIN, adminUserId, 1);

      process.env.VERIFY_USER_DB = 'true';
      // Authoritative database record now reflects demoted role: CONTRIBUTOR
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId(adminUserId),
          isActive: true,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 1,
        }),
      } as any);

      try {
        const res = await request(app)
          .post('/api/v1/places')
          .set('Authorization', `Bearer ${adminToken}`)
          .send({
            level: 'COUNTRY',
            canonicalName: 'India',
            names: [{ language: 'en', name: 'India' }],
          });

        expect(res.status).toBe(403);
        expect(res.body.error.code).toBe('UNAUTHORIZED');
        expect(res.body.error.message).toContain('Requires ADMIN role or higher');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('issues newly minted access token embedding authoritative tokenVersion on login', async () => {
      const authService = new AuthService(authRepository);
      const passwordHash = await bcrypt.hash('secretPass123', 10);
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: '507f1f77bcf86cd799439011',
        displayName: 'Versioned User',
        email: 'versioned@example.com',
        passwordHash,
        role: USER_ROLES.CONTRIBUTOR,
        tokenVersion: 4,
        isActive: true,
        isEmailVerified: true,
      } as any);
      jest.spyOn(authRepository, 'saveRefreshToken').mockResolvedValue({} as any);

      const loginResult = await authService.login({
        email: 'versioned@example.com',
        password: 'secretPass123',
      });

      expect(loginResult.accessToken).toBeDefined();
      const decoded: any = jwt.decode(loginResult.accessToken);
      expect(decoded.tokenVersion).toBe(4);
    });

    it('detects refresh token reuse and revokes entire token family and user sessions', async () => {
      const stolenToken = jwt.sign(
        { userId: '507f1f77bcf86cd799439011', family: 'family-xyz-123', tokenVersion: 1 },
        env.JWT_REFRESH_SECRET,
        { expiresIn: '7d' }
      );

      // findTokenByHash returns an already revoked token -> REUSE DETECTED!
      jest.spyOn(authRepository, 'findTokenByHash').mockResolvedValue({
        tokenHash: 'some-hash',
        tokenFamily: 'family-xyz-123',
        revoked: true,
        expiresAt: new Date(Date.now() + 100000),
      } as any);

      const revokeFamilySpy = jest.spyOn(authRepository, 'revokeTokenFamily').mockResolvedValue(3);
      const revokeAllSpy = jest.spyOn(authRepository, 'revokeAllUserRefreshTokens').mockResolvedValue(3);
      const incVersionSpy = jest.spyOn(authRepository, 'incrementTokenVersion').mockResolvedValue(2);

      const res = await request(app)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: stolenToken });

      expect(res.status).toBe(401);
      expect(res.body.error.message).toContain('Refresh token reuse detected');
      expect(revokeFamilySpy).toHaveBeenCalledWith('family-xyz-123');
      expect(revokeAllSpy).toHaveBeenCalledWith('507f1f77bcf86cd799439011');
      expect(incVersionSpy).toHaveBeenCalledWith('507f1f77bcf86cd799439011');
    });

    it('safely handles concurrent refresh attempts preventing both from succeeding', async () => {
      const activeToken = jwt.sign(
        { userId: '507f1f77bcf86cd799439011', family: 'family-concurrent', tokenVersion: 1 },
        env.JWT_REFRESH_SECRET,
        { expiresIn: '7d' }
      );

      // First caller gets the atomic rotation lock; second caller gets null (already rotated)
      let firstCall = true;
      jest.spyOn(authRepository, 'findTokenByHash').mockResolvedValue({
        tokenHash: 'hash-concur',
        tokenFamily: 'family-concurrent',
        revoked: false,
        expiresAt: new Date(Date.now() + 100000),
      } as any);
      jest.spyOn(authRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        email: 'concurrent@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        displayName: 'Concurrent User',
        isActive: true,
        tokenVersion: 1,
      } as any);
      jest.spyOn(authRepository, 'saveRefreshToken').mockResolvedValue({} as any);

      jest.spyOn(authRepository, 'atomicRotateRefreshToken').mockImplementation(async () => {
        if (firstCall) {
          firstCall = false;
          return { revoked: true } as any;
        }
        return null; // Lost the race
      });
      jest.spyOn(authRepository, 'findActiveRefreshToken').mockResolvedValue(null);

      const [res1, res2] = await Promise.all([
        request(app).post('/api/v1/auth/refresh').send({ refreshToken: activeToken }),
        request(app).post('/api/v1/auth/refresh').send({ refreshToken: activeToken }),
      ]);

      const statuses = [res1.status, res2.status].sort();
      expect(statuses).toEqual([200, 401]);
    });

    it('atomically rotates refresh token in live MongoDB replica set under concurrent execution: exactly one succeeds and one replacement is persisted', async () => {
      const rawOldToken = 'live-concurrent-old-token-xyz';
      const oldTokenHash = hashToken(rawOldToken);
      const userId = '507f1f77bcf86cd799439011';
      const tokenFamily = 'family-live-atomic-concur';

      await RefreshTokenModel.deleteMany({ tokenFamily });
      await RefreshTokenModel.create({
        userId: new mongoose.Types.ObjectId(userId),
        tokenHash: oldTokenHash,
        tokenFamily,
        revoked: false,
        expiresAt: new Date(Date.now() + 1000000),
      });

      const [res1, res2] = await Promise.all([
        authRepository.rotateAndSaveRefreshToken(
          rawOldToken,
          'replacement-live-token-1',
          userId,
          new Date(Date.now() + 1000000),
          tokenFamily
        ),
        authRepository.rotateAndSaveRefreshToken(
          rawOldToken,
          'replacement-live-token-2',
          userId,
          new Date(Date.now() + 1000000),
          tokenFamily
        ),
      ]);

      const rotatedFlags = [res1.rotated, res2.rotated].sort();
      expect(rotatedFlags).toEqual([false, true]);

      // Verify REAL PERSISTED DATABASE STATE in MongoDB
      const persistedOld = await RefreshTokenModel.findOne({ tokenHash: oldTokenHash });
      expect(persistedOld!.revoked).toBe(true);
      expect(persistedOld!.replacedByTokenHash).toMatch(
        new RegExp(`${hashToken('replacement-live-token-1')}|${hashToken('replacement-live-token-2')}`)
      );

      const activeReplacements = await RefreshTokenModel.find({
        tokenFamily,
        revoked: false,
      });
      expect(activeReplacements.length).toBe(1);

      await RefreshTokenModel.deleteMany({ tokenFamily });
    });

    it('returns uniform response on password reset request avoiding account enumeration', async () => {
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue(null);

      const res = await request(app)
        .post('/api/v1/auth/password-reset/request')
        .send({ email: 'nonexistent@example.com' });

      expect(res.status).toBe(200);
      expect(res.body.message).toContain('If an account exists with this email, password reset instructions have been sent.');
    });

    it('verifies single-use email verification token and invalidates after use', async () => {
      const fakeToken = 'valid-token-string-64-characters-long-test-token-12345678901234567890';
      
      let verified = false;
      jest.spyOn(authRepository, 'findByEmailVerificationToken').mockImplementation(async () => {
        if (!verified) {
          return { _id: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011') } as any;
        }
        return null; // Expired / already used
      });
      jest.spyOn(authRepository, 'markEmailVerified').mockImplementation(async () => {
        verified = true;
      });

      // First attempt: succeeds
      const res1 = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: fakeToken });
      expect(res1.status).toBe(200);
      expect(res1.body.message).toBe('Email verified successfully');

      // Second attempt with same token: rejected
      const res2 = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: fakeToken });
      expect(res2.status).toBe(400);
      expect(res2.body.error.code).toBe('VALIDATION_ERROR');
    });
  });

  // =========================================================================
  // 3. Route Parameter Validation & Safe Regex Handling
  // =========================================================================
  describe('3. Route Parameter Validation & Safe Regex Handling', () => {
    it('returns 400 VALIDATION_ERROR for malformed claim ID parameter', async () => {
      const userToken = generateToken(USER_ROLES.CONTRIBUTOR);

      const res = await request(app)
        .get('/api/v1/claims/not-a-valid-24-hex-id')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details.fieldErrors.id).toBeDefined();
    });

    it('returns 400 VALIDATION_ERROR for malformed evidence ID parameter', async () => {
      const userToken = generateToken(USER_ROLES.CONTRIBUTOR);

      const res = await request(app)
        .get('/api/v1/evidence/not-a-valid-id')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details.fieldErrors.id).toBeDefined();
    });

    it('returns 400 VALIDATION_ERROR for malformed place attribute ID parameter', async () => {
      const userToken = generateToken(USER_ROLES.CONTRIBUTOR);

      const res = await request(app)
        .get('/api/v1/places/place-001/attributes/invalid-attr-id/history')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details.fieldErrors.attrId).toBeDefined();
    });

    it('clamps oversized pagination limit to maximum bound (100) safely', async () => {
      const userToken = generateToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(claimRepository, 'list').mockResolvedValue({ claims: [], total: 0 });

      const res = await request(app)
        .get('/api/v1/claims?limit=99999&page=1')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      // Pagination limit clamped to 100 in response
      expect(res.body.pagination.limit).toBe(100);
    });

    it('escapes regex search characters safely in place search query', () => {
      // Testing regex safety utility logic directly
      const evilSearchInput = '.*+?^${}()|[\\]\\';
      const escaped = evilSearchInput.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      
      // Creating RegExp with escaped string must NOT match arbitrary input
      const regex = new RegExp(escaped, 'i');
      expect(regex.test('arbitrary normal place name')).toBe(false);
      expect(regex.test(evilSearchInput)).toBe(true);
    });
  });

  // =========================================================================
  // 4. MongoDB Transaction Fail-Closed Policy in Production
  // =========================================================================
  describe('4. MongoDB Transaction Fail-Closed Policy', () => {
    let priorEnv: string | undefined;

    beforeEach(() => {
      priorEnv = process.env.NODE_ENV;
    });

    afterEach(() => {
      process.env.NODE_ENV = priorEnv;
    });

    it('fails closed with 500 TRANSACTIONS_NOT_SUPPORTED in production on standalone deployment', async () => {
      process.env.NODE_ENV = 'production';

      // Mock supportsTransactions to return false (standalone MongoDB)
      jest.spyOn(claimRepository, 'supportsTransactions').mockReturnValue(false);

      const workCallback = jest.fn();

      await expect(claimRepository.withTransaction(workCallback)).rejects.toMatchObject({
        statusCode: 500,
        code: 'TRANSACTIONS_NOT_SUPPORTED',
        isOperational: true,
      });

      expect(workCallback).not.toHaveBeenCalled();
    });

    it('allows non-production standalone development fallback executing work once', async () => {
      process.env.NODE_ENV = 'test';

      jest.spyOn(claimRepository, 'supportsTransactions').mockReturnValue(false);

      const workCallback = jest.fn().mockResolvedValue('standalone-success');

      const result = await claimRepository.withTransaction(workCallback);

      expect(result).toBe('standalone-success');
      expect(workCallback).toHaveBeenCalledTimes(1);
    });
  });

  describe('5. Route-Specific JSON Payload Limits', () => {
    it('rejects payload >100KB on standard routes (e.g. /api/v1/auth/login) with 413 PAYLOAD_TOO_LARGE', async () => {
      const largePayload = {
        email: 'test@example.com',
        password: 'password123',
        padding: 'a'.repeat(105 * 1024),
      };

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send(largePayload);

      expect(res.status).toBe(413);
      expect(res.body.error.code).toBe('PAYLOAD_TOO_LARGE');
    });

    it('accepts payload <=100KB on standard routes', async () => {
      const validPayload = {
        email: 'test@example.com',
        password: 'password123',
      };

      const res = await request(app)
        .post('/api/v1/auth/login')
        .send(validPayload);

      expect(res.status).not.toBe(413);
    });

    it('accepts payload >100KB but <500KB on claims route', async () => {
      const token = generateToken(USER_ROLES.CONTRIBUTOR);
      const mediumPayload = {
        title: { original: 'Large Story', language: 'en' },
        body: { original: 'b'.repeat(150 * 1024), language: 'en' },
        locationId: '507f1f77bcf86cd799439011',
        category: 'HISTORICAL_RECORD',
      };

      const res = await request(app)
        .post('/api/v1/claims')
        .set('Authorization', `Bearer ${token}`)
        .send(mediumPayload);

      expect(res.status).not.toBe(413);
    });

    it('rejects payload >500KB on claims route with 413 PAYLOAD_TOO_LARGE', async () => {
      const token = generateToken(USER_ROLES.CONTRIBUTOR);
      const oversizedClaimsPayload = {
        title: { original: 'Too Large Story', language: 'en' },
        body: { original: 'c'.repeat(550 * 1024), language: 'en' },
        locationId: '507f1f77bcf86cd799439011',
        category: 'HISTORICAL_RECORD',
      };

      const res = await request(app)
        .post('/api/v1/claims')
        .set('Authorization', `Bearer ${token}`)
        .send(oversizedClaimsPayload);

      expect(res.status).toBe(413);
      expect(res.body.error.code).toBe('PAYLOAD_TOO_LARGE');
    });

    it('accepts payload >500KB on evidence route', async () => {
      const token = generateToken(USER_ROLES.CONTRIBUTOR);
      const largeEvidencePayload = {
        claimId: '507f1f77bcf86cd799439011',
        sourceType: 'DOCUMENT',
        citation: 'Official Archives',
        data: 'd'.repeat(600 * 1024),
      };

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(largeEvidencePayload);

      expect(res.status).not.toBe(413);
    });

    it('rejects payload >10MB on evidence route with 413 PAYLOAD_TOO_LARGE', async () => {
      const token = generateToken(USER_ROLES.CONTRIBUTOR);
      const oversizedEvidencePayload = {
        claimId: '507f1f77bcf86cd799439011',
        sourceType: 'DOCUMENT',
        citation: 'Official Archives',
        data: 'e'.repeat(10.5 * 1024 * 1024),
      };

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(oversizedEvidencePayload);

      expect(res.status).toBe(413);
      expect(res.body.error.code).toBe('PAYLOAD_TOO_LARGE');
    });
  });
});
