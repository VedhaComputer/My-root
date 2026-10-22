import mongoose from 'mongoose';
import { env } from './env';

let listenersRegistered = false;
let connectPromise: Promise<void> | null = null;
let disconnectPromise: Promise<void> | null = null;

function getConnectionState(): number {
  return mongoose.connection.readyState;
}

export function sanitizeErrorMessage(error: unknown): string {
  let message = 'Unknown database error';
  if (error instanceof Error) {
    message = error.message;
  } else if (typeof error === 'string') {
    message = error;
  }

  // 1. Redact any full MongoDB connection URI with or without credentials
  message = message.replace(/mongodb(?:\+srv)?:\/\/[^\s'",]+/gi, '<REDACTED_URI>');

  // 2. Redact embedded credentials pattern (e.g. user:pass@ or user@)
  message = message.replace(/(?:[a-zA-Z0-9._%+-]+):(?:[^\s@:]+)@/g, '<REDACTED_CREDENTIALS>@');

  // 3. Redact IP addresses with optional ports (e.g. 127.0.0.1:27017 or 10.0.0.1)
  message = message.replace(/\b(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?\b/g, '<REDACTED_HOST>');

  // 4. Redact bracketed server addresses (e.g. [cluster0-shard-00.mongodb.net:27017])
  message = message.replace(/\[[a-zA-Z0-9_.-]+(?::\d+)?\]/g, '[<REDACTED_HOST>]');

  // 5. Redact mongodb.net hostnames with optional port
  message = message.replace(/[a-zA-Z0-9_.-]+\.mongodb\.net(?::\d+)?/gi, '<REDACTED_HOST>');

  return message;
}

function registerConnectionListeners(): void {
  if (listenersRegistered) return;
  listenersRegistered = true;

  mongoose.connection.on('error', (err) => {
    console.error('❌ MongoDB connection error:', sanitizeErrorMessage(err));
  });

  mongoose.connection.on('disconnected', () => {
    console.warn('⚠️ MongoDB disconnected');
  });
}

/**
 * Resolves the target database name based on configuration:
 * 1. env.MONGODB_DATABASE if explicitly configured.
 * 2. Database path in env.MONGODB_URI if present.
 * 3. Default fallback:
 *    - In test environments (NODE_ENV === 'test'): 'myroot_test'
 *    - In application environments: 'myroot'
 */
export function resolveDatabaseName(customUri?: string, customDb?: string, customNodeEnv?: string): string {
  const explicitDb = customDb ?? env.MONGODB_DATABASE;
  if (explicitDb && explicitDb.trim().length > 0) {
    return explicitDb.trim();
  }

  const uri = customUri ?? env.MONGODB_URI;
  try {
    const parsed = new URL(uri);
    const dbPath = parsed.pathname.replace(/^\//, '').split('?')[0];
    if (dbPath && dbPath.trim().length > 0) {
      return decodeURIComponent(dbPath.trim());
    }
  } catch {
    const match = uri.match(/mongodb(?:\+srv)?:\/\/[^/]+\/([^?]+)/);
    if (match && match[1] && match[1].trim().length > 0) {
      return decodeURIComponent(match[1].trim());
    }
  }

  const nodeEnv = customNodeEnv ?? env.NODE_ENV;
  return nodeEnv === 'test' ? 'myroot_test' : 'myroot';
}

/**
 * Returns the effective active database name from the live Mongoose connection
 * or resolved configuration if disconnected.
 */
export function getEffectiveDatabaseName(): string {
  if (getConnectionState() === 1 && mongoose.connection.name) {
    return mongoose.connection.name;
  }
  return resolveDatabaseName();
}

export async function connectDatabase(): Promise<void> {
  // 1. If already connected, return immediately
  if (getConnectionState() === 1) {
    return;
  }

  // 2. If a connection is already in progress, await the ongoing promise (concurrency guard)
  if (connectPromise) {
    return connectPromise;
  }

  // 3. If a disconnection is in progress, await it before connecting
  if (disconnectPromise) {
    await disconnectPromise;
  }

  if (getConnectionState() === 1) {
    return;
  }

  registerConnectionListeners();

  const targetDb = resolveDatabaseName();

  connectPromise = (async () => {
    try {
      await mongoose.connect(env.MONGODB_URI, {
        serverSelectionTimeoutMS: 5000,
        dbName: targetDb,
      });
      console.log(`✅ MongoDB connected [database: ${targetDb}]`);
    } catch (error) {
      console.error('❌ MongoDB connection failed:', sanitizeErrorMessage(error));
      throw error;
    }
  })();

  try {
    await connectPromise;
  } finally {
    connectPromise = null;
  }
}

export async function disconnectDatabase(): Promise<void> {
  // 1. If already disconnected, return immediately
  if (getConnectionState() === 0) {
    return;
  }

  // 2. If a disconnection is already in progress, await the ongoing promise (concurrency guard)
  if (disconnectPromise) {
    return disconnectPromise;
  }

  // 3. If a connection is currently in progress, await it before disconnecting
  if (connectPromise) {
    try {
      await connectPromise;
    } catch {
      if (getConnectionState() === 0) {
        return;
      }
    }
  }

  if (getConnectionState() === 0) {
    return;
  }

  disconnectPromise = (async () => {
    try {
      await mongoose.disconnect();
      console.log('🔌 MongoDB disconnected');
    } catch (error) {
      console.error('❌ MongoDB disconnect failed:', sanitizeErrorMessage(error));
      throw error;
    }
  })();

  try {
    await disconnectPromise;
  } finally {
    disconnectPromise = null;
  }
}

export function getDatabaseStatus(): 'connected' | 'disconnected' {
  return getConnectionState() === 1 ? 'connected' : 'disconnected';
}

export function _resetListenersForTesting(): void {
  listenersRegistered = false;
  connectPromise = null;
  disconnectPromise = null;
}
