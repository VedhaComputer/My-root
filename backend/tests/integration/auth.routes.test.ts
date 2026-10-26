import request from 'supertest';
import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { createApp } from '../../src/app';
import { authRepository } from '../../src/modules/auth/repository';
import { UserModel } from '../../src/modules/auth/user.model';
import { authRateLimiter, authRateLimitStore } from '../../src/modules/auth/routes';
import { mailer } from '../../src/shared/mail';
import { env } from '../../src/config/env';
import { getJwtPublicKey } from '../../src/config/keys';
import { USER_ROLES } from '../../src/shared/constants';
import { TEST_RSA_PRIVATE_KEY } from '../fixtures/testKeys';

const app = createApp();

describe('Auth Routes (Integration Tests)', () => {
  beforeEach(async () => {
    jest.clearAllMocks();
    await authRateLimitStore.resetAll();
  });

  describe('POST /auth/register and /api/v1/auth/register', () => {
    it('returns 400 when body fails Zod validation (short password, invalid email)', async () => {
      const res = await request(app).post('/api/v1/auth/register').send({
        displayName: 'A',
        email: 'invalid-email',
        password: '123',
      });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details).toBeDefined();
    });

    it('returns generic uniform 201 response when email is already registered to prevent enumeration', async () => {
      jest.spyOn(authRepository, 'emailExists').mockResolvedValue(true);
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: 'u-existing',
        email: 'existing@example.com',
        displayName: 'Existing User',
        isEmailVerified: true,
        isActive: true,
      } as any);

      const res = await request(app).post('/api/v1/auth/register').send({
        displayName: 'Existing User',
        email: 'existing@example.com',
        password: 'securePassword123',
      });

      expect(res.status).toBe(201);
      expect(res.body.message).toBe('Registration successful. Please verify your email.');
    });

    it('returns 201 on valid registration and does not leak credentials in response', async () => {
      jest.spyOn(authRepository, 'emailExists').mockResolvedValue(false);
      jest.spyOn(authRepository, 'createUser').mockResolvedValue({
        id: 'u-101',
        displayName: 'Sunil',
        role: USER_ROLES.CONTRIBUTOR,
      } as any);

      const res = await request(app).post('/api/v1/auth/register').send({
        displayName: 'Sunil Kumar',
        email: 'sunil@example.com',
        password: 'securePassword123',
      });

      expect(res.status).toBe(201);
      expect(res.body.message).toBe('Registration successful. Please verify your email.');
      expect(res.body.password).toBeUndefined();
      expect(res.body.passwordHash).toBeUndefined();
      expect(res.body.token).toBeUndefined();
      expect(res.body.verificationToken).toBeUndefined();
      expect(res.body.url).toBeUndefined();
    });

    it('creates user and returns 201 uniform message without crashing or leaking token when initial mailer delivery fails on registration', async () => {
      jest.spyOn(authRepository, 'emailExists').mockResolvedValue(false);
      jest.spyOn(authRepository, 'createUser').mockResolvedValue({
        id: 'u-102',
        displayName: 'Test Failure',
        role: USER_ROLES.CONTRIBUTOR,
      } as any);
      jest.spyOn(authRepository, 'setEmailVerificationToken').mockResolvedValue();
      jest.spyOn(mailer, 'sendVerificationEmail').mockRejectedValueOnce(new Error('SMTP connection failure'));

      const res = await request(app).post('/api/v1/auth/register').send({
        displayName: 'Test Failure',
        email: 'fail@example.com',
        password: 'securePassword123',
      });

      expect(res.status).toBe(201);
      expect(res.body.message).toBe('Registration successful. Please verify your email.');
      expect(res.body.token).toBeUndefined();
      expect(res.body.verificationToken).toBeUndefined();
    });

    it('allows retry registration for existing unverified user and re-dispatches verification email', async () => {
      jest.spyOn(authRepository, 'emailExists').mockResolvedValue(true);
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: 'u-unverified',
        email: 'unverified@example.com',
        displayName: 'Unverified User',
        isEmailVerified: false,
        isActive: true,
      } as any);
      const setTokenSpy = jest.spyOn(authRepository, 'setEmailVerificationToken').mockResolvedValue();
      const mailSpy = jest.spyOn(mailer, 'sendVerificationEmail').mockResolvedValue();

      const res = await request(app).post('/api/v1/auth/register').send({
        displayName: 'Unverified User',
        email: 'unverified@example.com',
        password: 'securePassword123',
      });

      expect(res.status).toBe(201);
      expect(res.body.message).toBe('Registration successful. Please verify your email.');
      expect(setTokenSpy).toHaveBeenCalled();
      expect(mailSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          to: 'unverified@example.com',
          token: expect.any(String),
        })
      );
    });
  });

  describe('POST /auth/login', () => {
    it('returns 400 when email or password is missing', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'test@example.com',
      });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 401 on invalid password', async () => {
      const hash = await bcrypt.hash('correctPassword', 10);
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: 'user-01',
        displayName: 'Sunil',
        email: 'sunil@example.com',
        passwordHash: hash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: true,
      } as any);

      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'sunil@example.com',
        password: 'wrongPassword',
      });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
      expect(res.body.error.message).toBe('Invalid email or password');
    });

    it('rejects login with sanitized 401 error when user email is not verified', async () => {
      const hash = await bcrypt.hash('myPassword123', 10);
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: 'user-unverified',
        displayName: 'Unverified User',
        email: 'unverified@example.com',
        passwordHash: hash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: false,
      } as any);

      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'unverified@example.com',
        password: 'myPassword123',
      });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
      expect(res.body.error.message).toBe('Invalid email or password');
      expect(res.body.accessToken).toBeUndefined();
      expect(res.body.refreshToken).toBeUndefined();
    });

    it('returns 200 with tokens and user on successful login for verified user', async () => {
      const hash = await bcrypt.hash('myPassword123', 10);
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: 'user-01',
        displayName: 'Sunil',
        email: 'sunil@example.com',
        passwordHash: hash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: true,
      } as any);
      jest.spyOn(authRepository, 'saveRefreshToken').mockResolvedValue({} as any);

      const res = await request(app).post('/api/v1/auth/login').send({
        email: 'sunil@example.com',
        password: 'myPassword123',
      });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      const decodedAccess = jwt.verify(res.body.accessToken, getJwtPublicKey(), {
        algorithms: ['RS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      }) as any;
      expect(decodedAccess.userId).toBe('user-01');
      expect(decodedAccess.sub).toBe('user-01');
      expect(decodedAccess.iss).toBe('myroot-backend');
      expect(decodedAccess.aud).toBe('myroot-platform');
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.user).toEqual({
        id: 'user-01',
        displayName: 'Sunil',
        role: USER_ROLES.CONTRIBUTOR,
      });
      // Verify no sensitive fields in response
      expect(res.body.user.passwordHash).toBeUndefined();
      expect(res.body.user.email).toBeUndefined();
    });

    it('end-to-end: legacy user with undefined isEmailVerified is denied login (401), recovers via resend + verify, and logs in with 200', async () => {
      const hash = await bcrypt.hash('validPass123!', 10);
      const userDoc: any = {
        _id: 'user-legacy-02',
        displayName: 'Legacy User',
        email: 'legacy-recovery@example.com',
        passwordHash: hash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        // isEmailVerified is undefined
        tokenVersion: 1,
      };

      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockImplementation(async () => userDoc);
      jest.spyOn(authRepository, 'saveRefreshToken').mockResolvedValue({} as any);

      // 1. Initial login attempt fails with 401
      const preRes = await request(app).post('/api/v1/auth/login').send({
        email: 'legacy-recovery@example.com',
        password: 'validPass123!',
      });
      expect(preRes.status).toBe(401);
      expect(preRes.body.error.code).toBe('UNAUTHENTICATED');

      // 2. Request verification resend
      let capturedTokenHash: string | null = null;
      let lastDispatchedToken: string | null = null;
      jest.spyOn(authRepository, 'setEmailVerificationToken').mockImplementation(async (_id, tokenHash) => {
        capturedTokenHash = tokenHash;
      });
      jest.spyOn(mailer, 'sendVerificationEmail').mockImplementation(async (payload) => {
        lastDispatchedToken = payload.token;
      });

      const resendRes = await request(app).post('/api/v1/auth/verify-email/resend').send({
        email: 'legacy-recovery@example.com',
      });
      expect(resendRes.status).toBe(200);
      expect(capturedTokenHash).toBeDefined();
      expect(lastDispatchedToken).toBeDefined();

      // 3. Simulate verify-email with matching token
      jest.spyOn(authRepository, 'findByEmailVerificationToken').mockImplementation(async (tokenHash) => {
        const expected = crypto.createHash('sha256').update(lastDispatchedToken!).digest('hex');
        if (tokenHash === expected) {
          return userDoc;
        }
        return null;
      });
      jest.spyOn(authRepository, 'markEmailVerified').mockImplementation(async () => {
        userDoc.isEmailVerified = true;
      });

      const verifyRes = await request(app).post('/api/v1/auth/verify-email').send({
        token: lastDispatchedToken!,
      });
      expect(verifyRes.status).toBe(200);
      expect(verifyRes.body.message).toBe('Email verified successfully');
      expect(userDoc.isEmailVerified).toBe(true);

      // 4. Post-recovery login succeeds with 200
      const postRes = await request(app).post('/api/v1/auth/login').send({
        email: 'legacy-recovery@example.com',
        password: 'validPass123!',
      });
      expect(postRes.status).toBe(200);
      expect(postRes.body.accessToken).toBeDefined();
      expect(postRes.body.refreshToken).toBeDefined();
      expect(postRes.body.user.displayName).toBe('Legacy User');
    });
  });

  describe('POST /auth/refresh', () => {
    it('returns 400 when refreshToken is missing', async () => {
      const res = await request(app).post('/api/v1/auth/refresh').send({});

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 401 when token is invalid or expired', async () => {
      const res = await request(app).post('/api/v1/auth/refresh').send({
        refreshToken: 'invalid.jwt.token',
      });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 401 UNAUTHENTICATED when refresh token is missing tokenVersion claim', async () => {
      const validUserId = '507f1f77bcf86cd799439011';
      const tokenWithoutVersion = jwt.sign({ userId: validUserId }, env.JWT_REFRESH_SECRET, {
        expiresIn: '7d',
      });

      jest.spyOn(authRepository, 'findTokenByHash').mockResolvedValue(null);
      jest.spyOn(authRepository, 'findById').mockResolvedValue({
        _id: validUserId,
        displayName: 'Sunil',
        email: 'sunil@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        tokenVersion: 1,
      } as any);

      const res = await request(app).post('/api/v1/auth/refresh').send({
        refreshToken: tokenWithoutVersion,
      });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
      expect(res.body.error.message).toBe('Invalid or expired refresh token');
    });

    it('returns 401 UNAUTHENTICATED when refresh token has stale tokenVersion', async () => {
      const validUserId = '507f1f77bcf86cd799439011';
      const staleToken = jwt.sign({ userId: validUserId, tokenVersion: 1 }, env.JWT_REFRESH_SECRET, {
        expiresIn: '7d',
      });

      jest.spyOn(authRepository, 'findTokenByHash').mockResolvedValue(null);
      jest.spyOn(authRepository, 'findById').mockResolvedValue({
        _id: validUserId,
        displayName: 'Sunil',
        email: 'sunil@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        tokenVersion: 2, // Incremented after password reset
      } as any);

      const res = await request(app).post('/api/v1/auth/refresh').send({
        refreshToken: staleToken,
      });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
      expect(res.body.error.message).toBe('Token has been revoked');
    });

    it('returns 200 with rotated tokens on valid refresh token', async () => {
      const validUserId = '507f1f77bcf86cd799439011';
      const validRefreshToken = jwt.sign({ userId: validUserId, tokenVersion: 1 }, env.JWT_REFRESH_SECRET, {
        expiresIn: '7d',
      });

      jest.spyOn(authRepository, 'findTokenByHash').mockResolvedValue(null);
      jest.spyOn(authRepository, 'atomicRotateRefreshToken').mockResolvedValue({
        tokenHash: 'rotated-hash',
        userId: validUserId,
        revoked: true,
      } as any);
      jest.spyOn(authRepository, 'findActiveRefreshToken').mockResolvedValue({
        tokenHash: 'abc',
        userId: validUserId as any,
        revoked: false,
      } as any);
      jest.spyOn(authRepository, 'findById').mockResolvedValue({
        _id: validUserId,
        displayName: 'Sunil',
        email: 'sunil@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        tokenVersion: 1,
      } as any);
      jest.spyOn(authRepository, 'revokeRefreshToken').mockResolvedValue(true);
      jest.spyOn(authRepository, 'saveRefreshToken').mockResolvedValue({} as any);

      const res = await request(app).post('/api/v1/auth/refresh').send({
        refreshToken: validRefreshToken,
      });

      expect(res.status).toBe(200);
      expect(res.body.accessToken).toBeDefined();
      const decodedRotated = jwt.verify(res.body.accessToken, getJwtPublicKey(), {
        algorithms: ['RS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      }) as any;
      expect(decodedRotated.userId).toBe(validUserId);
      expect(decodedRotated.sub).toBe(validUserId);
      expect(res.body.refreshToken).toBeDefined();
      expect(res.body.refreshToken).not.toBe(validRefreshToken);
    });
  });

  describe('POST /auth/password-reset/request and /api/v1/auth/password-reset/request', () => {
    it('returns 400 when email is invalid or missing', async () => {
      const res = await request(app).post('/api/v1/auth/password-reset/request').send({
        email: 'not-an-email',
      });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 200 with uniform generic message and dispatches mail when user exists', async () => {
      const testEmail = 'validuser@example.com';
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: 'u-pw-1',
        email: testEmail,
        displayName: 'Valid User',
        isActive: true,
      } as any);
      const setTokenSpy = jest.spyOn(authRepository, 'setPasswordResetToken').mockResolvedValue();
      const mailSpy = jest.spyOn(mailer, 'sendPasswordResetEmail').mockResolvedValue();

      const res = await request(app).post('/api/v1/auth/password-reset/request').send({
        email: testEmail,
      });

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('If an account exists with this email, password reset instructions have been sent.');
      expect(mailSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          to: testEmail,
          token: expect.stringMatching(/^[0-9a-f]{64}$/),
          resetUrl: expect.stringContaining('/reset-password?token='),
        })
      );
      // Repository must store SHA-256 hash, not raw token
      expect(setTokenSpy).toHaveBeenCalledWith(
        'u-pw-1',
        expect.stringMatching(/^[0-9a-f]{64}$/),
        expect.any(Date)
      );
      // Response must not leak token or reset link
      expect(res.body.token).toBeUndefined();
      expect(res.body.resetToken).toBeUndefined();
      expect(res.body.resetUrl).toBeUndefined();
    });

    it('returns identical uniform 200 message without calling mailer when email does not exist (account enumeration protection)', async () => {
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue(null);
      const mailSpy = jest.spyOn(mailer, 'sendPasswordResetEmail');

      const res = await request(app).post('/api/v1/auth/password-reset/request').send({
        email: 'doesnotexist@example.com',
      });

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('If an account exists with this email, password reset instructions have been sent.');
      expect(mailSpy).not.toHaveBeenCalled();
    });

    it('returns uniform 200 message without revealing failure and does not leak token when mailer fails during password reset request', async () => {
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: 'u-pw-2',
        email: 'failmail@example.com',
        isActive: true,
      } as any);
      jest.spyOn(authRepository, 'setPasswordResetToken').mockResolvedValue();
      jest.spyOn(mailer, 'sendPasswordResetEmail').mockRejectedValueOnce(new Error('SMTP down'));

      const res = await request(app).post('/api/v1/auth/password-reset/request').send({
        email: 'failmail@example.com',
      });

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('If an account exists with this email, password reset instructions have been sent.');
      expect(res.body.token).toBeUndefined();
      expect(res.body.resetToken).toBeUndefined();
    });
  });

  describe('POST /auth/password-reset/confirm and /api/v1/auth/password-reset/confirm', () => {
    it('returns 400 when body fails Zod validation (missing token or short password)', async () => {
      const res = await request(app)
        .post('/api/v1/auth/password-reset/confirm')
        .send({
          token: '',
          newPassword: 'short',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 VALIDATION_ERROR when reset token is invalid or expired', async () => {
      jest.spyOn(authRepository, 'findByPasswordResetToken').mockResolvedValue(null);

      const res = await request(app)
        .post('/api/v1/auth/password-reset/confirm')
        .send({
          token: 'invalid-or-expired-token',
          newPassword: 'newSecurePassword123',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.message).toBe('Invalid or expired password reset token');
    });

    it('returns 200 and success message on valid password reset confirmation', async () => {
      const testUserId = new mongoose.Types.ObjectId().toString();
      jest.spyOn(authRepository, 'findByPasswordResetToken').mockResolvedValue({
        _id: testUserId,
        id: testUserId,
      } as any);
      const resetPasswordSpy = jest.spyOn(authRepository, 'resetPassword').mockResolvedValue(undefined as any);
      const revokeTokensSpy = jest.spyOn(authRepository, 'revokeAllUserRefreshTokens').mockResolvedValue(1);

      const res = await request(app)
        .post('/api/v1/auth/password-reset/confirm')
        .send({
          token: 'valid-reset-token-xyz',
          newPassword: 'brandNewPassword123!',
        });

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Password reset successful. Please log in with your new password.');
      expect(resetPasswordSpy).toHaveBeenCalledWith(testUserId, expect.any(String));
      expect(revokeTokensSpy).toHaveBeenCalledWith(testUserId);

      resetPasswordSpy.mockRestore();
      revokeTokensSpy.mockRestore();
    });

    it('revokes pre-reset access tokens: access token issued before reset fails authentication with 401 on /auth/me after reset succeeds', async () => {
      const testUserId = new mongoose.Types.ObjectId().toString();

      // State variable simulating user document in database
      let userTokenVersion = 1;

      // Mock UserModel.findById to reflect user's current tokenVersion in the database
      const findByIdSpy = jest.spyOn(UserModel, 'findById').mockImplementation((id: any) => ({
        select: () => ({
          lean: () => ({
            exec: async () => ({
              _id: mongoose.Types.ObjectId.isValid(id) ? new mongoose.Types.ObjectId(id) : id,
              isActive: true,
              role: USER_ROLES.CONTRIBUTOR,
              displayName: 'Sunil',
              tokenVersion: userTokenVersion,
            }),
          }),
        }),
      } as any));

      // Spy on UserModel.findByIdAndUpdate to simulate DB increment of tokenVersion
      const findByIdAndUpdateSpy = jest.spyOn(UserModel, 'findByIdAndUpdate').mockImplementation(((filter: any, update: any) => {
        if (update?.$inc?.tokenVersion) {
          userTokenVersion += update.$inc.tokenVersion;
        }
        return {
          exec: jest.fn().mockResolvedValue({ _id: testUserId, tokenVersion: userTokenVersion }),
        };
      }) as any);

      try {
        // Mock authRepository.findById for GET /auth/me profile fetching
        jest.spyOn(authRepository, 'findById').mockResolvedValue({
          _id: testUserId,
          displayName: 'Sunil',
          role: USER_ROLES.CONTRIBUTOR,
        } as any);

        // Pre-reset access token generated with current tokenVersion: 1
        const preResetAccessToken = jwt.sign(
          {
            userId: testUserId,
            email: 'sunil@example.com',
            role: USER_ROLES.CONTRIBUTOR,
            displayName: 'Sunil',
            tokenVersion: 1,
          },
          TEST_RSA_PRIVATE_KEY,
          { algorithm: 'RS256', issuer: 'myroot-backend', audience: 'myroot-platform', expiresIn: '15m' }
        );

        // 1. Verify pre-reset token works initially on protected endpoint GET /auth/me
        const preResetMeRes = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${preResetAccessToken}`);
        expect(preResetMeRes.status).toBe(200);
        expect(preResetMeRes.body.data.id).toBe(testUserId);

        // 2. Perform password reset for this user
        jest.spyOn(authRepository, 'findByPasswordResetToken').mockResolvedValue({
          _id: testUserId,
          id: testUserId,
        } as any);
        jest.spyOn(authRepository, 'revokeAllUserRefreshTokens').mockResolvedValue(1);

        const resetRes = await request(app)
          .post('/api/v1/auth/password-reset/confirm')
          .send({
            token: 'valid-reset-token-abc',
            newPassword: 'brandNewPassword123!',
          });

        expect(resetRes.status).toBe(200);
        expect(resetRes.body.message).toBe('Password reset successful. Please log in with your new password.');
        expect(userTokenVersion).toBe(2);

        // 3. Verify pre-reset token (with old tokenVersion 1) is now rejected with 401 UNAUTHENTICATED
        const postResetMeRes = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${preResetAccessToken}`);

        expect(postResetMeRes.status).toBe(401);
        expect(postResetMeRes.body.error.code).toBe('UNAUTHENTICATED');
        expect(postResetMeRes.body.error.message).toBe('Token has been revoked');

        // 4. Verify that a newly issued access token with new tokenVersion: 2 is accepted
        const postResetAccessToken = jwt.sign(
          {
            userId: testUserId,
            email: 'sunil@example.com',
            role: USER_ROLES.CONTRIBUTOR,
            displayName: 'Sunil',
            tokenVersion: userTokenVersion,
          },
          TEST_RSA_PRIVATE_KEY,
          { algorithm: 'RS256', issuer: 'myroot-backend', audience: 'myroot-platform', expiresIn: '15m' }
        );

        const validNewTokenRes = await request(app)
          .get('/api/v1/auth/me')
          .set('Authorization', `Bearer ${postResetAccessToken}`);

        expect(validNewTokenRes.status).toBe(200);
        expect(validNewTokenRes.body.data.id).toBe(testUserId);
      } finally {
        findByIdSpy.mockRestore();
        findByIdAndUpdateSpy.mockRestore();
      }
    });
  });

  describe('POST /auth/verify-email and /api/v1/auth/verify-email', () => {
    it('returns 400 when token is missing or empty', async () => {
      const res = await request(app).post('/api/v1/auth/verify-email').send({});
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');

      const emptyRes = await request(app).post('/api/v1/auth/verify-email').send({ token: '' });
      expect(emptyRes.status).toBe(400);
      expect(emptyRes.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 VALIDATION_ERROR when verification token is invalid', async () => {
      jest.spyOn(authRepository, 'findByEmailVerificationToken').mockResolvedValue(null);

      const res = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: 'invalid-token-12345' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.message).toBe('Invalid or expired verification token');
    });

    it('returns 400 VALIDATION_ERROR when verification token has expired', async () => {
      jest.spyOn(authRepository, 'findByEmailVerificationToken').mockResolvedValue(null);

      const res = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: 'expired-token-67890' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.message).toBe('Invalid or expired verification token');
    });

    it('returns 200 on valid email verification and does not leak token in response', async () => {
      const testUserId = new mongoose.Types.ObjectId().toString();
      jest.spyOn(authRepository, 'findByEmailVerificationToken').mockResolvedValue({
        _id: testUserId,
        email: 'user@example.com',
        isEmailVerified: false,
      } as any);
      const markVerifiedSpy = jest.spyOn(authRepository, 'markEmailVerified').mockResolvedValue();

      const res = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: 'valid-verification-token-abc' });

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Email verified successfully');
      expect(markVerifiedSpy).toHaveBeenCalledWith(testUserId);
      expect(res.body.token).toBeUndefined();
      expect(res.body.verificationToken).toBeUndefined();

      markVerifiedSpy.mockRestore();
    });

    it('rejects repeated token use because token is invalidated after first verification', async () => {
      const testUserId = new mongoose.Types.ObjectId().toString();
      const findTokenSpy = jest.spyOn(authRepository, 'findByEmailVerificationToken')
        .mockResolvedValueOnce({ _id: testUserId, isEmailVerified: false } as any)
        .mockResolvedValueOnce(null);
      const markVerifiedSpy = jest.spyOn(authRepository, 'markEmailVerified').mockResolvedValue();

      // First verification call
      const firstRes = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: 'single-use-token' });
      expect(firstRes.status).toBe(200);
      expect(firstRes.body.message).toBe('Email verified successfully');

      // Second verification call with same token
      const secondRes = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: 'single-use-token' });
      expect(secondRes.status).toBe(400);
      expect(secondRes.body.error.code).toBe('VALIDATION_ERROR');
      expect(secondRes.body.error.message).toBe('Invalid or expired verification token');

      findTokenSpy.mockRestore();
      markVerifiedSpy.mockRestore();
    });

    it('fails closed with 503 SERVICE_UNAVAILABLE when database is disconnected during verification', async () => {
      const testUserId = new mongoose.Types.ObjectId().toString();
      jest.spyOn(authRepository, 'findByEmailVerificationToken').mockResolvedValue({
        _id: testUserId,
        isEmailVerified: false,
      } as any);
      jest.spyOn(authRepository, 'markEmailVerified').mockRejectedValue(
        new (require('../../src/shared/errors/AppError').ServiceUnavailableError)(
          'Authentication service unavailable: database disconnected'
        )
      );

      const res = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: 'valid-token' });

      expect(res.status).toBe(503);
      expect(res.body.error.code).toBe('SERVICE_UNAVAILABLE');
    });

    it('enforces complete verification lifecycle: login blocked before verification, succeeds after verification', async () => {
      const testUserId = new mongoose.Types.ObjectId().toString();
      const testPassword = 'mySecurePassword123';
      const passwordHash = await bcrypt.hash(testPassword, 10);

      let isVerified = false;

      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockImplementation(async () => ({
        _id: testUserId,
        displayName: 'Lifecycle User',
        email: 'lifecycle@example.com',
        passwordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: isVerified,
        tokenVersion: 1,
      } as any));

      jest.spyOn(authRepository, 'findByEmailVerificationToken').mockImplementation(async (tokenHash: string) => {
        if (!isVerified && tokenHash) {
          return { _id: testUserId, email: 'lifecycle@example.com', isEmailVerified: false } as any;
        }
        return null;
      });

      jest.spyOn(authRepository, 'markEmailVerified').mockImplementation(async () => {
        isVerified = true;
      });

      jest.spyOn(authRepository, 'saveRefreshToken').mockResolvedValue({} as any);

      // Step 1: Login before verification fails with 401
      const preVerifyLogin = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: 'lifecycle@example.com', password: testPassword });
      expect(preVerifyLogin.status).toBe(401);
      expect(preVerifyLogin.body.error.message).toBe('Invalid email or password');
      expect(preVerifyLogin.body.accessToken).toBeUndefined();

      // Step 2: Verification endpoint called with valid token
      const verifyRes = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: 'raw-lifecycle-token' });
      expect(verifyRes.status).toBe(200);
      expect(verifyRes.body.message).toBe('Email verified successfully');
      expect(isVerified).toBe(true);

      // Step 3: Login after verification succeeds with 200 and tokens
      const postVerifyLogin = await request(app)
        .post('/api/v1/auth/login')
        .send({ email: 'lifecycle@example.com', password: testPassword });
      expect(postVerifyLogin.status).toBe(200);
      expect(postVerifyLogin.body.accessToken).toBeDefined();
      expect(postVerifyLogin.body.refreshToken).toBeDefined();
      expect(postVerifyLogin.body.user.id).toBe(testUserId);

      // Step 4: Re-verification attempt fails because token was cleared
      const repeatVerifyRes = await request(app)
        .post('/api/v1/auth/verify-email')
        .send({ token: 'raw-lifecycle-token' });
      expect(repeatVerifyRes.status).toBe(400);
      expect(repeatVerifyRes.body.error.code).toBe('VALIDATION_ERROR');
    });

    describe('POST /api/v1/auth/verify-email/resend', () => {
      it('returns 400 when email is invalid', async () => {
        const res = await request(app)
          .post('/api/v1/auth/verify-email/resend')
          .send({ email: 'not-an-email' });

        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_ERROR');
      });

      it('returns 200 uniform response and dispatches email for unverified/legacy user', async () => {
        const testUserId = new mongoose.Types.ObjectId().toString();
        const findSpy = jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
          _id: testUserId,
          email: 'legacy-resend@example.com',
          isActive: true,
          isEmailVerified: undefined, // Legacy user
        } as any);
        const setTokenSpy = jest.spyOn(authRepository, 'setEmailVerificationToken').mockResolvedValue();
        const mailSpy = jest.spyOn(mailer, 'sendVerificationEmail').mockResolvedValue();

        const res = await request(app)
          .post('/api/v1/auth/verify-email/resend')
          .send({ email: 'legacy-resend@example.com' });

        expect(res.status).toBe(200);
        expect(res.body.message).toContain('If an unverified account exists');
        expect(authRepository.setEmailVerificationToken).toHaveBeenCalledWith(
          testUserId,
          expect.any(String),
          expect.any(Date)
        );
        expect(mailSpy).toHaveBeenCalledWith(
          expect.objectContaining({
            to: 'legacy-resend@example.com',
          })
        );
        findSpy.mockRestore();
        setTokenSpy.mockRestore();
        mailSpy.mockRestore();
      });

      it('returns 200 uniform response without sending email for already verified user', async () => {
        const testUserId = new mongoose.Types.ObjectId().toString();
        const findSpy = jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
          _id: testUserId,
          email: 'verified@example.com',
          isActive: true,
          isEmailVerified: true,
        } as any);
        const mailSpy = jest.spyOn(mailer, 'sendVerificationEmail').mockResolvedValue();

        const res = await request(app)
          .post('/api/v1/auth/verify-email/resend')
          .send({ email: 'verified@example.com' });

        expect(res.status).toBe(200);
        expect(res.body.message).toContain('If an unverified account exists');
        expect(mailSpy).not.toHaveBeenCalled();
        findSpy.mockRestore();
        mailSpy.mockRestore();
      });
    });
  });

  describe('POST /auth/logout', () => {
    it('returns 401 if unauthenticated', async () => {
      const res = await request(app).post('/api/v1/auth/logout').send({});

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 200 and revokes token when authenticated', async () => {
      const token = jwt.sign(
        { userId: '507f1f77bcf86cd799439011', email: 'a@b.com', role: USER_ROLES.CONTRIBUTOR, displayName: 'User', tokenVersion: 1 },
        TEST_RSA_PRIVATE_KEY,
        { algorithm: 'RS256', issuer: 'myroot-backend', audience: 'myroot-platform', expiresIn: '15m' }
      );
      jest.spyOn(authRepository, 'revokeAllUserRefreshTokens').mockResolvedValue(1);

      const res = await request(app)
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${token}`)
        .send({});

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Logged out successfully');
    });
  });

  describe('GET /auth/me', () => {
    it('returns 401 if token is missing', async () => {
      const res = await request(app).get('/api/v1/auth/me');

      expect(res.status).toBe(401);
    });

    it('returns current user profile when token is valid', async () => {
      const token = jwt.sign(
        { userId: '507f1f77bcf86cd799439011', email: 'a@b.com', role: USER_ROLES.CONTRIBUTOR, displayName: 'User', tokenVersion: 1 },
        TEST_RSA_PRIVATE_KEY,
        { algorithm: 'RS256', issuer: 'myroot-backend', audience: 'myroot-platform', expiresIn: '15m' }
      );
      jest.spyOn(authRepository, 'findById').mockResolvedValue({
        _id: '507f1f77bcf86cd799439011',
        displayName: 'Sunil',
        role: USER_ROLES.CONTRIBUTOR,
      } as any);

      const res = await request(app).get('/api/v1/auth/me').set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toEqual({
        id: '507f1f77bcf86cd799439011',
        displayName: 'Sunil',
        role: USER_ROLES.CONTRIBUTOR,
      });
    });
  });

  describe('GET /auth/me/activity', () => {
    it('returns 401 if unauthenticated', async () => {
      const res = await request(app).get('/api/v1/auth/me/activity');
      expect(res.status).toBe(401);
    });

    it('returns user activity history and summary when authenticated', async () => {
      const { ClaimModel } = await import('../../src/modules/claims/claim.model');
      const { EvidenceModel } = await import('../../src/modules/evidence/evidence.model');
      const { PlaceModel } = await import('../../src/modules/places/place.model');
      const { PlaceAttributeModel } = await import('../../src/modules/places/placeAttribute.model');

      const testUserId = new mongoose.Types.ObjectId().toString();
      const token = jwt.sign(
        { userId: testUserId, email: 'contributor@example.com', role: USER_ROLES.CONTRIBUTOR, displayName: 'Contributor', tokenVersion: 1 },
        TEST_RSA_PRIVATE_KEY,
        { algorithm: 'RS256', issuer: 'myroot-backend', audience: 'myroot-platform', expiresIn: '15m' }
      );

      jest.spyOn(ClaimModel, 'find').mockReturnValue({
        sort: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue([
              {
                _id: new mongoose.Types.ObjectId(),
                title: { original: 'Ancient Fort Lore' },
                category: 'FOLKLORE',
                status: 'submitted',
                submittedAt: new Date('2026-01-15'),
                locationId: new mongoose.Types.ObjectId(),
                evidenceIds: [new mongoose.Types.ObjectId()],
                isPublic: true,
              },
            ]),
          }),
        }),
      } as any);

      jest.spyOn(EvidenceModel, 'find').mockReturnValue({
        sort: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue([
              {
                _id: new mongoose.Types.ObjectId(),
                claimId: new mongoose.Types.ObjectId(),
                sourceType: 'DOCUMENT',
                title: 'Land Deed 1920',
                description: 'Archival deed',
                status: 'submitted',
                uploadedAt: new Date('2026-01-16'),
              },
            ]),
          }),
        }),
      } as any);

      jest.spyOn(PlaceModel, 'find').mockReturnValue({
        sort: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue([]),
          }),
        }),
      } as any);

      jest.spyOn(PlaceAttributeModel, 'find').mockReturnValue({
        sort: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue([]),
          }),
        }),
      } as any);

      const res = await request(app).get('/api/v1/auth/me/activity').set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.summary.totalClaims).toBe(1);
      expect(res.body.data.summary.totalEvidences).toBe(1);
      expect(res.body.data.claims).toHaveLength(1);
      expect(res.body.data.claims[0].category).toBe('FOLKLORE');
      expect(res.body.data.evidences).toHaveLength(1);
      expect(res.body.data.evidences[0].sourceType).toBe('DOCUMENT');
    });

    it('queries claims sorted by submittedAt: -1, _id: -1 and includes user village contributions across draft and submitted states', async () => {
      const { ClaimModel } = await import('../../src/modules/claims/claim.model');
      const { EvidenceModel } = await import('../../src/modules/evidence/evidence.model');
      const { PlaceModel } = await import('../../src/modules/places/place.model');
      const { PlaceAttributeModel } = await import('../../src/modules/places/placeAttribute.model');

      const testUserId = new mongoose.Types.ObjectId().toString();
      const token = jwt.sign(
        { userId: testUserId, email: 'contributor@example.com', role: USER_ROLES.CONTRIBUTOR, displayName: 'Contributor', tokenVersion: 1 },
        TEST_RSA_PRIVATE_KEY,
        { algorithm: 'RS256', issuer: 'myroot-backend', audience: 'myroot-platform', expiresIn: '15m' }
      );

      const claimSortMock = jest.fn().mockReturnValue({
        limit: jest.fn().mockReturnValue({
          exec: jest.fn().mockResolvedValue([
            {
              _id: new mongoose.Types.ObjectId(),
              title: { original: 'Village River Origin Story' },
              category: 'HISTORICAL_RECORD',
              status: 'draft',
              submittedAt: new Date('2026-03-01T10:00:00Z'),
              locationId: new mongoose.Types.ObjectId(),
              evidenceIds: [],
              isPublic: false,
            },
            {
              _id: new mongoose.Types.ObjectId(),
              title: { original: 'Old Neem Tree Folklore' },
              category: 'FOLKLORE',
              status: 'submitted',
              submittedAt: new Date('2026-02-15T09:00:00Z'),
              locationId: new mongoose.Types.ObjectId(),
              evidenceIds: [],
              isPublic: true,
            },
          ]),
        }),
      });

      const findClaimSpy = jest.spyOn(ClaimModel, 'find').mockReturnValue({
        sort: claimSortMock,
      } as any);

      jest.spyOn(EvidenceModel, 'find').mockReturnValue({
        sort: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue([]),
          }),
        }),
      } as any);

      jest.spyOn(PlaceModel, 'find').mockReturnValue({
        sort: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue([]),
          }),
        }),
      } as any);

      jest.spyOn(PlaceAttributeModel, 'find').mockReturnValue({
        sort: jest.fn().mockReturnValue({
          limit: jest.fn().mockReturnValue({
            exec: jest.fn().mockResolvedValue([]),
          }),
        }),
      } as any);

      const res = await request(app).get('/api/v1/auth/me/activity').set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(findClaimSpy).toHaveBeenCalledWith({ submittedBy: new mongoose.Types.ObjectId(testUserId) });
      expect(claimSortMock).toHaveBeenCalledWith({ submittedAt: -1, _id: -1 });
      expect(res.body.data.claims).toHaveLength(2);
      expect(res.body.data.claims[0].status).toBe('draft');
      expect(res.body.data.claims[0].title.original).toBe('Village River Origin Story');
      expect(res.body.data.claims[1].status).toBe('submitted');
      expect(res.body.data.claims[1].title.original).toBe('Old Neem Tree Folklore');
    });
  });

  describe('PATCH /auth/me and /auth/me/selected-place', () => {
    const testUserId = new mongoose.Types.ObjectId().toString();
    const token = jwt.sign(
      { userId: testUserId, email: 'contributor@example.com', role: USER_ROLES.CONTRIBUTOR, displayName: 'Contributor', tokenVersion: 1 },
      TEST_RSA_PRIVATE_KEY,
      { algorithm: 'RS256', issuer: 'myroot-backend', audience: 'myroot-platform', expiresIn: '15m' }
    );

    it('returns 401 when request is unauthenticated', async () => {
      const res = await request(app)
        .patch('/api/v1/auth/me')
        .send({ selectedPlaceId: new mongoose.Types.ObjectId().toString() });

      expect(res.status).toBe(401);
    });

    it('returns 400 when selectedPlaceId has invalid characters or format', async () => {
      const res = await request(app)
        .patch('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .send({ selectedPlaceId: 'invalid/id/with/slashes' });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details.fieldErrors.selectedPlaceId).toBeDefined();
    });

    it('returns 404 when place does not exist in database', async () => {
      const nonExistentPlaceId = new mongoose.Types.ObjectId().toString();
      const mockUser = {
        _id: new mongoose.Types.ObjectId(testUserId),
        displayName: 'Contributor',
        role: USER_ROLES.CONTRIBUTOR,
        save: jest.fn().mockResolvedValue(true),
      };
      jest.spyOn(authRepository, 'findById').mockResolvedValue(mockUser as any);
      const { PlaceModel } = await import('../../src/modules/places/place.model');
      jest.spyOn(PlaceModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      const res = await request(app)
        .patch('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .send({ selectedPlaceId: nonExistentPlaceId });

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
      expect(res.body.error.message).toContain('Place');
      expect(mockUser.save).not.toHaveBeenCalled();
    });

    it('successfully persists selectedPlaceId with ObjectId and returns it in response and GET /auth/me', async () => {
      const validPlaceId = new mongoose.Types.ObjectId();
      const mockUser = {
        _id: new mongoose.Types.ObjectId(testUserId),
        displayName: 'Contributor',
        role: USER_ROLES.CONTRIBUTOR,
        verifiedLocationId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        selectedPlaceId: null,
        placeRelationships: [
          {
            placeId: validPlaceId.toString(),
            indigenousClassification: 'Indigenous',
          },
        ],
        save: jest.fn().mockImplementation(function (this: any) {
          return Promise.resolve(this);
        }),
      };
      jest.spyOn(authRepository, 'findById').mockResolvedValue(mockUser as any);
      const { PlaceModel } = await import('../../src/modules/places/place.model');
      jest.spyOn(PlaceModel, 'findById').mockReturnValue({
        exec: jest.fn().mockResolvedValue({
          _id: validPlaceId,
          canonicalName: 'Mandore Village',
          level: 'VILLAGE',
        }),
      } as any);

      const res = await request(app)
        .patch('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .send({ selectedPlaceId: validPlaceId.toString() });

      expect(res.status).toBe(200);
      expect(res.body.data.selectedPlaceId).toBe(validPlaceId.toString());
      expect(res.body.data.verifiedLocationId).toBe('507f1f77bcf86cd799439011');
      expect(mockUser.save).toHaveBeenCalled();
      expect(mockUser.selectedPlaceId).toEqual(validPlaceId.toString());

      // Verify subsequent GET /auth/me also returns persisted selectedPlaceId
      const getMeRes = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`);

      expect(getMeRes.status).toBe(200);
      expect(getMeRes.body.data.selectedPlaceId).toBe(validPlaceId.toString());
      // Verified location badge id is unchanged
      expect(getMeRes.body.data.verifiedLocationId).toBe('507f1f77bcf86cd799439011');
    });

    it('successfully persists India Place API string ID (e.g. PL_VIL_06_077_00382_060008) via gateway proxy and preserves verifiedLocationId', async () => {
      const indiaPlaceId = 'PL_VIL_06_077_00382_060008';
      const mockUser = {
        _id: new mongoose.Types.ObjectId(testUserId),
        displayName: 'Contributor',
        role: USER_ROLES.CONTRIBUTOR,
        verifiedLocationId: new mongoose.Types.ObjectId('507f1f77bcf86cd799439011'),
        selectedPlaceId: null,
        placeRelationships: [
          {
            placeId: indiaPlaceId,
            indigenousClassification: 'Indigenous',
          },
        ],
        save: jest.fn().mockImplementation(function (this: any) {
          return Promise.resolve(this);
        }),
      };
      jest.spyOn(authRepository, 'findById').mockResolvedValue(mockUser as any);
      const { placeGatewayService } = await import('../../src/modules/places/gateway');
      jest.spyOn(placeGatewayService, 'isProxyEnabled').mockReturnValue(true);
      jest.spyOn(placeGatewayService, 'executeProxy').mockResolvedValue({
        status: 200,
        body: {
          data: {
            id: indiaPlaceId,
            canonicalName: 'Mohal Khera (38)',
            level: 'VILLAGE',
          },
        },
      });

      const res = await request(app)
        .patch('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .send({ selectedPlaceId: indiaPlaceId });

      expect(res.status).toBe(200);
      expect(res.body.data.selectedPlaceId).toBe(indiaPlaceId);
      expect(res.body.data.verifiedLocationId).toBe('507f1f77bcf86cd799439011');
      expect(mockUser.save).toHaveBeenCalled();
      expect(mockUser.selectedPlaceId).toEqual(indiaPlaceId);

      // Verify GET /auth/me returns persisted India Place API ID
      const getMeRes = await request(app)
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`);

      expect(getMeRes.status).toBe(200);
      expect(getMeRes.body.data.selectedPlaceId).toBe(indiaPlaceId);
      expect(getMeRes.body.data.verifiedLocationId).toBe('507f1f77bcf86cd799439011');
    });

    it('allows clearing selectedPlaceId by sending null', async () => {
      const mockUser = {
        _id: new mongoose.Types.ObjectId(testUserId),
        displayName: 'Contributor',
        role: USER_ROLES.CONTRIBUTOR,
        selectedPlaceId: 'PL_VIL_06_077_00382_060008',
        save: jest.fn().mockImplementation(function (this: any) {
          return Promise.resolve(this);
        }),
      };
      jest.spyOn(authRepository, 'findById').mockResolvedValue(mockUser as any);

      const res = await request(app)
        .patch('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .send({ selectedPlaceId: null });

      expect(res.status).toBe(200);
      expect(res.body.data.selectedPlaceId).toBeNull();
      expect(mockUser.selectedPlaceId).toBeNull();
      expect(mockUser.save).toHaveBeenCalled();
    });

    it('successfully persists matrbhoomiHistoryInterest (placeId, knowsHistory, wantsToLearn) and returns it in profile', async () => {
      const targetPlaceId = 'PL_VIL_06_077_00382_060008';
      const mockUser: any = {
        _id: new mongoose.Types.ObjectId(testUserId),
        displayName: 'Contributor',
        role: USER_ROLES.CONTRIBUTOR,
        selectedPlaceId: targetPlaceId,
        save: jest.fn().mockImplementation(function (this: any) {
          return Promise.resolve(this);
        }),
      };
      jest.spyOn(authRepository, 'findById').mockResolvedValue(mockUser as any);

      const res = await request(app)
        .patch('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .send({
          matrbhoomiHistoryInterest: {
            placeId: targetPlaceId,
            knowsHistory: true,
            wantsToLearn: false,
          },
        });

      expect(res.status).toBe(200);
      expect(res.body.data.matrbhoomiHistoryInterest).toBeDefined();
      expect(res.body.data.matrbhoomiHistoryInterest.placeId).toBe(targetPlaceId);
      expect(res.body.data.matrbhoomiHistoryInterest.knowsHistory).toBe(true);
      expect(res.body.data.matrbhoomiHistoryInterest.wantsToLearn).toBe(false);
      expect(res.body.data.matrbhoomiHistoryInterests).toBeDefined();
      expect(res.body.data.matrbhoomiHistoryInterests).toHaveLength(1);
      expect(res.body.data.matrbhoomiHistoryInterests[0].placeId).toBe(targetPlaceId);
      expect(mockUser.save).toHaveBeenCalled();
    });

    it('successfully preserves multiple place responses in matrbhoomiHistoryInterests array independently', async () => {
      const place1 = 'PL_VIL_06_077_00382_060001';
      const place2 = 'PL_VIL_06_077_00382_060002';
      const mockUser: any = {
        _id: new mongoose.Types.ObjectId(testUserId),
        displayName: 'Contributor',
        role: USER_ROLES.CONTRIBUTOR,
        selectedPlaceId: place1,
        matrbhoomiHistoryInterests: [
          {
            placeId: place1,
            knowsHistory: true,
            wantsToLearn: false,
            answeredAt: new Date(),
          },
        ],
        save: jest.fn().mockImplementation(function (this: any) {
          return Promise.resolve(this);
        }),
      };
      jest.spyOn(authRepository, 'findById').mockResolvedValue(mockUser as any);

      // Now update for place2
      const res = await request(app)
        .patch('/api/v1/auth/me')
        .set('Authorization', `Bearer ${token}`)
        .send({
          matrbhoomiHistoryInterest: {
            placeId: place2,
            knowsHistory: false,
            wantsToLearn: true,
          },
        });

      expect(res.status).toBe(200);
      expect(res.body.data.matrbhoomiHistoryInterests).toHaveLength(2);
      const interest1 = res.body.data.matrbhoomiHistoryInterests.find((i: any) => i.placeId === place1);
      const interest2 = res.body.data.matrbhoomiHistoryInterests.find((i: any) => i.placeId === place2);
      expect(interest1).toBeDefined();
      expect(interest1.knowsHistory).toBe(true);
      expect(interest2).toBeDefined();
      expect(interest2.knowsHistory).toBe(false);
      expect(interest2.wantsToLearn).toBe(true);
      // Both places are preserved independently without clobbering
      expect(mockUser.matrbhoomiHistoryInterests).toHaveLength(2);
    });
  });

  describe('Authentication Rate Limiter Enforcement', () => {
    it('enforces configured limit of 20 requests and returns 429 RATE_LIMITED on the 21st request', async () => {
      const fastHash = await bcrypt.hash('testPassword', 4);
      jest.spyOn(authRepository, 'findByEmailWithSecrets').mockResolvedValue({
        _id: 'user-rate-limit',
        email: 'rate-limit-test@example.com',
        passwordHash: fastHash,
        isActive: true,
        isEmailVerified: true,
      } as any);
      // 20 requests within rate limit
      for (let i = 0; i < 20; i++) {
        const res = await request(app).post('/api/v1/auth/login').send({
          email: 'rate-limit-test@example.com',
          password: 'wrongPassword',
        });
        // Request reaches auth validation logic (401), not 429
        expect(res.status).toBe(401);
        expect(res.headers['ratelimit-limit']).toBe('20');
        expect(res.headers['ratelimit-remaining']).toBe(String(19 - i));
      }

      // The 21st request must be blocked by authRateLimiter with HTTP 429
      const blockedRes = await request(app).post('/api/v1/auth/login').send({
        email: 'rate-limit-test@example.com',
        password: 'wrongPassword',
      });

      expect(blockedRes.status).toBe(429);
      expect(blockedRes.body.error.code).toBe('RATE_LIMITED');
      expect(blockedRes.body.error.message).toContain('Too many authentication attempts. Please try again later.');
      expect(blockedRes.headers['retry-after']).toBeDefined();
      expect(Number(blockedRes.headers['retry-after'])).toBeGreaterThan(0);
      expect(blockedRes.headers['ratelimit-remaining']).toBe('0');

      // Proves that resetAll cleanly resets the store and allows requests again
      await authRateLimitStore.resetAll();
      const afterResetRes = await request(app).post('/api/v1/auth/login').send({
        email: 'rate-limit-test@example.com',
        password: 'wrongPassword',
      });
      expect(afterResetRes.status).toBe(401);
      expect(afterResetRes.headers['ratelimit-remaining']).toBe('19');
    });
  });
});
