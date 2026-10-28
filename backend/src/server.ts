import { Server } from 'http';
import { createApp } from './app';
import { connectDatabase, disconnectDatabase } from './config/database';
import { connectRedis, disconnectRedis } from './config/redis';
import { env } from './config/env';
import { validateJwtKeysOnStartup } from './config/keys';
import { placeGatewayService } from './modules/places/gateway';

let server: Server | null = null;
let shutdownPromise: Promise<void> | null = null;
let signalHandlersRegistered = false;

export async function shutdown(signal?: string): Promise<void> {
  if (shutdownPromise) {
    return shutdownPromise;
  }

  if (signal) {
    console.log(`\nReceived ${signal}. Starting graceful shutdown...`);
  }

  shutdownPromise = (async () => {
    const errors: Error[] = [];

    // 1. Close HTTP server first to stop accepting new requests
    if (server && server.listening) {
      try {
        if (typeof (server as any).closeIdleConnections === 'function') {
          (server as any).closeIdleConnections();
        }
        await new Promise<void>((resolve, reject) => {
          server!.close((err) => {
            if (err) reject(err);
            else resolve();
          });
        });
        console.log('🛑 HTTP server closed');
      } catch (httpError) {
        const err = httpError instanceof Error ? httpError : new Error(String(httpError));
        console.error('❌ Error closing HTTP server:', err.message);
        errors.push(err);
      }
    }

    // 2. Always attempt database cleanup, even if HTTP server closing encountered an error
    try {
      await disconnectDatabase();
    } catch (dbError) {
      const err = dbError instanceof Error ? dbError : new Error(String(dbError));
      console.error('❌ Error disconnecting database during shutdown:', err.message);
      errors.push(err);
    }

    // 3. Disconnect Redis client if active
    try {
      await disconnectRedis();
    } catch (redisError) {
      const err = redisError instanceof Error ? redisError : new Error(String(redisError));
      console.error('❌ Error disconnecting Redis during shutdown:', err.message);
      errors.push(err);
    }

    if (errors.length > 0) {
      const combinedMessage = errors.map((e) => e.message).join('; ');
      const failureError = new Error(`Shutdown failed: ${combinedMessage}`);
      console.error('❌ Graceful shutdown failed:', failureError.message);
      throw failureError;
    }

    console.log('✅ Graceful shutdown completed');
  })();

  return shutdownPromise;
}

export function registerSignalHandlers(): void {
  if (signalHandlersRegistered) return;
  signalHandlersRegistered = true;

  const handleSignal = async (signal: string) => {
    try {
      await shutdown(signal);
      process.exit(0);
    } catch {
      process.exit(1);
    }
  };

  process.once('SIGINT', () => {
    void handleSignal('SIGINT');
  });
  process.once('SIGTERM', () => {
    void handleSignal('SIGTERM');
  });
}

export async function startServer(): Promise<Server> {
  try {
    // 1. Validate JWT cryptographic key configuration fail-fast
    validateJwtKeysOnStartup();

    // 2. Establish database connection first
    await connectDatabase();

    // 3. Establish Redis connection for distributed rate limiting
    await connectRedis();

    // 4. Verify My Place API connectivity on startup
    if (placeGatewayService.isProxyEnabled()) {
      await placeGatewayService.checkUpstreamHealth();
    }

    // 5. Start HTTP server
    const app = createApp();
    return await new Promise<Server>((resolve, reject) => {
      const s = app.listen(env.PORT, () => {
        console.log(`🚀 My Root backend running on port ${env.PORT} [${env.NODE_ENV}]`);
        server = s;
        registerSignalHandlers();
        resolve(s);
      });
      s.once('error', (err) => {
        reject(err);
      });
    });
  } catch (error) {
    console.error('Failed to start server:', error instanceof Error ? error.message : error);
    process.exit(1);
  }
}

export function _setServerInstanceForTesting(s: Server | null): void {
  server = s;
}

export function _resetShutdownPromiseForTesting(): void {
  shutdownPromise = null;
}

export function _resetSignalHandlersForTesting(): void {
  signalHandlersRegistered = false;
}

if (require.main === module) {
  void startServer();
}
