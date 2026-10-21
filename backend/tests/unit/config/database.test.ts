import mongoose from 'mongoose';
import {
  connectDatabase,
  disconnectDatabase,
  getDatabaseStatus,
  sanitizeErrorMessage,
  _resetListenersForTesting,
} from '../../../src/config/database';

describe('Database Connection Lifecycle (Unit Tests)', () => {
  const originalReadyState = mongoose.connection.readyState;

  beforeEach(() => {
    jest.clearAllMocks();
    _resetListenersForTesting();
    mongoose.connection.removeAllListeners();
    (mongoose.connection as any).readyState = 0;
  });

  afterAll(async () => {
    _resetListenersForTesting();
    mongoose.connection.removeAllListeners();
    (mongoose.connection as any).readyState = originalReadyState;
  });

  describe('getDatabaseStatus', () => {
    it('returns "disconnected" when readyState is 0', () => {
      (mongoose.connection as any).readyState = 0;
      expect(getDatabaseStatus()).toBe('disconnected');
    });

    it('returns "connected" when readyState is 1', () => {
      (mongoose.connection as any).readyState = 1;
      expect(getDatabaseStatus()).toBe('connected');
    });

    it('returns "disconnected" when readyState is 2 (connecting) or 3 (disconnecting)', () => {
      (mongoose.connection as any).readyState = 2;
      expect(getDatabaseStatus()).toBe('disconnected');

      (mongoose.connection as any).readyState = 3;
      expect(getDatabaseStatus()).toBe('disconnected');
    });
  });

  describe('sanitizeErrorMessage', () => {
    it('redacts credentials and hosts from standard MongoDB URIs', () => {
      const rawError = new Error('Failed to connect to mongodb://admin:secretPassword@localhost:27017/myroot');
      const sanitized = sanitizeErrorMessage(rawError);
      expect(sanitized).toBe('Failed to connect to <REDACTED_URI>');
      expect(sanitized).not.toContain('admin');
      expect(sanitized).not.toContain('secretPassword');
      expect(sanitized).not.toContain('localhost:27017');
    });

    it('redacts credentials from mongodb+srv URIs', () => {
      const rawError = new Error('Authentication failed for mongodb+srv://app_user:p@ssword!@cluster0.abc.mongodb.net/myroot?retryWrites=true');
      const sanitized = sanitizeErrorMessage(rawError);
      expect(sanitized).toBe('Authentication failed for <REDACTED_URI>');
      expect(sanitized).not.toContain('app_user');
      expect(sanitized).not.toContain('p@ssword!');
      expect(sanitized).not.toContain('cluster0.abc.mongodb.net');
    });

    it('redacts raw IP addresses and ports from network errors', () => {
      const rawError = new Error('MongoServerSelectionError: connect ECONNREFUSED 127.0.0.1:27017');
      const sanitized = sanitizeErrorMessage(rawError);
      expect(sanitized).toBe('MongoServerSelectionError: connect ECONNREFUSED <REDACTED_HOST>');
      expect(sanitized).not.toContain('127.0.0.1:27017');
    });

    it('redacts bracketed server host:port identifiers', () => {
      const rawError = new Error('failed to connect to server [cluster0-shard-00.mongodb.net:27017] on first connect');
      const sanitized = sanitizeErrorMessage(rawError);
      expect(sanitized).toBe('failed to connect to server [<REDACTED_HOST>] on first connect');
      expect(sanitized).not.toContain('cluster0-shard-00.mongodb.net:27017');
    });

    it('redacts mongodb.net cloud hostnames without brackets', () => {
      const rawError = new Error('getaddrinfo ENOTFOUND cluster0.abc.mongodb.net');
      const sanitized = sanitizeErrorMessage(rawError);
      expect(sanitized).toBe('getaddrinfo ENOTFOUND <REDACTED_HOST>');
      expect(sanitized).not.toContain('cluster0.abc.mongodb.net');
    });

    it('redacts embedded credentials in non-URI messages', () => {
      const rawError = new Error('Authentication failed for root:SuperSecretPassword123@local');
      const sanitized = sanitizeErrorMessage(rawError);
      expect(sanitized).not.toContain('SuperSecretPassword123');
      expect(sanitized).toContain('<REDACTED_CREDENTIALS>@');
    });

    it('leaves non-sensitive error messages intact', () => {
      const normalError = new Error('Server selection timed out after 5000 ms');
      expect(sanitizeErrorMessage(normalError)).toBe('Server selection timed out after 5000 ms');
    });

    it('handles non-Error objects safely', () => {
      expect(sanitizeErrorMessage('Error with mongodb://user:pass@host/db')).toBe('Error with <REDACTED_URI>');
      expect(sanitizeErrorMessage(null)).toBe('Unknown database error');
    });
  });

  describe('connectDatabase', () => {
    it('returns immediately without calling mongoose.connect when already connected (readyState === 1)', async () => {
      (mongoose.connection as any).readyState = 1;
      const connectSpy = jest.spyOn(mongoose, 'connect').mockResolvedValue(mongoose as any);

      await connectDatabase();

      expect(connectSpy).not.toHaveBeenCalled();
      connectSpy.mockRestore();
    });

    it('calls mongoose.connect when disconnected and sets up connection timeout', async () => {
      (mongoose.connection as any).readyState = 0;
      const connectSpy = jest.spyOn(mongoose, 'connect').mockImplementation(async () => {
        (mongoose.connection as any).readyState = 1;
        return mongoose as any;
      });

      await connectDatabase();

      expect(connectSpy).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({ serverSelectionTimeoutMS: 5000 })
      );
      connectSpy.mockRestore();
    });

    it('handles concurrent connectDatabase calls safely by sharing the in-flight connection promise', async () => {
      (mongoose.connection as any).readyState = 0;
      let resolveConnection: () => void;
      const connectSpy = jest.spyOn(mongoose, 'connect').mockImplementation(
        () =>
          new Promise((resolve) => {
            resolveConnection = () => {
              (mongoose.connection as any).readyState = 1;
              resolve(mongoose as any);
            };
          })
      );

      // Launch multiple simultaneous connection calls
      const call1 = connectDatabase();
      const call2 = connectDatabase();
      const call3 = connectDatabase();

      // Resolve the single in-flight connection
      resolveConnection!();
      await Promise.all([call1, call2, call3]);

      // mongoose.connect must have been called exactly once
      expect(connectSpy).toHaveBeenCalledTimes(1);
      connectSpy.mockRestore();
    });

    it('does not register duplicate event listeners on multiple connectDatabase calls', async () => {
      (mongoose.connection as any).readyState = 0;
      const connectSpy = jest.spyOn(mongoose, 'connect').mockImplementation(async () => {
        (mongoose.connection as any).readyState = 1;
        return mongoose as any;
      });

      await connectDatabase();
      await connectDatabase();
      await connectDatabase();

      expect(mongoose.connection.listenerCount('error')).toBe(1);
      expect(mongoose.connection.listenerCount('disconnected')).toBe(1);
      connectSpy.mockRestore();
    });

    it('sanitizes error log and rethrows when mongoose.connect fails', async () => {
      (mongoose.connection as any).readyState = 0;
      const connectSpy = jest.spyOn(mongoose, 'connect').mockRejectedValue(
        new Error('Could not connect to mongodb://dbuser:supersecret@127.0.0.1:27017/myroot')
      );
      const consoleErrorSpy = jest.spyOn(console, 'error').mockImplementation(() => {});

      await expect(connectDatabase()).rejects.toThrow();

      expect(consoleErrorSpy).toHaveBeenCalledWith(
        '❌ MongoDB connection failed:',
        'Could not connect to <REDACTED_URI>'
      );
      expect(consoleErrorSpy.mock.calls[0][1]).not.toContain('supersecret');
      expect(consoleErrorSpy.mock.calls[0][1]).not.toContain('dbuser');

      consoleErrorSpy.mockRestore();
      connectSpy.mockRestore();
    });
  });

  describe('disconnectDatabase', () => {
    it('returns immediately when already disconnected (readyState === 0)', async () => {
      (mongoose.connection as any).readyState = 0;
      const disconnectSpy = jest.spyOn(mongoose, 'disconnect').mockResolvedValue();

      await disconnectDatabase();

      expect(disconnectSpy).not.toHaveBeenCalled();
      disconnectSpy.mockRestore();
    });

    it('calls mongoose.disconnect when connection is open (readyState === 1)', async () => {
      (mongoose.connection as any).readyState = 1;
      const disconnectSpy = jest.spyOn(mongoose, 'disconnect').mockImplementation(async () => {
        (mongoose.connection as any).readyState = 0;
      });

      await disconnectDatabase();

      expect(disconnectSpy).toHaveBeenCalledTimes(1);
      disconnectSpy.mockRestore();
    });

    it('handles concurrent disconnectDatabase calls safely by sharing the in-flight disconnection promise', async () => {
      (mongoose.connection as any).readyState = 1;
      let resolveDisconnection: () => void;
      const disconnectSpy = jest.spyOn(mongoose, 'disconnect').mockImplementation(
        () =>
          new Promise((resolve) => {
            resolveDisconnection = () => {
              (mongoose.connection as any).readyState = 0;
              resolve();
            };
          })
      );

      // Launch multiple simultaneous disconnection calls
      const call1 = disconnectDatabase();
      const call2 = disconnectDatabase();

      resolveDisconnection!();
      await Promise.all([call1, call2]);

      expect(disconnectSpy).toHaveBeenCalledTimes(1);
      disconnectSpy.mockRestore();
    });
  });
});
