import mongoose from 'mongoose';
import {
  resolveDatabaseName,
  getEffectiveDatabaseName,
  connectDatabase,
  disconnectDatabase,
} from '../../../src/config/database';
import { UserModel } from '../../../src/modules/auth/user.model';
import { authRepository } from '../../../src/modules/auth/repository';

describe('Database Selection & Isolation (Regression Tests)', () => {
  describe('1. resolveDatabaseName Logic', () => {
    it('prefers explicit MONGODB_DATABASE over URI path when provided', () => {
      const dbName = resolveDatabaseName(
        'mongodb://localhost:27017/ignored_uri_db',
        'myroot',
        'production'
      );
      expect(dbName).toBe('myroot');
    });

    it('extracts database name from standard MongoDB URI with path', () => {
      const dbName = resolveDatabaseName(
        'mongodb://localhost:27017/myroot',
        undefined,
        'production'
      );
      expect(dbName).toBe('myroot');
    });

    it('extracts database name from URI containing query parameters', () => {
      const dbName = resolveDatabaseName(
        'mongodb://localhost:27017/myroot?replicaSet=rs0&readPreference=primary',
        undefined,
        'production'
      );
      expect(dbName).toBe('myroot');
    });

    it('extracts database name from URI containing URL-encoded characters', () => {
      const dbName = resolveDatabaseName(
        'mongodb://localhost:27017/my%20root',
        undefined,
        'production'
      );
      expect(dbName).toBe('my root');
    });

    it('defaults to myroot for bare URI without path in non-test environment', () => {
      const dbName = resolveDatabaseName(
        'mongodb://localhost:27017',
        undefined,
        'production'
      );
      expect(dbName).toBe('myroot');
    });

    it('defaults to myroot_test for bare URI in test environment', () => {
      const dbName = resolveDatabaseName(
        'mongodb://localhost:27017',
        undefined,
        'test'
      );
      expect(dbName).toBe('myroot_test');
    });
  });

  describe('2. Connection Database Selection & Test Isolation', () => {
    const originalReadyState = mongoose.connection.readyState;

    beforeEach(() => {
      jest.clearAllMocks();
      (mongoose.connection as any).readyState = 0;
    });

    afterAll(() => {
      (mongoose.connection as any).readyState = originalReadyState;
    });

    it('connectDatabase passes resolved database name as dbName option to mongoose.connect', async () => {
      const connectSpy = jest.spyOn(mongoose, 'connect').mockImplementation(async () => {
        (mongoose.connection as any).readyState = 1;
        return mongoose as any;
      });

      await connectDatabase();

      expect(connectSpy).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          dbName: 'myroot_test',
        })
      );
      connectSpy.mockRestore();
    });

    it('getEffectiveDatabaseName returns active connection name or falls back to resolved name', () => {
      // When connected with a connection name
      (mongoose.connection as any).readyState = 1;
      (mongoose.connection as any).name = 'custom_db';
      expect(getEffectiveDatabaseName()).toBe('custom_db');

      // When disconnected
      (mongoose.connection as any).readyState = 0;
      (mongoose.connection as any).name = undefined;
      expect(getEffectiveDatabaseName()).toBe('myroot_test');
    });

    it('UserModel targets the users collection and uses active mongoose connection', () => {
      expect(UserModel.collection.name).toBe('users');
      expect(UserModel.db).toBe(mongoose.connection);
    });

    it('guarantees complete isolation between test and application databases by default', () => {
      const appDb = resolveDatabaseName('mongodb://localhost:27017', undefined, 'development');
      const prodDb = resolveDatabaseName('mongodb://localhost:27017', undefined, 'production');
      const testDb = resolveDatabaseName('mongodb://localhost:27017', undefined, 'test');

      expect(appDb).toBe('myroot');
      expect(prodDb).toBe('myroot');
      expect(testDb).toBe('myroot_test');
      expect(testDb).not.toBe(appDb);
    });
  });
});
