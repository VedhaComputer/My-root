import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { AuthService } from '../../../../src/modules/auth/service';
import { AuthRepository } from '../../../../src/modules/auth/repository';
import { AuthenticationError, ValidationError } from '../../../../src/shared/errors/AppError';
import { USER_ROLES } from '../../../../src/shared/constants';
import { TestMailer } from '../../../../src/shared/mail';
import { env } from '../../../../src/config/env';
import { getJwtPublicKey } from '../../../../src/config/keys';

describe('Legacy User & Email Verification Security (Regression Tests)', () => {
  let mockRepo: jest.Mocked<AuthRepository>;
  let testMailer: TestMailer;
  let authService: AuthService;

  const validPassword = 'correctPassword123!';
  let validPasswordHash: string;

  beforeAll(async () => {
    validPasswordHash = await bcrypt.hash(validPassword, 10);
  });

  beforeEach(() => {
    testMailer = new TestMailer();
    mockRepo = {
      createUser: jest.fn(),
      emailExists: jest.fn(),
      findByEmailWithSecrets: jest.fn(),
      findById: jest.fn(),
      saveRefreshToken: jest.fn().mockResolvedValue({} as any),
      findActiveRefreshToken: jest.fn(),
      findTokenByHash: jest.fn(),
      findByStoredTokenHash: jest.fn(),
      rollbackTokenRotation: jest.fn(),
      atomicRotateRefreshToken: jest.fn(),
      revokeRefreshToken: jest.fn(),
      revokeTokenFamily: jest.fn(),
      revokeAllUserRefreshTokens: jest.fn().mockResolvedValue(1),
      incrementTokenVersion: jest.fn(),
      setEmailVerificationToken: jest.fn().mockResolvedValue(undefined),
      findByEmailVerificationToken: jest.fn(),
      markEmailVerified: jest.fn().mockResolvedValue(undefined),
      setPasswordResetToken: jest.fn().mockResolvedValue(undefined),
      findByPasswordResetToken: jest.fn(),
      resetPassword: jest.fn().mockResolvedValue(undefined),
    } as unknown as jest.Mocked<AuthRepository>;

    authService = new AuthService(mockRepo, {} as any, testMailer);
  });

  describe('1. Verified user logging in successfully with valid credentials', () => {
    it('allows login, issues access and refresh tokens, and saves refresh token', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-verified-01',
        displayName: 'Verified User',
        email: 'verified@example.com',
        passwordHash: validPasswordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: true,
        tokenVersion: 1,
      } as any);

      const result = await authService.login({
        email: 'verified@example.com',
        password: validPassword,
      });

      expect(result.accessToken).toBeDefined();
      expect(result.refreshToken).toBeDefined();
      expect(result.user).toEqual({
        id: 'user-verified-01',
        displayName: 'Verified User',
        role: USER_ROLES.CONTRIBUTOR,
      });

      // Verify JWT claims
      const decoded = jwt.verify(result.accessToken, getJwtPublicKey(), {
        algorithms: ['RS256'],
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
      }) as any;
      expect(decoded.userId).toBe('user-verified-01');
      expect(mockRepo.saveRefreshToken).toHaveBeenCalledTimes(1);
    });
  });

  describe('2. Explicitly unverified user being denied login', () => {
    it('denies login with sanitized AuthenticationError and issues no tokens when isEmailVerified is explicitly false', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-unverified-01',
        displayName: 'Unverified User',
        email: 'unverified@example.com',
        passwordHash: validPasswordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: false,
        tokenVersion: 1,
      } as any);

      await expect(
        authService.login({
          email: 'unverified@example.com',
          password: validPassword,
        })
      ).rejects.toThrow(AuthenticationError);

      await expect(
        authService.login({
          email: 'unverified@example.com',
          password: validPassword,
        })
      ).rejects.toThrow('Invalid email or password');

      expect(mockRepo.saveRefreshToken).not.toHaveBeenCalled();
      expect(mockRepo.markEmailVerified).not.toHaveBeenCalled();
    });
  });

  describe('3. Legacy user with a missing verification field following intended secure recovery behavior', () => {
    it('denies login initially when isEmailVerified field is missing (undefined)', async () => {
      // Legacy document without isEmailVerified field
      const legacyUser: any = {
        _id: 'user-legacy-01',
        displayName: 'Legacy User',
        email: 'legacy@example.com',
        passwordHash: validPasswordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        // isEmailVerified is completely missing (undefined)
      };
      mockRepo.findByEmailWithSecrets.mockResolvedValue(legacyUser);

      await expect(
        authService.login({
          email: 'legacy@example.com',
          password: validPassword,
        })
      ).rejects.toThrow(AuthenticationError);

      await expect(
        authService.login({
          email: 'legacy@example.com',
          password: validPassword,
        })
      ).rejects.toThrow('Invalid email or password');

      expect(mockRepo.saveRefreshToken).not.toHaveBeenCalled();
      // Must not auto-verify legacy user on failed login
      expect(mockRepo.markEmailVerified).not.toHaveBeenCalled();
    });

    it('recovers legacy user securely via email verification flow and succeeds login afterwards', async () => {
      // State representing the database document for the legacy user
      const dbUser: any = {
        _id: 'user-legacy-01',
        displayName: 'Vinod',
        email: 'raj04846@gmail.com',
        passwordHash: validPasswordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: undefined, // Missing field in legacy record
        tokenVersion: 1,
      };

      mockRepo.findByEmailWithSecrets.mockImplementation(async () => ({ ...dbUser }));

      // Step 1: Pre-recovery login fails
      await expect(
        authService.login({
          email: 'raj04846@gmail.com',
          password: validPassword,
        })
      ).rejects.toThrow('Invalid email or password');

      // Step 2: Request verification email (explicit recovery via resendVerificationEmail)
      let storedTokenHash: string | null = null;
      mockRepo.setEmailVerificationToken.mockImplementation(async (_userId, hash) => {
        storedTokenHash = hash;
        dbUser.emailVerificationTokenHash = hash;
        dbUser.emailVerificationExpiresAt = new Date(Date.now() + 86400000);
      });

      const resendResult = await authService.resendVerificationEmail('raj04846@gmail.com');
      expect(resendResult.message).toBe(
        'If an unverified account exists with this email, verification instructions have been sent.'
      );
      expect(testMailer.sentEmails).toHaveLength(1);
      expect(testMailer.sentEmails[0].to).toBe('raj04846@gmail.com');

      const dispatchedToken = testMailer.sentEmails[0].token;
      expect(dispatchedToken).toBeDefined();

      // Verify token hash was stored safely
      const expectedHash = crypto.createHash('sha256').update(dispatchedToken).digest('hex');
      expect(storedTokenHash).toBe(expectedHash);

      // Step 3: Verify the token via verifyEmail
      mockRepo.findByEmailVerificationToken.mockImplementation(async (hash) => {
        if (hash === storedTokenHash) {
          return { ...dbUser };
        }
        return null;
      });

      mockRepo.markEmailVerified.mockImplementation(async () => {
        dbUser.isEmailVerified = true;
        dbUser.emailVerificationTokenHash = null;
        dbUser.emailVerificationExpiresAt = null;
      });

      const verifyResult = await authService.verifyEmail(dispatchedToken);
      expect(verifyResult.message).toBe('Email verified successfully');
      expect(mockRepo.markEmailVerified).toHaveBeenCalledWith('user-legacy-01');

      // Step 4: Login succeeds after explicit verification
      const loginResult = await authService.login({
        email: 'raj04846@gmail.com',
        password: validPassword,
      });

      expect(loginResult.accessToken).toBeDefined();
      expect(loginResult.refreshToken).toBeDefined();
      expect(loginResult.user.id).toBe('user-legacy-01');
      expect(mockRepo.saveRefreshToken).toHaveBeenCalledTimes(1);
    });

    it('recovers legacy user securely via password reset flow and succeeds login with new password', async () => {
      const dbUser: any = {
        _id: 'user-legacy-pwreset',
        displayName: 'Vinod',
        email: 'raj04846@gmail.com',
        passwordHash: validPasswordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: undefined,
        tokenVersion: 1,
      };

      mockRepo.findByEmailWithSecrets.mockImplementation(async () => ({ ...dbUser }));

      // Step 1: Request password reset
      let resetTokenHash: string | null = null;
      mockRepo.setPasswordResetToken.mockImplementation(async (_id, hash) => {
        resetTokenHash = hash;
        dbUser.passwordResetTokenHash = hash;
        dbUser.passwordResetExpiresAt = new Date(Date.now() + 3600000);
      });

      const requestResult = await authService.requestPasswordReset('raj04846@gmail.com');
      expect(requestResult.message).toContain('password reset instructions have been sent');
      expect(testMailer.sentEmails).toHaveLength(1);

      const resetToken = testMailer.sentEmails[0].token;

      // Step 2: Confirm password reset
      mockRepo.findByPasswordResetToken.mockImplementation(async (hash) => {
        if (hash === resetTokenHash) {
          return { ...dbUser };
        }
        return null;
      });

      const newPassword = 'BrandNewPassword999!';
      mockRepo.resetPassword.mockImplementation(async (_id, newHash) => {
        dbUser.passwordHash = newHash;
        dbUser.isEmailVerified = true; // Proving email ownership via reset token verifies email
      });

      const resetResult = await authService.resetPassword(resetToken, newPassword);
      expect(resetResult.message).toContain('Password reset successful');

      // Step 3: Login with new password succeeds
      const loginResult = await authService.login({
        email: 'raj04846@gmail.com',
        password: newPassword,
      });

      expect(loginResult.accessToken).toBeDefined();
      expect(loginResult.user.id).toBe('user-legacy-pwreset');
    });

    it('allows retry registration to re-dispatch verification email for legacy users with missing verification field', async () => {
      mockRepo.emailExists.mockResolvedValue(true);
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-legacy-register',
        email: 'legacy-reg@example.com',
        displayName: 'Legacy Register',
        role: USER_ROLES.CONTRIBUTOR,
        isEmailVerified: undefined, // Missing
      } as any);

      const result = await authService.register({
        displayName: 'Legacy Register',
        email: 'legacy-reg@example.com',
        password: 'securePassword123',
      });

      expect(result.message).toBe('Registration successful. Please verify your email.');
      expect(testMailer.sentEmails).toHaveLength(1);
      expect(testMailer.sentEmails[0].to).toBe('legacy-reg@example.com');
      expect(mockRepo.setEmailVerificationToken).toHaveBeenCalledWith(
        'user-legacy-register',
        expect.any(String),
        expect.any(Date)
      );
    });
  });

  describe('4. Invalid credentials remaining rejected', () => {
    it('rejects verified user with invalid password', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-verified-01',
        displayName: 'Verified User',
        email: 'verified@example.com',
        passwordHash: validPasswordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: true,
      } as any);

      await expect(
        authService.login({
          email: 'verified@example.com',
          password: 'wrongPassword',
        })
      ).rejects.toThrow('Invalid email or password');

      expect(mockRepo.saveRefreshToken).not.toHaveBeenCalled();
    });

    it('rejects explicitly unverified user with invalid password', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-unverified-01',
        displayName: 'Unverified User',
        email: 'unverified@example.com',
        passwordHash: validPasswordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: false,
      } as any);

      await expect(
        authService.login({
          email: 'unverified@example.com',
          password: 'wrongPassword',
        })
      ).rejects.toThrow('Invalid email or password');

      expect(mockRepo.saveRefreshToken).not.toHaveBeenCalled();
    });

    it('rejects legacy user (missing verification field) with invalid password', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-legacy-01',
        displayName: 'Legacy User',
        email: 'legacy@example.com',
        passwordHash: validPasswordHash,
        role: USER_ROLES.CONTRIBUTOR,
        isActive: true,
        isEmailVerified: undefined,
      } as any);

      await expect(
        authService.login({
          email: 'legacy@example.com',
          password: 'wrongPassword',
        })
      ).rejects.toThrow('Invalid email or password');

      expect(mockRepo.saveRefreshToken).not.toHaveBeenCalled();
    });

    it('rejects non-existent email address with constant-time dummy work to prevent enumeration', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue(null);
      const compareSpy = jest.spyOn(bcrypt, 'compare');

      await expect(
        authService.login({
          email: 'nobody@example.com',
          password: 'randomPassword',
        })
      ).rejects.toThrow('Invalid email or password');

      expect(compareSpy).toHaveBeenCalledWith(
        'randomPassword',
        expect.stringMatching(/^\$2[abxy]?\$\d{2}\$/)
      );
      expect(mockRepo.saveRefreshToken).not.toHaveBeenCalled();
      compareSpy.mockRestore();
    });
  });

  describe('5. Resend verification endpoint security checks', () => {
    it('returns uniform response without sending email if account is already verified', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-already-verified',
        email: 'already@example.com',
        isEmailVerified: true,
        isActive: true,
      } as any);

      const result = await authService.resendVerificationEmail('already@example.com');

      expect(result.message).toBe(
        'If an unverified account exists with this email, verification instructions have been sent.'
      );
      expect(testMailer.sentEmails).toHaveLength(0);
      expect(mockRepo.setEmailVerificationToken).not.toHaveBeenCalled();
    });

    it('returns uniform response without sending email if account does not exist', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue(null);

      const result = await authService.resendVerificationEmail('doesnotexist@example.com');

      expect(result.message).toBe(
        'If an unverified account exists with this email, verification instructions have been sent.'
      );
      expect(testMailer.sentEmails).toHaveLength(0);
      expect(mockRepo.setEmailVerificationToken).not.toHaveBeenCalled();
    });

    it('returns uniform response without sending email if account is disabled', async () => {
      mockRepo.findByEmailWithSecrets.mockResolvedValue({
        _id: 'user-disabled',
        email: 'disabled@example.com',
        isEmailVerified: false,
        isActive: false,
      } as any);

      const result = await authService.resendVerificationEmail('disabled@example.com');

      expect(result.message).toBe(
        'If an unverified account exists with this email, verification instructions have been sent.'
      );
      expect(testMailer.sentEmails).toHaveLength(0);
      expect(mockRepo.setEmailVerificationToken).not.toHaveBeenCalled();
    });
  });
});
