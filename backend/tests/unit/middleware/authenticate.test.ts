import crypto from 'crypto';
import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { authenticate } from '../../../src/middleware/authenticate';
import { env } from '../../../src/config/env';
import { AuthenticationError, AppError } from '../../../src/shared/errors/AppError';
import { AuthenticatedRequest } from '../../../src/shared/types';
import { USER_ROLES } from '../../../src/shared/constants';
import { UserModel } from '../../../src/modules/auth/user.model';
import { TEST_RSA_PRIVATE_KEY, TEST_RSA_PUBLIC_KEY } from '../../fixtures/testKeys';

// Generate a distinct, valid RSA key pair to simulate an attacker/foreign issuer
const foreignKeyPair = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  publicKeyEncoding: { type: 'spki', format: 'pem' },
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
});

describe('Authenticate Middleware (Unit Tests)', () => {
  let mockReq: Partial<AuthenticatedRequest>;
  let mockRes: Partial<Response>;
  let nextFn: NextFunction;

  beforeEach(() => {
    mockReq = {
      headers: {},
    };
    mockRes = {};
    nextFn = jest.fn();
  });

  describe('1. Missing and Malformed Authorization Headers', () => {
    it('calls next with AuthenticationError("No token provided") if Authorization header is missing', () => {
      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('No token provided');
    });

    it('calls next with AuthenticationError("No token provided") if Authorization header does not start with Bearer', () => {
      mockReq.headers = { authorization: 'Basic dXNlcjpwYXNz' };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('No token provided');
    });

    it('calls next with AuthenticationError("No token provided") if Bearer token is empty whitespace', () => {
      mockReq.headers = { authorization: 'Bearer    ' };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('No token provided');
    });

    it('calls next with AuthenticationError("Invalid or expired token") if token is malformed', () => {
      mockReq.headers = { authorization: 'Bearer not.a.valid.jwt' };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });
  });

  describe('2. Valid RS256 Verification & Claim Normalization', () => {
    it('verifies valid RS256 token and attaches req.user with exact claims', async () => {
      const token = jwt.sign(
        {
          userId: '507f1f77bcf86cd799439011',
          email: 'test@example.com',
          role: USER_ROLES.CONTRIBUTOR,
          displayName: 'Test Contributor',
          tokenVersion: 1,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith();
      expect(mockReq.user).toEqual({
        userId: '507f1f77bcf86cd799439011',
        email: 'test@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        displayName: 'Test Contributor',
        tokenVersion: 1,
      });
    });

    it('normalizes legacy lowercase role (e.g. "admin" -> "ADMIN")', async () => {
      const token = jwt.sign(
        {
          userId: '507f1f77bcf86cd799439012',
          email: 'admin@example.com',
          role: 'admin',
          displayName: 'Admin User',
          tokenVersion: 1,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith();
      expect(mockReq.user?.role).toBe(USER_ROLES.ADMIN);
      expect(mockReq.user?.tokenVersion).toBe(1);
    });

    it('falls back to sub claim when userId is omitted', async () => {
      const token = jwt.sign(
        {
          sub: '507f1f77bcf86cd799439013',
          role: USER_ROLES.REVIEWER,
          tokenVersion: 1,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith();
      expect(mockReq.user?.userId).toBe('507f1f77bcf86cd799439013');
      expect(mockReq.user?.role).toBe(USER_ROLES.REVIEWER);
      expect(mockReq.user?.email).toBe('');
      expect(mockReq.user?.displayName).toBe('');
      expect(mockReq.user?.tokenVersion).toBe(1);
    });
  });

  describe('3. RS256 Cryptographic and Claim Rejections', () => {
    it('rejects RS256 token signed with wrong/unmatching private key', () => {
      const token = jwt.sign(
        {
          userId: 'user-123',
          role: USER_ROLES.CONTRIBUTOR,
        },
        foreignKeyPair.privateKey,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('rejects RS256 token with wrong issuer', () => {
      const token = jwt.sign(
        {
          userId: 'user-123',
          role: USER_ROLES.CONTRIBUTOR,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'wrong-issuer',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('rejects RS256 token with wrong audience', () => {
      const token = jwt.sign(
        {
          userId: 'user-123',
          role: USER_ROLES.CONTRIBUTOR,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'wrong-audience',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('rejects expired RS256 token', () => {
      const token = jwt.sign(
        {
          userId: 'user-123',
          role: USER_ROLES.CONTRIBUTOR,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '-10s',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('rejects token with missing userId and sub', () => {
      const token = jwt.sign(
        {
          role: USER_ROLES.CONTRIBUTOR,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('rejects token with empty string userId', () => {
      const token = jwt.sign(
        {
          userId: '   ',
          role: USER_ROLES.CONTRIBUTOR,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('rejects token with unrecognized role', () => {
      const token = jwt.sign(
        {
          userId: 'u1',
          role: 'SUPERUSER',
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });
  });

  describe('4. Unsupported Algorithms & Algorithm Confusion', () => {
    it('rejects token with "none" algorithm', () => {
      const unsignedToken = jwt.sign(
        {
          userId: 'u1',
          role: USER_ROLES.ADMIN,
        },
        '',
        {
          algorithm: 'none' as any,
        }
      );
      mockReq.headers = { authorization: `Bearer ${unsignedToken}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('rejects unsupported asymmetric algorithm (e.g. ES256)', () => {
      const ecKey = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
      const es256Token = jwt.sign(
        {
          userId: 'u1',
          role: USER_ROLES.ADMIN,
        },
        ecKey.privateKey,
        {
          algorithm: 'ES256',
        }
      );
      mockReq.headers = { authorization: `Bearer ${es256Token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('rejects algorithm confusion attack (HS256 signed with public key as secret)', () => {
      const confusionToken = jwt.sign(
        {
          userId: 'attacker',
          role: USER_ROLES.ADMIN,
        },
        TEST_RSA_PUBLIC_KEY,
        {
          algorithm: 'HS256',
        }
      );
      mockReq.headers = { authorization: `Bearer ${confusionToken}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });
  });

  describe('5. HS256 Legacy Fallback Behavior', () => {
    const validHs256Token = jwt.sign(
      {
        userId: '507f1f77bcf86cd799439014',
        email: 'legacy@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        displayName: 'Legacy User',
        tokenVersion: 1,
      },
      env.JWT_ACCESS_SECRET,
      {
        algorithm: 'HS256',
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
        expiresIn: '15m',
      }
    );

    it('rejects valid HS256 token when JWT_ALLOW_HS256_FALLBACK is false (default)', () => {
      mockReq.headers = { authorization: `Bearer ${validHs256Token}` };

      authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      const error = (nextFn as jest.Mock).mock.calls[0][0];
      expect(error.message).toBe('Invalid or expired token');
    });

    it('strictly rejects HS256 token in production even if fallback flag is enabled', () => {
      const prevEnv = env.NODE_ENV;
      const prevFallback = process.env.JWT_ALLOW_HS256_FALLBACK;
      (env as any).NODE_ENV = 'production';
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
      try {
        mockReq.headers = { authorization: `Bearer ${validHs256Token}` };

        authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        const error = (nextFn as jest.Mock).mock.calls[0][0];
        expect(error.message).toBe('Invalid or expired token');
      } finally {
        (env as any).NODE_ENV = prevEnv;
        if (prevFallback === undefined) {
          delete process.env.JWT_ALLOW_HS256_FALLBACK;
        } else {
          process.env.JWT_ALLOW_HS256_FALLBACK = prevFallback;
        }
      }
    });

    it('accepts valid HS256 token when JWT_ALLOW_HS256_FALLBACK is true', async () => {
      const prev = process.env.JWT_ALLOW_HS256_FALLBACK;
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
      try {
        mockReq.headers = { authorization: `Bearer ${validHs256Token}` };

        await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith();
        expect(mockReq.user).toEqual({
          userId: '507f1f77bcf86cd799439014',
          email: 'legacy@example.com',
          role: USER_ROLES.CONTRIBUTOR,
          displayName: 'Legacy User',
          tokenVersion: 1,
        });
      } finally {
        if (prev === undefined) {
          delete process.env.JWT_ALLOW_HS256_FALLBACK;
        } else {
          process.env.JWT_ALLOW_HS256_FALLBACK = prev;
        }
      }
    });

    it('never retries a failed RS256 token against HS256 fallback even when fallback is true', () => {
      const prev = process.env.JWT_ALLOW_HS256_FALLBACK;
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
      try {
        // RS256 token with invalid signature
        const invalidRs256Token = jwt.sign(
          {
            userId: 'user-tampered',
            role: USER_ROLES.ADMIN,
          },
          foreignKeyPair.privateKey,
          {
            algorithm: 'RS256',
            issuer: 'myroot-backend',
            audience: 'myroot-platform',
            expiresIn: '15m',
          }
        );
        mockReq.headers = { authorization: `Bearer ${invalidRs256Token}` };

        authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        const error = (nextFn as jest.Mock).mock.calls[0][0];
        expect(error.message).toBe('Invalid or expired token');
      } finally {
        if (prev === undefined) {
          delete process.env.JWT_ALLOW_HS256_FALLBACK;
        } else {
          process.env.JWT_ALLOW_HS256_FALLBACK = prev;
        }
      }
    });

    it('rejects HS256 token when issuer claim is missing even if fallback is true', () => {
      const prev = process.env.JWT_ALLOW_HS256_FALLBACK;
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
      try {
        const noIssuerToken = jwt.sign(
          {
            userId: '507f1f77bcf86cd799439014',
            email: 'legacy@example.com',
            role: USER_ROLES.CONTRIBUTOR,
            displayName: 'Legacy User',
            tokenVersion: 1,
            // aud provided, iss missing
            aud: env.JWT_AUDIENCE,
          },
          env.JWT_ACCESS_SECRET,
          { algorithm: 'HS256', expiresIn: '15m' }
        );
        mockReq.headers = { authorization: `Bearer ${noIssuerToken}` };

        authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        const error = (nextFn as jest.Mock).mock.calls[0][0];
        expect(error.message).toBe('Invalid or expired token');
      } finally {
        if (prev === undefined) {
          delete process.env.JWT_ALLOW_HS256_FALLBACK;
        } else {
          process.env.JWT_ALLOW_HS256_FALLBACK = prev;
        }
      }
    });

    it('rejects HS256 token when audience claim is missing even if fallback is true', () => {
      const prev = process.env.JWT_ALLOW_HS256_FALLBACK;
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
      try {
        const noAudienceToken = jwt.sign(
          {
            userId: '507f1f77bcf86cd799439014',
            email: 'legacy@example.com',
            role: USER_ROLES.CONTRIBUTOR,
            displayName: 'Legacy User',
            tokenVersion: 1,
            // iss provided, aud missing
            iss: env.JWT_ISSUER,
          },
          env.JWT_ACCESS_SECRET,
          { algorithm: 'HS256', expiresIn: '15m' }
        );
        mockReq.headers = { authorization: `Bearer ${noAudienceToken}` };

        authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        const error = (nextFn as jest.Mock).mock.calls[0][0];
        expect(error.message).toBe('Invalid or expired token');
      } finally {
        if (prev === undefined) {
          delete process.env.JWT_ALLOW_HS256_FALLBACK;
        } else {
          process.env.JWT_ALLOW_HS256_FALLBACK = prev;
        }
      }
    });

    it('rejects HS256 token with mismatched issuer claim', () => {
      const prev = process.env.JWT_ALLOW_HS256_FALLBACK;
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
      try {
        const wrongIssuerToken = jwt.sign(
          {
            userId: '507f1f77bcf86cd799439014',
            email: 'legacy@example.com',
            role: USER_ROLES.CONTRIBUTOR,
            displayName: 'Legacy User',
            tokenVersion: 1,
          },
          env.JWT_ACCESS_SECRET,
          {
            algorithm: 'HS256',
            issuer: 'foreign-issuer',
            audience: env.JWT_AUDIENCE,
            expiresIn: '15m',
          }
        );
        mockReq.headers = { authorization: `Bearer ${wrongIssuerToken}` };

        authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        const error = (nextFn as jest.Mock).mock.calls[0][0];
        expect(error.message).toBe('Invalid or expired token');
      } finally {
        if (prev === undefined) {
          delete process.env.JWT_ALLOW_HS256_FALLBACK;
        } else {
          process.env.JWT_ALLOW_HS256_FALLBACK = prev;
        }
      }
    });

    it('rejects HS256 token with mismatched audience claim', () => {
      const prev = process.env.JWT_ALLOW_HS256_FALLBACK;
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
      try {
        const wrongAudienceToken = jwt.sign(
          {
            userId: '507f1f77bcf86cd799439014',
            email: 'legacy@example.com',
            role: USER_ROLES.CONTRIBUTOR,
            displayName: 'Legacy User',
            tokenVersion: 1,
          },
          env.JWT_ACCESS_SECRET,
          {
            algorithm: 'HS256',
            issuer: env.JWT_ISSUER,
            audience: 'foreign-audience',
            expiresIn: '15m',
          }
        );
        mockReq.headers = { authorization: `Bearer ${wrongAudienceToken}` };

        authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        const error = (nextFn as jest.Mock).mock.calls[0][0];
        expect(error.message).toBe('Invalid or expired token');
      } finally {
        if (prev === undefined) {
          delete process.env.JWT_ALLOW_HS256_FALLBACK;
        } else {
          process.env.JWT_ALLOW_HS256_FALLBACK = prev;
        }
      }
    });

    it('rejects token using unsupported HMAC algorithm (e.g. HS384) in fallback path', () => {
      const prev = process.env.JWT_ALLOW_HS256_FALLBACK;
      process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
      try {
        const hs384Token = jwt.sign(
          {
            userId: '507f1f77bcf86cd799439014',
            email: 'legacy@example.com',
            role: USER_ROLES.CONTRIBUTOR,
            displayName: 'Legacy User',
            tokenVersion: 1,
          },
          env.JWT_ACCESS_SECRET,
          {
            algorithm: 'HS384',
            issuer: env.JWT_ISSUER,
            audience: env.JWT_AUDIENCE,
            expiresIn: '15m',
          }
        );
        mockReq.headers = { authorization: `Bearer ${hs384Token}` };

        authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        const error = (nextFn as jest.Mock).mock.calls[0][0];
        expect(error.message).toBe('Invalid or expired token');
      } finally {
        if (prev === undefined) {
          delete process.env.JWT_ALLOW_HS256_FALLBACK;
        } else {
          process.env.JWT_ALLOW_HS256_FALLBACK = prev;
        }
      }
    });
  });

  describe('6. TokenVersion Validation & Fail-Closed Authoritative Verification', () => {
    const validObjectId = '507f1f77bcf86cd799439011';

    function createTokenWithClaims(claims: Record<string, any>): string {
      return jwt.sign(
        {
          userId: validObjectId,
          email: 'test@example.com',
          role: USER_ROLES.CONTRIBUTOR,
          displayName: 'Test User',
          ...claims,
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
    }

    it('rejects access token missing tokenVersion claim', async () => {
      const token = jwt.sign(
        {
          userId: validObjectId,
          email: 'test@example.com',
          role: USER_ROLES.CONTRIBUTOR,
          displayName: 'Test User',
        },
        TEST_RSA_PRIVATE_KEY,
        {
          algorithm: 'RS256',
          issuer: 'myroot-backend',
          audience: 'myroot-platform',
          expiresIn: '15m',
        }
      );
      mockReq.headers = { authorization: `Bearer ${token}` };

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('Invalid or expired token');
    });

    it('rejects access token with string tokenVersion', async () => {
      const token = createTokenWithClaims({ tokenVersion: '1' });
      mockReq.headers = { authorization: `Bearer ${token}` };

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('Invalid or expired token');
    });

    it('rejects access token with fractional tokenVersion', async () => {
      const token = createTokenWithClaims({ tokenVersion: 1.5 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('Invalid or expired token');
    });

    it('rejects access token with negative tokenVersion', async () => {
      const token = createTokenWithClaims({ tokenVersion: -1 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('Invalid or expired token');
    });

    it('rejects access token with NaN tokenVersion', async () => {
      const token = createTokenWithClaims({ tokenVersion: NaN });
      mockReq.headers = { authorization: `Bearer ${token}` };

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
      expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('Invalid or expired token');
    });

    it('accepts access token with valid non-negative integer tokenVersion: 0', async () => {
      const token = createTokenWithClaims({ tokenVersion: 0 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      jest.spyOn(UserModel, 'findById').mockReturnValueOnce({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId(validObjectId),
          isActive: true,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 0,
        }),
      } as any);

      await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

      expect(nextFn).toHaveBeenCalledWith();
      expect(mockReq.user?.tokenVersion).toBe(0);
    });

    it('fails closed when database verification is required but MongoDB is disconnected', async () => {
      const token = createTokenWithClaims({ tokenVersion: 1 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      (mongoose.connection as any).readyState = 0;

      try {
        await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AppError));
        expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('Authentication service unavailable');
      } finally {
        (mongoose.connection as any).readyState = 1;
      }
    });

    it('fails closed when database verification is required but userId is not a valid ObjectId', async () => {
      const token = createTokenWithClaims({ userId: 'invalid-string-id', tokenVersion: 1 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      process.env.VERIFY_USER_DB = 'true';

      try {
        await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('Invalid or expired token');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('fails closed when database query rejects with an error and never calls next() successfully', async () => {
      const token = createTokenWithClaims({ tokenVersion: 1 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockRejectedValue(new Error('MongoNetworkTimeoutException: connection lost')),
      } as any);

      try {
        await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledTimes(1);
        expect(nextFn).toHaveBeenCalledWith(expect.any(AppError));
        const passedError = (nextFn as jest.Mock).mock.calls[0][0];
        expect(passedError.message).toBe('Authentication service unavailable');
        // Critical safety assertion: must not call next() without error
        expect(mockReq.user).toBeUndefined();
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('rejects with 401 User account not found when user does not exist in DB', async () => {
      const token = createTokenWithClaims({ tokenVersion: 1 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      try {
        await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('User account not found');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('rejects with 401 User account is disabled when isActive is false', async () => {
      const token = createTokenWithClaims({ tokenVersion: 1 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId(validObjectId),
          isActive: false,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 1,
        }),
      } as any);

      try {
        await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('User account is disabled');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('rejects with 401 Token has been revoked when tokenVersion does not match authoritative DB version', async () => {
      const token = createTokenWithClaims({ tokenVersion: 1 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId(validObjectId),
          isActive: true,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 2,
        }),
      } as any);

      try {
        await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith(expect.any(AuthenticationError));
        expect((nextFn as jest.Mock).mock.calls[0][0].message).toBe('Token has been revoked');
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });

    it('synchronizes req.user.role with authoritative database role when token role is ADMIN and database role is CONTRIBUTOR', async () => {
      const token = createTokenWithClaims({ role: USER_ROLES.ADMIN, tokenVersion: 1 });
      mockReq.headers = { authorization: `Bearer ${token}` };

      process.env.VERIFY_USER_DB = 'true';
      jest.spyOn(UserModel, 'findById').mockReturnValue({
        select: jest.fn().mockReturnThis(),
        lean: jest.fn().mockReturnThis(),
        exec: jest.fn().mockResolvedValue({
          _id: new mongoose.Types.ObjectId(validObjectId),
          isActive: true,
          role: USER_ROLES.CONTRIBUTOR,
          tokenVersion: 1,
        }),
      } as any);

      try {
        await authenticate(mockReq as AuthenticatedRequest, mockRes as Response, nextFn);

        expect(nextFn).toHaveBeenCalledWith();
        expect((mockReq as AuthenticatedRequest).user?.role).toBe(USER_ROLES.CONTRIBUTOR);
        expect((mockReq as AuthenticatedRequest).user?.tokenVersion).toBe(1);
      } finally {
        delete process.env.VERIFY_USER_DB;
      }
    });
  });
});

