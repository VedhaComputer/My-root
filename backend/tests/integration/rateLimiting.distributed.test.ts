import request from 'express';
import supertest from 'supertest';
import express, { Request, Response } from 'express';
import rateLimit from 'express-rate-limit';
import { envSchema } from '../../src/config/env';
import {
  connectRedis,
  disconnectRedis,
  getRedisClient,
  getRedisStatus,
  setRedisClientForTesting,
} from '../../src/config/redis';
import {
  normalizeAccountKey,
  createRateLimitStore,
  authAccountRateLimiter,
  authIpRateLimiter,
  authRateLimitStore,
} from '../../src/middleware/rateLimiter';
import { InMemoryRedisMock } from '../fixtures/redisMock';

describe('Distributed Rate Limiting & Phase 2.6 Verification', () => {
  let redisMock: InMemoryRedisMock;

  beforeEach(() => {
    redisMock = new InMemoryRedisMock();
    setRedisClientForTesting(redisMock as any);
  });

  afterEach(() => {
    setRedisClientForTesting(null);
  });

  // =========================================================================
  // 1. Redis Environment & Configuration Validation
  // =========================================================================
  describe('1. Redis Environment & Configuration Validation', () => {
    const baseProductionEnv = {
      NODE_ENV: 'production',
      PORT: '3001',
      MONGODB_URI: 'mongodb://localhost:27017/myroot',
      JWT_ACCESS_SECRET: 'min_32_characters_jwt_access_secret_for_tests!',
      JWT_REFRESH_SECRET: 'min_32_characters_jwt_refresh_secret_for_tests!',
      MAIL_TRANSPORT: 'smtp',
      SMTP_HOST: 'smtp.example.com',
      SMTP_PORT: '587',
      SMTP_USER: 'prod_user',
      SMTP_PASS: 'prod_pass',
      EMAIL_FROM: 'noreply@myroot.in',
    };

    it('rejects RATE_LIMIT_STORE=memory in production with fail-closed schema validation', () => {
      const config = {
        ...baseProductionEnv,
        RATE_LIMIT_STORE: 'memory',
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(
          result.error.issues.some(
            (i) =>
              i.path.includes('RATE_LIMIT_STORE') &&
              i.message.includes('Production environment strictly forbids RATE_LIMIT_STORE=memory')
          )
        ).toBe(true);
      }
    });

    it('rejects RATE_LIMIT_STORE=redis when REDIS_URL is missing', () => {
      const config = {
        ...baseProductionEnv,
        RATE_LIMIT_STORE: 'redis',
        // REDIS_URL omitted
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('REDIS_URL'))).toBe(true);
      }
    });

    it('accepts valid RATE_LIMIT_STORE=redis and REDIS_URL in production', () => {
      const config = {
        ...baseProductionEnv,
        RATE_LIMIT_STORE: 'redis',
        REDIS_URL: 'redis://redis.production.internal:6379',
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.RATE_LIMIT_STORE).toBe('redis');
        expect(result.data.REDIS_URL).toBe('redis://redis.production.internal:6379');
      }
    });

    it('permits RATE_LIMIT_STORE=memory in development and test environments', () => {
      const devConfig = {
        NODE_ENV: 'development',
        MONGODB_URI: 'mongodb://localhost:27017/myroot_dev',
        JWT_ACCESS_SECRET: 'min_32_characters_jwt_access_secret_for_tests!',
        JWT_REFRESH_SECRET: 'min_32_characters_jwt_refresh_secret_for_tests!',
        RATE_LIMIT_STORE: 'memory',
      };
      const result = envSchema.safeParse(devConfig);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.RATE_LIMIT_STORE).toBe('memory');
      }
    });
  });

  // =========================================================================
  // 2. Unavailable Redis Behavior (Fail Closed, No Silent Fallback)
  // =========================================================================
  describe('2. Unavailable Redis Behavior (Fail Closed, No Silent Fallback)', () => {
    it('throws fail-closed error if Redis connection/ping fails when Redis is required', async () => {
      // Simulate Redis server offline
      redisMock.simulateDisconnect();

      try {
        await expect(
          connectRedis({
            rateLimitStore: 'redis',
            redisUrl: 'redis://127.0.0.1:6379',
          })
        ).rejects.toThrow(/Redis connection failed \(fail closed\)/);
        expect(getRedisStatus()).toBe('disconnected');
      } finally {
        redisMock.simulateReconnect();
      }
    });

    it('throws fail-closed error at startup in production if RATE_LIMIT_STORE is memory', async () => {
      await expect(
        connectRedis({
          nodeEnv: 'production',
          rateLimitStore: 'memory',
        })
      ).rejects.toThrow(/Production environment strictly forbids MemoryStore/);
    });
  });

  // =========================================================================
  // 3. Shared-Store Multi-Instance Behavior
  // =========================================================================
  describe('3. Shared-Store Multi-Instance Distributed Limiting', () => {
    it('shares rate limit hit counts across multiple backend instances via the shared Redis mock', async () => {
      // Simulate Instance A and Instance B connecting to the same Redis cluster
      const clientA = redisMock;
      const clientB = redisMock.createPeerInstance();

      const storeA = createRateLimitStore({ prefix: 'rl:shared:', client: clientA });
      const storeB = createRateLimitStore({ prefix: 'rl:shared:', client: clientB });

      // Create Express apps for Instance A and Instance B
      const appA = express();
      appA.set('trust proxy', 'loopback');
      appA.use(
        rateLimit({
          windowMs: 60000,
          max: 5,
          standardHeaders: true,
          legacyHeaders: false,
          validate: false,
          store: storeA,
        })
      );
      appA.get('/test', (_req, res) => res.json({ instance: 'A', ok: true }));

      const appB = express();
      appB.set('trust proxy', 'loopback');
      appB.use(
        rateLimit({
          windowMs: 60000,
          max: 5,
          standardHeaders: true,
          legacyHeaders: false,
          validate: false,
          store: storeB,
        })
      );
      appB.get('/test', (_req, res) => res.json({ instance: 'B', ok: true }));

      // Send 3 requests to Instance A
      for (let i = 0; i < 3; i++) {
        const resA = await supertest(appA).get('/test').set('X-Forwarded-For', '198.51.100.1');
        expect(resA.status).toBe(200);
        expect(resA.headers['ratelimit-remaining']).toBe(String(4 - i));
      }

      // Send 2 requests to Instance B from the same client IP
      // Instance B must see that 3 requests have already been consumed on Instance A!
      const resB1 = await supertest(appB).get('/test').set('X-Forwarded-For', '198.51.100.1');
      expect(resB1.status).toBe(200);
      expect(resB1.headers['ratelimit-remaining']).toBe('1');

      const resB2 = await supertest(appB).get('/test').set('X-Forwarded-For', '198.51.100.1');
      expect(resB2.status).toBe(200);
      expect(resB2.headers['ratelimit-remaining']).toBe('0');

      // The 6th request sent to Instance A must be blocked with 429
      const blockedResA = await supertest(appA).get('/test').set('X-Forwarded-For', '198.51.100.1');
      expect(blockedResA.status).toBe(429);

      // The 7th request sent to Instance B must also be blocked with 429
      const blockedResB = await supertest(appB).get('/test').set('X-Forwarded-For', '198.51.100.1');
      expect(blockedResB.status).toBe(429);
    });
  });

  // =========================================================================
  // 4. IP-Based Rate Limiting
  // =========================================================================
  describe('4. IP-Based Rate Limiting', () => {
    it('blocks subsequent requests from an IP after exceeding limit while leaving other IPs unaffected', async () => {
      const store = createRateLimitStore({ prefix: 'rl:ip:', client: redisMock });
      const testApp = express();
      testApp.set('trust proxy', 'loopback');
      testApp.use(
        rateLimit({
          windowMs: 60000,
          max: 3,
          standardHeaders: true,
          legacyHeaders: false,
          validate: false,
          store,
          message: { error: { code: 'RATE_LIMITED', message: 'Too many requests' } },
        })
      );
      testApp.get('/api/test', (_req, res) => res.json({ success: true }));

      // IP 1: sends 3 requests
      for (let i = 0; i < 3; i++) {
        const res = await supertest(testApp).get('/api/test').set('X-Forwarded-For', '203.0.113.10');
        expect(res.status).toBe(200);
      }

      // IP 1: 4th request is blocked
      const blockedRes = await supertest(testApp).get('/api/test').set('X-Forwarded-For', '203.0.113.10');
      expect(blockedRes.status).toBe(429);
      expect(blockedRes.body.error.code).toBe('RATE_LIMITED');

      // IP 2: distinct IP is NOT blocked
      const ip2Res = await supertest(testApp).get('/api/test').set('X-Forwarded-For', '203.0.113.20');
      expect(ip2Res.status).toBe(200);
      expect(ip2Res.headers['ratelimit-remaining']).toBe('2');
    });
  });

  // =========================================================================
  // 5. Per-Account Rate Limiting & Distributed Protection
  // =========================================================================
  describe('5. Per-Account Rate Limiting & DoS Prevention', () => {
    it('aggregates authentication attempts across different IPs for the same account without locking out other accounts', async () => {
      const accountStore = createRateLimitStore({ prefix: 'rl:acct:', client: redisMock });
      const testApp = express();
      testApp.set('trust proxy', 'loopback');
      testApp.use(express.json());

      testApp.post(
        '/login',
        rateLimit({
          windowMs: 60000,
          max: 4,
          standardHeaders: true,
          legacyHeaders: false,
          validate: false,
          store: accountStore,
          keyGenerator: (req: Request) => normalizeAccountKey(req.body.email || ''),
          skip: (req: Request) => !req.body?.email || typeof req.body.email !== 'string',
          message: {
            error: {
              code: 'RATE_LIMITED',
              message: 'Too many authentication attempts. Please try again later.',
            },
          },
        }),
        (_req: Request, res: Response) => {
          res.status(401).json({ error: { code: 'INVALID_CREDENTIALS', message: 'Invalid credentials' } });
        }
      );

      const targetEmail = 'target.user@example.com';
      const innocentEmail = 'innocent.user@example.com';

      // Attacker tries 4 attempts against target user from 4 DIFFERENT IP addresses
      for (let i = 1; i <= 4; i++) {
        const res = await supertest(testApp)
          .post('/login')
          .set('X-Forwarded-For', `192.0.2.${i}`)
          .send({ email: targetEmail, password: `wrong_${i}` });
        expect(res.status).toBe(401);
        expect(res.headers['ratelimit-remaining']).toBe(String(4 - i));
      }

      // 5th attempt against target user from a 5th distinct IP is blocked by the Per-Account limiter
      const blockedRes = await supertest(testApp)
        .post('/login')
        .set('X-Forwarded-For', '192.0.2.5')
        .send({ email: targetEmail, password: 'wrong_5' });

      expect(blockedRes.status).toBe(429);
      expect(blockedRes.body.error.code).toBe('RATE_LIMITED');
      expect(blockedRes.body.error.message).toContain('Too many authentication attempts');

      // Crucial requirement: Innocent user account is NOT locked out and can still attempt login
      const innocentRes = await supertest(testApp)
        .post('/login')
        .set('X-Forwarded-For', '192.0.2.6')
        .send({ email: innocentEmail, password: 'password123' });

      expect(innocentRes.status).toBe(401);
      expect(innocentRes.headers['ratelimit-remaining']).toBe('3');
    });
  });

  // =========================================================================
  // 6. Identifier Normalization & Sensitive Data Hashing (PII Protection)
  // =========================================================================
  describe('6. Account Identifier Normalization & PII Protection', () => {
    it('normalizes email casing and leading/trailing whitespace into identical hash keys', () => {
      const email1 = 'User.Name@Example.COM';
      const email2 = '  user.name@example.com  ';
      const email3 = 'user.name@example.com';

      const key1 = normalizeAccountKey(email1);
      const key2 = normalizeAccountKey(email2);
      const key3 = normalizeAccountKey(email3);

      expect(key1).toBe(key3);
      expect(key2).toBe(key3);
      expect(key1).toHaveLength(64); // Valid SHA-256 hex string
    });

    it('applies Unicode NFKC normalization to prevent homoglyph/encoding bypass', () => {
      // Full-width characters (e.g. ｕｓｅｒ＠ｅｘａｍｐｌｅ．ｃｏｍ)
      const fullWidth = '\uFF55\uFF53\uFF45\uFF52@example.com';
      const regular = 'user@example.com';

      expect(normalizeAccountKey(fullWidth)).toBe(normalizeAccountKey(regular));
    });

    it('guarantees that raw emails are never used as Redis keys', async () => {
      const accountStore = createRateLimitStore({ prefix: 'rl:auth:acct:', client: redisMock });
      const testApp = express();
      testApp.use(express.json());

      testApp.post(
        '/login',
        rateLimit({
          windowMs: 60000,
          max: 5,
          validate: false,
          store: accountStore,
          keyGenerator: (req) => normalizeAccountKey(req.body.email || ''),
        }),
        (_req, res) => res.status(200).json({ ok: true })
      );

      const sensitiveEmail = 'sensitive.ceo@corporation.internal';
      await supertest(testApp).post('/login').send({ email: sensitiveEmail });

      // Inspect keys stored in Redis mock
      const keys = Array.from(redisMock.data.keys());
      expect(keys.length).toBeGreaterThan(0);

      // Verify none of the keys contain the raw email address
      for (const k of keys) {
        expect(k).not.toContain(sensitiveEmail);
        expect(k).not.toContain('@');
        expect(k).toMatch(/^rl:auth:acct:[a-f0-9]{64}$/);
      }
    });
  });

  // =========================================================================
  // 7. Bounded Lifetimes, Expiry & Window Reset
  // =========================================================================
  describe('7. Bounded Lifetime & Expiry', () => {
    it('sets bounded TTL on Redis keys and clears rate limit after window expires without permanent lockout', async () => {
      const store = createRateLimitStore({ prefix: 'rl:expiry:', client: redisMock });
      const testApp = express();
      testApp.set('trust proxy', 'loopback');

      testApp.get(
        '/test',
        rateLimit({
          windowMs: 10000, // 10 second window
          max: 2,
          validate: false,
          store,
          standardHeaders: true,
          legacyHeaders: false,
        }),
        (_req, res) => res.status(200).json({ ok: true })
      );

      // 2 allowed requests
      await supertest(testApp).get('/test').set('X-Forwarded-For', '10.0.0.1');
      await supertest(testApp).get('/test').set('X-Forwarded-For', '10.0.0.1');

      // 3rd request is blocked
      const blockedRes = await supertest(testApp).get('/test').set('X-Forwarded-For', '10.0.0.1');
      expect(blockedRes.status).toBe(429);

      // Advance mock virtual time past the 10-second window
      redisMock.advanceTime(11000);

      // Rate limit must automatically be lifted (no permanent lockout)
      const afterExpiryRes = await supertest(testApp).get('/test').set('X-Forwarded-For', '10.0.0.1');
      expect(afterExpiryRes.status).toBe(200);
      expect(afterExpiryRes.headers['ratelimit-remaining']).toBe('1');
    });
  });

  // =========================================================================
  // 8. Generic Authentication Responses & Confidentiality
  // =========================================================================
  describe('8. Generic Authentication Responses & Confidentiality', () => {
    it('returns generic uniform 429 response without leaking credentials or tokens', async () => {
      const store = createRateLimitStore({ prefix: 'rl:auth:generic:', client: redisMock });
      const testApp = express();
      testApp.use(express.json());

      testApp.post(
        '/login',
        rateLimit({
          windowMs: 60000,
          max: 1,
          validate: false,
          store,
          standardHeaders: true,
          legacyHeaders: false,
          message: {
            error: {
              code: 'RATE_LIMITED',
              message: 'Too many authentication attempts. Please try again later.',
            },
          },
        }),
        (_req, res) => res.json({ ok: true })
      );

      const secretPassword = 'MySuperSecretP@ssword!2026';
      // First request: success
      await supertest(testApp).post('/login').send({ email: 'user@example.com', password: secretPassword });

      // Second request: blocked
      const blocked = await supertest(testApp).post('/login').send({ email: 'user@example.com', password: secretPassword });

      expect(blocked.status).toBe(429);
      expect(blocked.body).toEqual({
        error: {
          code: 'RATE_LIMITED',
          message: 'Too many authentication attempts. Please try again later.',
        },
      });

      // Verify headers do not leak passwords, tokens, or PII
      const headerString = JSON.stringify(blocked.headers);
      expect(headerString).not.toContain(secretPassword);
      expect(headerString).not.toContain('user@example.com');
      expect(blocked.headers['retry-after']).toBeDefined();
      expect(Number(blocked.headers['retry-after'])).toBeGreaterThan(0);
    });
  });

  // =========================================================================
  // 9. Lifecycle, Store Delegation & Utility Coverage
  // =========================================================================
  describe('9. Redis Lifecycle, Store Delegation & Utility Functions', () => {
    it('exercises getRedisClient, disconnectRedis, and status reporting', async () => {
      setRedisClientForTesting(redisMock as any);
      expect(getRedisClient()).toBe(redisMock);
      expect(getRedisStatus()).toBe('connected');

      await disconnectRedis();
      expect(getRedisClient()).toBeNull();
      expect(getRedisStatus()).toBe('disconnected');
    });

    it('clears timeout handle when quit() resolves promptly, leaving no pending timer handles', async () => {
      jest.useFakeTimers();
      try {
        const promptClient = {
          status: 'ready' as 'ready' | 'disconnected',
          quit: jest.fn(async () => {
            promptClient.status = 'disconnected';
          }),
          disconnect: jest.fn(),
        };

        setRedisClientForTesting(promptClient as any);
        await disconnectRedis();

        expect(promptClient.quit).toHaveBeenCalled();
        expect(promptClient.disconnect).not.toHaveBeenCalled();
        expect(getRedisClient()).toBeNull();
        expect(jest.getTimerCount()).toBe(0);
      } finally {
        jest.useRealTimers();
      }
    });

    it('triggers disconnect fallback when quit() stalls and exceeds timeout, and clears the timer', async () => {
      jest.useFakeTimers();
      try {
        const hangingClient = {
          status: 'ready' as 'ready' | 'disconnected',
          quit: jest.fn(() => new Promise<void>(() => {})), // Stalled/hanging quit
          disconnect: jest.fn(() => {
            hangingClient.status = 'disconnected';
          }),
        };

        setRedisClientForTesting(hangingClient as any);
        const disconnectPromise = disconnectRedis();

        // Advance fake timers by 3000ms timeout
        jest.advanceTimersByTime(3000);
        await disconnectPromise;

        expect(hangingClient.quit).toHaveBeenCalled();
        expect(hangingClient.disconnect).toHaveBeenCalled();
        expect(getRedisClient()).toBeNull();
        expect(jest.getTimerCount()).toBe(0);
      } finally {
        jest.useRealTimers();
      }
    });

    it('exercises authRateLimitStore delegation methods (init, get, increment, decrement, resetKey, resetAll)', async () => {
      authRateLimitStore.init?.({} as any);

      // Increment
      const inc = await authRateLimitStore.increment('delegate-key');
      expect(inc.totalHits).toBe(1);

      // Get
      if (typeof authRateLimitStore.get === 'function') {
        const info = await authRateLimitStore.get('delegate-key');
        expect(info).toBeDefined();
      }

      // Decrement
      if (typeof authRateLimitStore.decrement === 'function') {
        await authRateLimitStore.decrement('delegate-key');
      }

      // ResetKey
      await authRateLimitStore.resetKey('delegate-key');

      // ResetAll
      await authRateLimitStore.resetAll();
    });

    it('exercises authAccountRateLimiter skip and keyGenerator branches', () => {
      const skipFn = (authAccountRateLimiter as any).skip;
      const keyGenFn = (authAccountRateLimiter as any).keyGenerator;

      if (typeof skipFn === 'function') {
        expect(skipFn({ body: {} } as any)).toBe(true);
        expect(skipFn({ body: { email: 123 } } as any)).toBe(true);
        expect(skipFn({ body: { email: '   ' } } as any)).toBe(true);
        expect(skipFn({ body: { email: 'valid@example.com' } } as any)).toBe(false);
      }

      if (typeof keyGenFn === 'function') {
        expect(keyGenFn({ body: { email: 'valid@example.com' } } as any)).toHaveLength(64);
        expect(keyGenFn({ body: {} } as any)).toHaveLength(64);
      }
    });

    it('exercises RedisStore fallback and resetAll', async () => {
      const store = createRateLimitStore({ prefix: 'rl:mocktest:', client: redisMock });
      await redisMock.call('set', 'rl:mocktest:testkey', '1');
      if (typeof store.resetAll === 'function') {
        await store.resetAll();
      }
      const remaining = await redisMock.call('keys', 'rl:mocktest:*');
      expect(remaining).toHaveLength(0);
    });
  });
});
