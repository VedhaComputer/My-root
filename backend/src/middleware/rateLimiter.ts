import crypto from 'crypto';
import { Request } from 'express';
import rateLimit, { MemoryStore, Store } from 'express-rate-limit';
import { RedisStore, RedisReply } from 'rate-limit-redis';
import { env } from '../config/env';
import { getRedisClient } from '../config/redis';

/**
 * Normalizes an account identifier (email) and hashes it with SHA-256.
 *
 * Rules:
 * 1. Must be trimmed of leading/trailing whitespace.
 * 2. Must be converted to lowercase.
 * 3. Unicode NFKC normalization applied to prevent homoglyph/encoding bypasses.
 * 4. Hashed using SHA-256: raw email address is NEVER used as a Redis key (PII protection).
 * 5. Returns a 64-character hexadecimal digest, safe against key collisions or injection.
 */
export function normalizeAccountKey(identifier: string): string {
  const normalized = identifier.trim().toLowerCase().normalize('NFKC');
  return crypto.createHash('sha256').update(normalized).digest('hex');
}

export interface RateLimitStoreWithReset extends Store {
  resetAll: () => Promise<void>;
}

export interface CreateStoreOptions {
  prefix: string;
  client?: any;
}

/**
 * Creates a rate limit store based on the active environment configuration:
 * - When RATE_LIMIT_STORE === 'redis', instantiates a shared RedisStore via rate-limit-redis.
 * - When RATE_LIMIT_STORE === 'memory', instantiates an in-memory MemoryStore for non-production environments.
 */
export function createRateLimitStore(options: CreateStoreOptions): RateLimitStoreWithReset {
  if (options.client || env.RATE_LIMIT_STORE === 'redis') {
    const store = new RedisStore({
      prefix: options.prefix,
      sendCommand: async (...args: string[]) => {
        const client = options.client ?? getRedisClient();
        if (!client) {
          // If called during store construction before the connection completes,
          // return pre-hashed SHA to satisfy loadIncrementScript/loadGetScript without failing.
          if (args[0] === 'SCRIPT' && args[1] === 'LOAD') {
            return crypto.createHash('sha1').update(args[2]).digest('hex');
          }
          throw new Error('Redis client is not available for distributed rate limiting');
        }
        return client.call(args[0], ...args.slice(1)) as Promise<RedisReply>;
      },
    });

    const storeWithReset = store as unknown as RateLimitStoreWithReset;
    storeWithReset.resetAll = async () => {
      const client = options.client ?? getRedisClient();
      if (!client) return;
      try {
        const keys: string[] =
          typeof client.keys === 'function'
            ? await client.keys(`${options.prefix}*`)
            : await client.call('keys', `${options.prefix}*`);
        if (keys && keys.length > 0) {
          if (typeof client.del === 'function') {
            await client.del(...keys);
          } else {
            await client.call('del', ...keys);
          }
        }
      } catch {
        // Safe reset attempt
      }
    };

    return storeWithReset;
  }

  const memStore = new MemoryStore();
  return memStore as unknown as RateLimitStoreWithReset;
}

// Global API rate limit store and middleware
export const generalRateLimitStore = createRateLimitStore({ prefix: 'rl:gen:' });

export const generalRateLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  store: generalRateLimitStore,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many requests' } },
});

// Authentication IP-based rate limit store and middleware
export const authIpRateLimitStore = createRateLimitStore({ prefix: 'rl:auth:ip:' });

export const authIpRateLimiter = rateLimit({
  windowMs: env.AUTH_RATE_LIMIT_WINDOW_MS,
  max: env.AUTH_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  store: authIpRateLimitStore,
  message: {
    error: {
      code: 'RATE_LIMITED',
      message: 'Too many authentication attempts. Please try again later.',
    },
  },
});

// Authentication Per-Account rate limit store and middleware
export const authAccountRateLimitStore = createRateLimitStore({ prefix: 'rl:auth:acct:' });

export const authAccountRateLimiter = rateLimit({
  windowMs: env.AUTH_ACCOUNT_RATE_LIMIT_WINDOW_MS,
  max: env.AUTH_ACCOUNT_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  store: authAccountRateLimitStore,
  keyGenerator: (req: Request) => {
    const email = typeof req.body?.email === 'string' ? req.body.email : '';
    return normalizeAccountKey(email);
  },
  skip: (req: Request) => {
    const email = req.body?.email;
    return typeof email !== 'string' || email.trim().length === 0;
  },
  message: {
    error: {
      code: 'RATE_LIMITED',
      message: 'Too many authentication attempts. Please try again later.',
    },
  },
});

/**
 * Composite store object for backward compatibility with existing tests and imports.
 * Resetting this store resets both the IP and per-account stores.
 */
export const authRateLimitStore: RateLimitStoreWithReset = {
  ...authIpRateLimitStore,
  init: (options) => {
    authIpRateLimitStore.init?.(options);
  },
  get: (key) => authIpRateLimitStore.get?.(key),
  increment: (key) => authIpRateLimitStore.increment(key),
  decrement: (key) => authIpRateLimitStore.decrement(key),
  resetKey: (key) => authIpRateLimitStore.resetKey(key),
  resetAll: async () => {
    if (typeof authIpRateLimitStore.resetAll === 'function') {
      await authIpRateLimitStore.resetAll();
    }
    if (typeof authAccountRateLimitStore.resetAll === 'function') {
      await authAccountRateLimitStore.resetAll();
    }
  },
};

/**
 * Alias to maintain existing route interface while preserving underlying IP rate limiter
 */
export const authRateLimiter = authIpRateLimiter;

/**
 * Helper to reset all rate limit stores across the application (used in tests)
 */
export async function resetAllRateLimitStores(): Promise<void> {
  if (typeof generalRateLimitStore.resetAll === 'function') {
    await generalRateLimitStore.resetAll();
  }
  if (typeof authIpRateLimitStore.resetAll === 'function') {
    await authIpRateLimitStore.resetAll();
  }
  if (typeof authAccountRateLimitStore.resetAll === 'function') {
    await authAccountRateLimitStore.resetAll();
  }
}
