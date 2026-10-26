import Redis from 'ioredis';
import { env } from './env';

let redisClient: Redis | null = null;
let isConnecting = false;

export function getRedisClient(): Redis | null {
  return redisClient;
}

export function getRedisStatus(): 'connected' | 'disconnected' | 'disabled' {
  if (env.RATE_LIMIT_STORE === 'memory') {
    return 'disabled';
  }
  return redisClient && redisClient.status === 'ready' ? 'connected' : 'disconnected';
}

export interface ConnectRedisOptions {
  rateLimitStore?: string;
  redisUrl?: string;
  nodeEnv?: string;
}

/**
 * Connects to Redis for distributed rate limiting.
 *
 * Rules:
 * - When RATE_LIMIT_STORE === 'redis', connects and pings the Redis instance.
 * - If connection or ping fails, throws an error (fails closed). SILENT FALLBACK TO MEMORYSTORE IS STRICTLY FORBIDDEN.
 * - When RATE_LIMIT_STORE === 'memory', verifies environment is non-production and logs a clear limitation warning.
 */
export async function connectRedis(options?: ConnectRedisOptions): Promise<Redis | null> {
  const store = options?.rateLimitStore ?? env.RATE_LIMIT_STORE;
  const url = options?.redisUrl ?? env.REDIS_URL;
  const nodeEnv = options?.nodeEnv ?? env.NODE_ENV;

  if (nodeEnv === 'production') {
    if (store !== 'redis' || !url) {
      throw new Error(
        'Production environment strictly forbids MemoryStore. RATE_LIMIT_STORE must be "redis" and REDIS_URL must be configured.'
      );
    }
  }

  if (store !== 'redis') {
    console.warn(
      '⚠️ [RateLimit] Using MemoryStore for rate limiting. NOTE: MemoryStore is limited to a single Node.js process and does not share state across multiple instances. Redis is required for distributed deployments.'
    );
    return null;
  }

  if (!url) {
    throw new Error('RATE_LIMIT_STORE is set to "redis" but REDIS_URL is not configured.');
  }

  if (redisClient && redisClient.status === 'ready') {
    return redisClient;
  }

  if (isConnecting) {
    return redisClient;
  }

  isConnecting = true;
  try {
    const client =
      redisClient ??
      new Redis(url, {
        lazyConnect: true,
        maxRetriesPerRequest: 1,
        enableOfflineQueue: false,
        retryStrategy: (times) => {
          if (times > 3) return null;
          return Math.min(times * 200, 1000);
        },
      });

    client.on('error', (err) => {
      console.error('❌ Redis error:', err.message);
    });

    if (client.status !== 'ready') {
      await client.connect();
    }
    await client.ping();

    redisClient = client;
    console.log('✅ Redis connected for distributed rate limiting');
    return redisClient;
  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    console.error('❌ Failed to connect to Redis for distributed rate limiting:', err.message);
    // Fail-closed guarantee: Never silently fall back to MemoryStore when Redis is configured
    throw new Error(`Redis connection failed (fail closed): ${err.message}`);
  } finally {
    isConnecting = false;
  }
}

/**
 * Disconnects Redis cleanly during application shutdown.
 */
export async function disconnectRedis(): Promise<void> {
  if (!redisClient) return;

  try {
    if (redisClient.status === 'ready' || redisClient.status === 'connecting') {
      let timeoutHandle: NodeJS.Timeout | undefined;
      const timeoutPromise = new Promise<never>((_, reject) => {
        timeoutHandle = setTimeout(() => reject(new Error('Redis quit timeout')), 3000);
      });

      try {
        await Promise.race([redisClient.quit(), timeoutPromise]);
      } catch {
        redisClient?.disconnect();
      } finally {
        if (timeoutHandle) {
          clearTimeout(timeoutHandle);
        }
      }
    }
    console.log('🔌 Redis disconnected');
  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    console.error('❌ Error disconnecting Redis:', err.message);
    throw err;
  } finally {
    redisClient = null;
  }
}

/**
 * Injects a mock or custom Redis client for testing.
 */
export function setRedisClientForTesting(client: Redis | null): void {
  redisClient = client;
}
