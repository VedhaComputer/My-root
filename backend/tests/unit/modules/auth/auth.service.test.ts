import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { AuthService } from '../../../../src/modules/auth/service';
import { AuthRepository } from '../../../../src/modules/auth/repository';
import { env } from '../../../../src/config/env';
import { getJwtPublicKey } from '../../../../src/config/keys';
import {
  AuthenticationError,
  ConflictError,
  NotFoundError,
  ServiceUnavailableError,
  ValidationError,
} from '../../../../src/shared/errors/AppError';
import { USER_ROLES } from '../../../../src/shared/constants';
import { TestMailer } from '../../../../src/shared/mail';
import crypto from 'crypto';

describe('AuthService (Unit Tests)', () => {
  let mockRepo: jest.Mocked<AuthRepository>;
  let testMailer: TestMailer;
  let authService: AuthService;

  beforeEach(() => {
    testMailer = new TestMailer();
    mockRepo = {
      createUser: jest.fn(),
      emailExists: jest.fn(),
      findByEmailWithSecrets: jest.fn(),
      findById: jest.fn(),
      saveRefreshToken: jest.fn(),
      findActiveRefreshToken: jest.fn(),
      findTokenByHash: jest.fn(),
      findByStoredTokenHash: jest.fn(),
      rollbackTokenRotation: jest.fn(),
      atomicRotateRefreshToken: jest.fn(),
      revokeRefreshToken: jest.fn(),
      revokeTokenFamily: jest.fn(),
      revokeAllUserRefreshTokens: jest.fn(),
      incrementTokenVersion: jest.fn(),
      setEmailVerificationToken: jest.fn(),
      findByEmailVerificationToken: jest.fn(),
      markEmailVerified: jest.fn(),
      setPasswordResetToken: jest.fn(),
      findByPasswordResetToken: jest.fn(),
      resetPassword: jest.fn(),
    } as unknown as jest.Mocked<AuthRepository>;

    authService = new AuthService(mockRepo, {} as any, testMailer);
  });

  describe('register', () => {
    it('successfully registers a user with normalized email and hashed password', async () => {
      mockRepo.emailExists.mockResolvedValue(false);
      mockRepo.createUser.mockResolvedValue({
        id: 'u1',
        displayName: 'Aarav Sharma',
        role: USER_ROLES.CONTRIBUTOR,
      } as any);

      const result = await authService.register({
        displayName: '  Aarav Sharma  ',
        email: '  Aarav@Example.com  ',
        password: 'securePassword123',
      });

      expect(mockRepo.emailExists).toHaveBeenCalledWith('aarav@example.com');
      expect(mockRepo.createUser).toHaveBeenCalledWith(
        expect.objectContaining({
          displayName: 'Aarav Sharma',
          email: 'aarav@example.com',
          passwordHash: expect.any(String),
        })
      );
      // Password hash must not be the raw password
      const savedHash = mockRepo.createUser.mock.calls[0][0].passwordHash;
      expect(savedHash).not.toBe('securePassword123');
      expect(await bcrypt.compare('securePassword123', savedHash)).toBe(true);

      expect(result).toEqual({
        message: 'Registration successful. Please verify your email.',
      });
      // Verification token must be dispatched via mailer with unhashed token
      expect(testMailer.sentEmails).toHaveLength(1);
      expect(testMailer.sentEmails[0].to).toBe('aarav@example.com');
      const sentToken = testMailer.sentEmails[0].token;
      expect(sentToken).toMatch(/^[0-9a-f]{64}$/);
      expect(testMailer.sentEmails[0].url).toBe(`http://localhost:3000/verify-email?token=${sentToken}`);

      // Database repository must receive SHA-256 hash of the token, NOT raw token
      const expectedHash = crypto.createHash('sha256').update(sentToken).digest('hex');
      expect(mockRepo.setEmailVerificationToken).toHaveBeenCalledWith(
        'u1',
        expectedHash,
        expect.any(Date)
      );

      // Raw token or verification link must NOT be returned in result
      expect((result as any).token).toBeUndefined();
      expect((result as any).verificationToken).toBeUndefined();
      expect((result as any).url).toBeUndefined();
    });

    it('returns uniform success message and creates user without leaking token when mailer delivery fails during registration', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue(null);
      mockRepo.createUser.mockResolvedValue({
        id: 'u-fail',
        displayName: 'Test User',
        role: USER_ROLES.CONTRIBUTOR,
      } as any);
      testMailer.shouldFail = true;

      const result = await authService.register({
        displayName: 'Test User',
        email: 'testfail@example.com',
        password: 'securePassword123',
      });

      expect(result).toEqual({
        message: 'Registration successful. Please verify your email.',
      });
      expect((result as any).token).toBeUndefined();
      expect((result as any).verificationToken).toBeUndefined();
    });

    it('allows retry registration for existing unverified account and dispatches new verification email', async () => {
      mockRepo.emailExists.mockResolvedValue(true);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'u-unverified-retry',
        email: 'unverified@example.com',
        displayName: 'Aarav Sharma',
        role: USER_ROLES.CONTRIBUTOR,
        isEmailVerified: false,
      } as any);

      const result = await authService.register({
        displayName: 'Aarav Sharma',
        email: 'unverified@example.com',
        password: 'securePassword123',
      });

      expect(result).toEqual({
        message: 'Registration successful. Please verify your email.',
      });
      expect(testMailer.sentEmails).toHaveLength(1);
      expect(testMailer.sentEmails[0].to).toBe('unverified@example.com');
      expect(mockRepo.setEmailVerificationToken).toHaveBeenCalledWith(
        'u-unverified-retry',
        expect.any(String),
        expect.any(Date)
      );
    });

    it('returns generic uniform message without creating duplicate account if email is already registered', async () => {
      mockRepo.emailExists.mockResolvedValue(true);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'u-existing',
        isEmailVerified: true,
      } as any);

      const result = await authService.register({
        displayName: 'Aarav Sharma',
        email: 'existing@example.com',
        password: 'password123',
      });

      expect(result).toEqual({ message: 'Registration successful. Please verify your email.' });
      expect(mockRepo.createUser).not.toHaveBeenCalled();
    });
  });

  describe('login', () => {
    it('successfully logs in with valid credentials and returns tokens and user DTO', async () => {
      const passwordHash = await bcrypt.hash('mySecretPass123', 10);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-001',
        displayName: 'Meera Patel',
        email: 'meera@example.com',
        passwordHash,
        role: USER_ROLES.LOCAL_CONTRIBUTOR,
        isActive: true,
        isEmailVerified: true,
      } as any);
      mockRepo.saveRefreshToken.mockResolvedValue({} as any);

      const result = await authService.login({
        email: '  MEERA@example.com ',
        password: 'mySecretPass123',
      });

      expect(result.user).toEqual({
        id: 'user-001',
        displayName: 'Meera Patel',
        role: USER_ROLES.LOCAL_CONTRIBUTOR,
      });
      // Email and passwordHash must not be exposed in user DTO
      expect((result.user as any).email).toBeUndefined();
      expect((result.user as any).passwordHash).toBeUndefined();

      expect(result.accessToken).toBeDefined();
      expect(result.refreshToken).toBeDefined();

      const decodedAccess = jwt.verify(result.accessToken, getJwtPublicKey(), {
        algorithms: ['RS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      }) as any;
      expect(decodedAccess.userId).toBe('user-001');
      expect(decodedAccess.sub).toBe('user-001');
      expect(decodedAccess.iss).toBe('myroot-backend');
      expect(decodedAccess.aud).toBe('myroot-platform');
      expect(decodedAccess.role).toBe(USER_ROLES.LOCAL_CONTRIBUTOR);
      expect(decodedAccess.email).toBe('meera@example.com');
      expect(decodedAccess.displayName).toBe('Meera Patel');
      expect(decodedAccess.tokenVersion).toBe(1);

      const decodedRefresh = jwt.verify(result.refreshToken, env.JWT_REFRESH_SECRET) as any;
      expect(decodedRefresh.userId).toBe('user-001');
      expect(decodedRefresh.tokenVersion).toBe(1);

      expect(mockRepo.saveRefreshToken).toHaveBeenCalledWith(
        'user-001',
        result.refreshToken,
        expect.any(Date),
        expect.any(String)
      );
    });

    it('embeds authoritative tokenVersion in access token when user has custom tokenVersion', async () => {
      const passwordHash = await bcrypt.hash('mySecretPass123', 10);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-002',
        displayName: 'Aarav',
        email: 'aarav@example.com',
        passwordHash,
        role: USER_ROLES.CONTRIBUTOR,
        tokenVersion: 5,
        isActive: true,
        isEmailVerified: true,
      } as any);
      mockRepo.saveRefreshToken.mockResolvedValue({} as any);

      const result = await authService.login({
        email: 'aarav@example.com',
        password: 'mySecretPass123',
      });

      const decodedAccess = jwt.verify(result.accessToken, getJwtPublicKey(), {
        algorithms: ['RS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      }) as any;
      expect(decodedAccess.tokenVersion).toBe(5);

      const decodedRefresh = jwt.verify(result.refreshToken, env.JWT_REFRESH_SECRET) as any;
      expect(decodedRefresh.tokenVersion).toBe(5);
    });

    it('throws AuthenticationError with generic sanitized error and issues no tokens when email is not verified', async () => {
      const passwordHash = await bcrypt.hash('mySecretPass123', 10);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-unverified',
        displayName: 'Unverified User',
        email: 'unverified@example.com',
        passwordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: false,
      } as any);

      await expect(
        authService.login({
          email: 'unverified@example.com',
          password: 'mySecretPass123',
        })
      ).rejects.toThrow(AuthenticationError);

      await expect(
        authService.login({
          email: 'unverified@example.com',
          password: 'mySecretPass123',
        })
      ).rejects.toThrow('Invalid email or password');

      expect(mockRepo.saveRefreshToken).not.toHaveBeenCalled();
    });

    it('throws AuthenticationError with generic message when email is not found and invokes bcrypt.compare with DUMMY_HASH to prevent timing attacks', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue(null);
      const compareSpy = jest.spyOn(bcrypt, 'compare');

      await expect(
        authService.login({
          email: 'unknown@example.com',
          password: 'password123',
        })
      ).rejects.toThrow(AuthenticationError);

      expect(compareSpy).toHaveBeenCalledWith(
        'password123',
        expect.stringMatching(/^\$2[abxy]?\$\d{2}\$/)
      );
      compareSpy.mockRestore();
    });

    it('throws AuthenticationError when password is wrong and invokes bcrypt.compare with user passwordHash', async () => {
      const passwordHash = await bcrypt.hash('correctPassword123', 10);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-001',
        displayName: 'Meera',
        email: 'meera@example.com',
        passwordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: true,
      } as any);

      const compareSpy = jest.spyOn(bcrypt, 'compare');

      await expect(
        authService.login({
          email: 'meera@example.com',
          password: 'wrongPassword',
        })
      ).rejects.toThrow(AuthenticationError);

      expect(compareSpy).toHaveBeenCalledWith('wrongPassword', passwordHash);
      compareSpy.mockRestore();
    });

    it('throws AuthenticationError (not AuthorizationError) when user account is disabled — prevents account-status enumeration via HTTP status', async () => {
      // Security regression: a disabled account with a CORRECT password must throw
      // AuthenticationError (HTTP 401) so that callers cannot distinguish a disabled
      // account from an invalid password by comparing response codes (403 vs 401).
      const passwordHash = await bcrypt.hash('password123', 10);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-001',
        displayName: 'Disabled User',
        email: 'disabled@example.com',
        passwordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: false,
        isEmailVerified: true,
      } as any);

      const err = await authService
        .login({ email: 'disabled@example.com', password: 'password123' })
        .catch((e) => e);

      expect(err).toBeInstanceOf(AuthenticationError);
      expect(err.statusCode).toBe(401);
      // Message must match the generic wrong-credential message — not reveal disabled status
      expect(err.message).toBe('Invalid email or password');
    });

    it('disabled account and wrong password are indistinguishable — both throw AuthenticationError with statusCode 401', async () => {
      // Regression: ensures that login() never leaks whether an account is disabled
      // vs has a wrong password via distinct error types or status codes.
      const passwordHash = await bcrypt.hash('correct', 10);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-002',
        displayName: 'Disabled User 2',
        email: 'disabled2@example.com',
        passwordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: false,
        isEmailVerified: true,
      } as any);

      const disabledErr = await authService
        .login({ email: 'disabled2@example.com', password: 'correct' })
        .catch((e) => e);

      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-003',
        displayName: 'Active User',
        email: 'active@example.com',
        passwordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: true,
      } as any);

      const wrongPassErr = await authService
        .login({ email: 'active@example.com', password: 'wrong' })
        .catch((e) => e);

      expect(disabledErr).toBeInstanceOf(AuthenticationError);
      expect(wrongPassErr).toBeInstanceOf(AuthenticationError);
      expect(disabledErr.statusCode).toBe(wrongPassErr.statusCode);
      expect(disabledErr.message).toBe(wrongPassErr.message);
    });
  });

  describe('refreshToken', () => {
    it('successfully rotates refresh token and returns new token pair', async () => {
      const rawToken = jwt.sign({ userId: 'u123', tokenVersion: 1 }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      mockRepo.findActiveRefreshToken.mockResolvedValue({
        tokenHash: 'somehash',
        userId: 'u123' as any,
        revoked: false,
      } as any);
      mockRepo.findById.mockResolvedValue({
        _id: 'u123',
        displayName: 'Dev',
        email: 'dev@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        tokenVersion: 1,
      } as any);
      mockRepo.revokeRefreshToken.mockResolvedValue(true);
      mockRepo.saveRefreshToken.mockResolvedValue({} as any);

      const result = await authService.refreshToken(rawToken);

      expect(mockRepo.revokeRefreshToken).toHaveBeenCalledWith(rawToken);
      expect(result.accessToken).toBeDefined();

      const decodedRotatedAccess = jwt.verify(result.accessToken, getJwtPublicKey(), {
        algorithms: ['RS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      }) as any;
      expect(decodedRotatedAccess.userId).toBe('u123');
      expect(decodedRotatedAccess.sub).toBe('u123');
      expect(decodedRotatedAccess.iss).toBe('myroot-backend');
      expect(decodedRotatedAccess.aud).toBe('myroot-platform');
      expect(decodedRotatedAccess.role).toBe(USER_ROLES.CONTRIBUTOR);
      expect(decodedRotatedAccess.tokenVersion).toBe(1);

      expect(result.refreshToken).toBeDefined();
      expect(result.refreshToken).not.toBe(rawToken);
      const decodedRotatedRefresh = jwt.verify(result.refreshToken, env.JWT_REFRESH_SECRET) as any;
      expect(decodedRotatedRefresh.tokenVersion).toBe(1);
      expect(mockRepo.saveRefreshToken).toHaveBeenCalledWith(
        'u123',
        result.refreshToken,
        expect.any(Date),
        expect.any(String)
      );
    });

    it('throws AuthenticationError when refresh token signature is invalid', async () => {
      const badToken = jwt.sign({ userId: 'u123', tokenVersion: 1 }, 'wrong_secret_at_least_32_characters_long');

      await expect(authService.refreshToken(badToken)).rejects.toThrow(AuthenticationError);
    });

    it('throws AuthenticationError when refresh token is missing tokenVersion claim (fails closed)', async () => {
      const tokenWithoutVersion = jwt.sign({ userId: 'u123' }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      mockRepo.findActiveRefreshToken.mockResolvedValue({
        tokenHash: 'somehash',
        userId: 'u123' as any,
        revoked: false,
      } as any);
      mockRepo.findById.mockResolvedValue({
        _id: 'u123',
        isActive: true,
        tokenVersion: 1,
      } as any);

      await expect(authService.refreshToken(tokenWithoutVersion)).rejects.toThrow(AuthenticationError);
      await expect(authService.refreshToken(tokenWithoutVersion)).rejects.toThrow('Invalid or expired refresh token');
    });

    it('throws AuthenticationError when tokenVersion claim has invalid type (string, negative, float)', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'u123',
        isActive: true,
        tokenVersion: 1,
      } as any);

      const stringVersionToken = jwt.sign({ userId: 'u123', tokenVersion: '1' }, env.JWT_REFRESH_SECRET);
      await expect(authService.refreshToken(stringVersionToken)).rejects.toThrow('Invalid or expired refresh token');

      const negativeVersionToken = jwt.sign({ userId: 'u123', tokenVersion: -1 }, env.JWT_REFRESH_SECRET);
      await expect(authService.refreshToken(negativeVersionToken)).rejects.toThrow('Invalid or expired refresh token');

      const floatVersionToken = jwt.sign({ userId: 'u123', tokenVersion: 1.5 }, env.JWT_REFRESH_SECRET);
      await expect(authService.refreshToken(floatVersionToken)).rejects.toThrow('Invalid or expired refresh token');
    });

    it('accepts matching tokenVersion claim and issues rotated tokens stamped with current version', async () => {
      const validToken = jwt.sign({ userId: 'u123', tokenVersion: 4 }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      mockRepo.findActiveRefreshToken.mockResolvedValue({
        tokenHash: 'activehash',
        userId: 'u123' as any,
        revoked: false,
      } as any);
      mockRepo.findById.mockResolvedValue({
        _id: 'u123',
        displayName: 'Custom Version User',
        email: 'v4@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        tokenVersion: 4,
      } as any);
      mockRepo.revokeRefreshToken.mockResolvedValue(true);
      mockRepo.saveRefreshToken.mockResolvedValue({} as any);

      const result = await authService.refreshToken(validToken);

      const decodedAccess = jwt.verify(result.accessToken, getJwtPublicKey(), {
        algorithms: ['RS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      }) as any;
      expect(decodedAccess.tokenVersion).toBe(4);

      const decodedRefresh = jwt.verify(result.refreshToken, env.JWT_REFRESH_SECRET) as any;
      expect(decodedRefresh.tokenVersion).toBe(4);
    });

    it('throws persistence error and leaves old token revoked (fail closed) when saveRefreshToken fails in standalone path', async () => {
      const rawToken = jwt.sign({ userId: 'u123', tokenVersion: 1 }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      mockRepo.findActiveRefreshToken.mockResolvedValue({
        tokenHash: 'somehash',
        userId: 'u123' as any,
        revoked: false,
      } as any);
      mockRepo.findById.mockResolvedValue({
        _id: 'u123',
        displayName: 'Dev',
        email: 'dev@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        tokenVersion: 1,
      } as any);
      mockRepo.revokeRefreshToken.mockResolvedValue(true);
      // saveRefreshToken fails — old token already revoked; fail closed, propagate error, no credentials returned
      mockRepo.saveRefreshToken.mockRejectedValue(new Error('Persistence failed: connection dropped'));

      await expect(authService.refreshToken(rawToken)).rejects.toThrow('Persistence failed: connection dropped');
      // Rollback must NOT be attempted: old token remains revoked to prevent dual-active token state
      expect(mockRepo.rollbackTokenRotation).not.toHaveBeenCalled();
    });

    it('fails closed with 401 when revoked token has replacedByTokenHash but replacement was never persisted (aborted rotation)', async () => {
      const rawToken = jwt.sign({ userId: 'u123', tokenVersion: 1 }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      // Token was previously marked revoked with a replacement hash during aborted rotation
      mockRepo.findTokenByHash.mockResolvedValue({
        tokenHash: 'somehash',
        userId: 'u123' as any,
        revoked: true,
        replacedByTokenHash: 'unpersisted-replacement-hash',
        tokenFamily: 'family-1',
      } as any);

      // Replacement token was never persisted in database (partial failure)
      mockRepo.findByStoredTokenHash.mockResolvedValue(null);

      // Fail closed: require reauthentication; must not revoke family or increment tokenVersion
      await expect(authService.refreshToken(rawToken)).rejects.toThrow(
        'Token rotation was interrupted. Please log in again.'
      );
      // Must NOT attempt rollback (old token stays revoked)
      expect(mockRepo.rollbackTokenRotation).not.toHaveBeenCalled();
      // Must NOT revoke other sessions or increment tokenVersion
      expect(mockRepo.revokeTokenFamily).not.toHaveBeenCalled();
      expect(mockRepo.revokeAllUserRefreshTokens).not.toHaveBeenCalled();
      expect(mockRepo.incrementTokenVersion).not.toHaveBeenCalled();
    });

    it('strictly triggers token reuse detection when revoked token has an existing replacement token in database', async () => {
      const reusedToken = jwt.sign({ userId: 'u123', tokenVersion: 1 }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      mockRepo.findTokenByHash.mockResolvedValue({
        tokenHash: 'reused-hash',
        userId: 'u123' as any,
        revoked: true,
        replacedByTokenHash: 'existing-replacement-hash',
        tokenFamily: 'family-1',
      } as any);

      // Replacement token DOES exist in database (genuine rotation occurred earlier)
      mockRepo.findByStoredTokenHash.mockResolvedValue({
        tokenHash: 'existing-replacement-hash',
      } as any);

      await expect(authService.refreshToken(reusedToken)).rejects.toThrow(AuthenticationError);
      await expect(authService.refreshToken(reusedToken)).rejects.toThrow('Refresh token reuse detected. All active sessions have been revoked.');
      expect(mockRepo.revokeTokenFamily).toHaveBeenCalledWith('family-1');
      expect(mockRepo.revokeAllUserRefreshTokens).toHaveBeenCalledWith('u123');
      expect(mockRepo.incrementTokenVersion).toHaveBeenCalledWith('u123');
    });

    it('throws error and does not return credentials when MongoDB is disconnected during user lookup', async () => {
      const rawToken = jwt.sign({ userId: 'u123', tokenVersion: 1 }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });

      mockRepo.findActiveRefreshToken.mockResolvedValue({
        tokenHash: 'somehash',
        userId: 'u123' as any,
        revoked: false,
      } as any);
      mockRepo.findById.mockRejectedValue(new Error('MongoNetworkTimeoutException: connection timed out'));

      await expect(authService.refreshToken(rawToken)).rejects.toThrow('MongoNetworkTimeoutException');
    });

    it('rejects refresh token signed with unexpected algorithm (e.g. HS384) enforcing pinned HS256 algorithm', async () => {
      const hs384Token = jwt.sign(
        { userId: 'u123', tokenVersion: 1 },
        env.JWT_REFRESH_SECRET,
        { algorithm: 'HS384', expiresIn: '7d' }
      );

      await expect(authService.refreshToken(hs384Token)).rejects.toThrow(AuthenticationError);
      await expect(authService.refreshToken(hs384Token)).rejects.toThrow('Invalid or expired refresh token');
    });

    it('rejects refresh token signed with wrong secret', async () => {
      const wrongSecretToken = jwt.sign(
        { userId: 'u123', tokenVersion: 1 },
        'wrong_secret_at_least_32_characters_long_for_test',
        { algorithm: 'HS256', expiresIn: '7d' }
      );

      await expect(authService.refreshToken(wrongSecretToken)).rejects.toThrow(AuthenticationError);
      await expect(authService.refreshToken(wrongSecretToken)).rejects.toThrow('Invalid or expired refresh token');
    });

    it('throws AuthenticationError when refresh token is not found or revoked in database', async () => {
      const token = jwt.sign({ userId: 'u123', tokenVersion: 1 }, env.JWT_REFRESH_SECRET, { expiresIn: '7d' });
      mockRepo.findTokenByHash.mockResolvedValue(null);
      mockRepo.findActiveRefreshToken.mockResolvedValue(null);
      mockRepo.findById.mockResolvedValue({
        _id: 'u123',
        isActive: true,
        tokenVersion: 1,
      } as any);

      await expect(authService.refreshToken(token)).rejects.toThrow(AuthenticationError);
    });

    it('throws AuthenticationError and revokes session when refresh token has stale tokenVersion', async () => {
      // Refresh token issued under tokenVersion 1
      const staleToken = jwt.sign(
        { userId: 'u123', tokenVersion: 1 },
        env.JWT_REFRESH_SECRET,
        { expiresIn: '7d' }
      );

      mockRepo.findTokenByHash.mockResolvedValue({
        tokenHash: 'hash-1',
        userId: 'u123' as any,
        revoked: false,
      } as any);
      // User in database was incremented to tokenVersion 2 (e.g. via password reset)
      mockRepo.findById.mockResolvedValue({
        _id: 'u123',
        displayName: 'Dev',
        email: 'dev@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        tokenVersion: 2,
      } as any);

      await expect(authService.refreshToken(staleToken)).rejects.toThrow(AuthenticationError);
      await expect(authService.refreshToken(staleToken)).rejects.toThrow('Token has been revoked');
      expect(mockRepo.saveRefreshToken).not.toHaveBeenCalled();
    });
  });

  describe('logout', () => {
    it('revokes specific refresh token when provided', async () => {
      mockRepo.revokeRefreshToken.mockResolvedValue(true);

      const result = await authService.logout('user-1', 'specific-token');

      expect(mockRepo.revokeRefreshToken).toHaveBeenCalledWith('specific-token');
      expect(result).toEqual({ message: 'Logged out successfully' });
    });

    it('revokes all refresh tokens for user when no token is specified', async () => {
      mockRepo.revokeAllUserRefreshTokens.mockResolvedValue(2);

      const result = await authService.logout('user-1');

      expect(mockRepo.revokeAllUserRefreshTokens).toHaveBeenCalledWith('user-1');
      expect(result).toEqual({ message: 'Logged out successfully' });
    });

    it('propagates ServiceUnavailableError when revokeRefreshToken fails due to database disconnection', async () => {
      mockRepo.revokeRefreshToken.mockRejectedValue(
        new ServiceUnavailableError('Authentication service unavailable: database disconnected')
      );

      await expect(authService.logout('user-1', 'specific-token')).rejects.toThrow(
        ServiceUnavailableError
      );
    });
  });

  describe('verifyEmail', () => {
    it('successfully verifies email with valid unexpired token and marks email verified', async () => {
      const rawToken = 'valid-hex-token-1234567890abcdef1234567890abcdef';
      const expectedHash = crypto.createHash('sha256').update(rawToken).digest('hex');

      mockRepo.findByEmailVerificationToken.mockResolvedValue({
        _id: 'user-to-verify',
        email: 'verify@example.com',
        isEmailVerified: false,
      } as any);
      mockRepo.markEmailVerified.mockResolvedValue();

      const result = await authService.verifyEmail(rawToken);

      expect(result).toEqual({ message: 'Email verified successfully' });
      expect(mockRepo.findByEmailVerificationToken).toHaveBeenCalledWith(expectedHash);
      expect(mockRepo.markEmailVerified).toHaveBeenCalledWith('user-to-verify');
      expect((result as any).token).toBeUndefined();
    });

    it('throws ValidationError when token is invalid or does not match any record', async () => {
      mockRepo.findByEmailVerificationToken.mockResolvedValue(null);

      await expect(authService.verifyEmail('invalid-token')).rejects.toThrow(ValidationError);
      await expect(authService.verifyEmail('invalid-token')).rejects.toThrow('Invalid or expired verification token');
      expect(mockRepo.markEmailVerified).not.toHaveBeenCalled();
    });

    it('throws ValidationError when verification token has expired', async () => {
      mockRepo.findByEmailVerificationToken.mockResolvedValue(null);

      await expect(authService.verifyEmail('expired-token')).rejects.toThrow(ValidationError);
      await expect(authService.verifyEmail('expired-token')).rejects.toThrow('Invalid or expired verification token');
      expect(mockRepo.markEmailVerified).not.toHaveBeenCalled();
    });

    it('rejects repeated token use because token is invalidated upon first verification', async () => {
      const rawToken = 'single-use-token-abc';
      const expectedHash = crypto.createHash('sha256').update(rawToken).digest('hex');

      // First call finds user
      mockRepo.findByEmailVerificationToken.mockResolvedValueOnce({
        _id: 'user-single-use',
        isEmailVerified: false,
      } as any);
      mockRepo.markEmailVerified.mockResolvedValueOnce();

      const firstResult = await authService.verifyEmail(rawToken);
      expect(firstResult).toEqual({ message: 'Email verified successfully' });
      expect(mockRepo.markEmailVerified).toHaveBeenCalledWith('user-single-use');

      // Subsequent call: token was cleared, so repository returns null
      mockRepo.findByEmailVerificationToken.mockResolvedValueOnce(null);

      await expect(authService.verifyEmail(rawToken)).rejects.toThrow(ValidationError);
      await expect(authService.verifyEmail(rawToken)).rejects.toThrow('Invalid or expired verification token');
    });

    it('propagates ServiceUnavailableError when markEmailVerified encounters disconnected database', async () => {
      mockRepo.findByEmailVerificationToken.mockResolvedValue({
        _id: 'user-1',
        isEmailVerified: false,
      } as any);
      mockRepo.markEmailVerified.mockRejectedValue(
        new ServiceUnavailableError('Authentication service unavailable: database disconnected')
      );

      await expect(authService.verifyEmail('valid-token-str')).rejects.toThrow(
        ServiceUnavailableError
      );
    });
  });

  describe('requestPasswordReset', () => {
    it('dispatches password reset email with unhashed token while storing SHA-256 hash in database', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-reset-1',
        email: 'resetme@example.com',
        displayName: 'Reset User',
        isActive: true,
      } as any);

      const result = await authService.requestPasswordReset('  ResetMe@Example.com ');

      expect(result).toEqual({
        message: 'If an account exists with this email, password reset instructions have been sent.',
      });

      // Mailer must receive unhashed raw token
      expect(testMailer.sentEmails).toHaveLength(1);
      expect(testMailer.sentEmails[0].to).toBe('resetme@example.com');
      const sentToken = testMailer.sentEmails[0].token;
      expect(sentToken).toMatch(/^[0-9a-f]{64}$/);
      expect(testMailer.sentEmails[0].url).toBe(`http://localhost:3000/reset-password?token=${sentToken}`);

      // Database repository must receive SHA-256 hash of the token, NOT raw token
      const expectedHash = crypto.createHash('sha256').update(sentToken).digest('hex');
      expect(mockRepo.setPasswordResetToken).toHaveBeenCalledWith(
        'user-reset-1',
        expectedHash,
        expect.any(Date)
      );

      // Raw token or reset link must NOT be returned in result
      expect((result as any).token).toBeUndefined();
      expect((result as any).resetToken).toBeUndefined();
      expect((result as any).url).toBeUndefined();
    });

    it('returns uniform generic response and performs dummy work without calling mailer when email does not exist', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue(null);

      const result = await authService.requestPasswordReset('unknown@example.com');

      expect(result).toEqual({
        message: 'If an account exists with this email, password reset instructions have been sent.',
      });
      expect(testMailer.sentEmails).toHaveLength(0);
      expect(mockRepo.setPasswordResetToken).not.toHaveBeenCalled();
    });

    it('returns uniform generic response and avoids enumeration without leaking token when mailer delivery fails', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-reset-1',
        email: 'resetme@example.com',
        isActive: true,
      } as any);
      testMailer.shouldFail = true;

      const result = await authService.requestPasswordReset('resetme@example.com');

      expect(result).toEqual({
        message: 'If an account exists with this email, password reset instructions have been sent.',
      });
      expect((result as any).token).toBeUndefined();
      expect((result as any).resetToken).toBeUndefined();
    });
  });

  describe('resetPassword', () => {
    it('propagates ServiceUnavailableError when resetPassword encounters disconnected database', async () => {
      mockRepo.findByPasswordResetToken.mockResolvedValue({
        _id: 'user-1',
      } as any);
      mockRepo.resetPassword.mockRejectedValue(
        new ServiceUnavailableError('Authentication service unavailable: database disconnected')
      );

      await expect(authService.resetPassword('valid-token-str', 'newPass12345')).rejects.toThrow(
        ServiceUnavailableError
      );
    });

    it('invalidates refresh token via tokenVersion even if revokeAllUserRefreshTokens fails', async () => {
      const userId = 'u-recovery-1';
      mockRepo.findByPasswordResetToken.mockResolvedValue({
        _id: userId,
        tokenVersion: 1,
      } as any);
      mockRepo.resetPassword.mockResolvedValue();
      mockRepo.revokeAllUserRefreshTokens.mockRejectedValue(
        new ServiceUnavailableError('Authentication service unavailable: database disconnected')
      );

      // Password reset attempts to revoke tokens, and fails at step 2
      await expect(authService.resetPassword('valid-reset-token', 'BrandNewPass123!')).rejects.toThrow(
        ServiceUnavailableError
      );

      // Pre-reset refresh token carrying tokenVersion: 1
      const preResetRefreshToken = jwt.sign(
        { userId, tokenVersion: 1 },
        env.JWT_REFRESH_SECRET,
        { expiresIn: '7d' }
      );

      // Attempting to refresh with the pre-reset token against updated user (tokenVersion: 2)
      mockRepo.findTokenByHash.mockResolvedValue({
        tokenHash: 'hash-pre',
        userId: userId as any,
        revoked: false, // Unrevoked because step 2 failed
      } as any);
      mockRepo.findById.mockResolvedValue({
        _id: userId,
        tokenVersion: 2, // Incremented by step 1
        isActive: true,
      } as any);

      await expect(authService.refreshToken(preResetRefreshToken)).rejects.toThrow(AuthenticationError);
      await expect(authService.refreshToken(preResetRefreshToken)).rejects.toThrow('Token has been revoked');
    });
  });

  describe('getMe', () => {
    it('returns sanitized user info', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'u-99',
        displayName: 'Pooja',
        role: USER_ROLES.REVIEWER,
      } as any);

      const result = await authService.getMe('u-99');

      expect(result).toEqual({
        id: 'u-99',
        displayName: 'Pooja',
        role: USER_ROLES.REVIEWER,
      });
    });

    it('throws NotFoundError if user is not found', async () => {
      mockRepo.findById.mockResolvedValue(null);

      await expect(authService.getMe('u-missing')).rejects.toThrow(NotFoundError);
    });
  });
});
