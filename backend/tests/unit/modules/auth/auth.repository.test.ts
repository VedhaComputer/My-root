import mongoose from 'mongoose';
import { AuthRepository } from '../../../../src/modules/auth/repository';
import { RefreshTokenModel, hashToken } from '../../../../src/modules/auth/refreshToken.model';
import { UserModel } from '../../../../src/modules/auth/user.model';
import { NotFoundError, ServiceUnavailableError } from '../../../../src/shared/errors/AppError';

describe('AuthRepository (Unit Tests - Database Disconnection & Failsafe)', () => {
  let authRepo: AuthRepository;
  let originalReadyState: number;

  beforeEach(() => {
    jest.clearAllMocks();
    authRepo = new AuthRepository();
    originalReadyState = mongoose.connection.readyState;
  });

  afterEach(() => {
    (mongoose.connection as any).readyState = originalReadyState;
  });

  describe('Database Disconnected (readyState !== 1) Fail-Closed Safeguards', () => {
    beforeEach(() => {
      // Mock disconnected state safely without altering real database connection
      (mongoose.connection as any).readyState = 0;
    });

    it('saveRefreshToken throws ServiceUnavailableError and attempts no database write when MongoDB is disconnected', async () => {
      const saveSpy = jest.spyOn(RefreshTokenModel.prototype, 'save');
      const validUserId = new mongoose.Types.ObjectId().toString();
      const futureDate = new Date(Date.now() + 86400000);

      await expect(
        authRepo.saveRefreshToken(validUserId, 'test-refresh-token', futureDate, 'family-test')
      ).rejects.toThrow(ServiceUnavailableError);
      await expect(
        authRepo.saveRefreshToken(validUserId, 'test-refresh-token', futureDate, 'family-test')
      ).rejects.toThrow('Authentication service unavailable: database disconnected');

      expect(saveSpy).not.toHaveBeenCalled();
      saveSpy.mockRestore();
    });

    it('revokeRefreshToken throws ServiceUnavailableError when MongoDB is disconnected', async () => {
      const updateOneSpy = jest.spyOn(RefreshTokenModel, 'updateOne');

      await expect(authRepo.revokeRefreshToken('test-token-string')).rejects.toThrow(
        ServiceUnavailableError
      );
      await expect(authRepo.revokeRefreshToken('test-token-string')).rejects.toThrow(
        'Authentication service unavailable: database disconnected'
      );
      expect(updateOneSpy).not.toHaveBeenCalled();
    });

    it('resetPassword throws ServiceUnavailableError when MongoDB is disconnected', async () => {
      const findByIdAndUpdateSpy = jest.spyOn(UserModel, 'findByIdAndUpdate');
      const validUserId = new mongoose.Types.ObjectId().toString();

      await expect(
        authRepo.resetPassword(validUserId, 'new-hashed-password')
      ).rejects.toThrow(ServiceUnavailableError);
      await expect(
        authRepo.resetPassword(validUserId, 'new-hashed-password')
      ).rejects.toThrow('Authentication service unavailable: database disconnected');
      expect(findByIdAndUpdateSpy).not.toHaveBeenCalled();
    });

    it('markEmailVerified throws ServiceUnavailableError when MongoDB is disconnected', async () => {
      const findByIdAndUpdateSpy = jest.spyOn(UserModel, 'findByIdAndUpdate');
      const validUserId = new mongoose.Types.ObjectId().toString();

      await expect(authRepo.markEmailVerified(validUserId)).rejects.toThrow(
        ServiceUnavailableError
      );
      await expect(authRepo.markEmailVerified(validUserId)).rejects.toThrow(
        'Authentication service unavailable: database disconnected'
      );
      expect(findByIdAndUpdateSpy).not.toHaveBeenCalled();
    });

    it('revokeAllUserRefreshTokens throws ServiceUnavailableError when MongoDB is disconnected', async () => {
      const updateManySpy = jest.spyOn(RefreshTokenModel, 'updateMany');
      const validUserId = new mongoose.Types.ObjectId().toString();

      await expect(authRepo.revokeAllUserRefreshTokens(validUserId)).rejects.toThrow(
        ServiceUnavailableError
      );
      await expect(authRepo.revokeAllUserRefreshTokens(validUserId)).rejects.toThrow(
        'Authentication service unavailable: database disconnected'
      );
      expect(updateManySpy).not.toHaveBeenCalled();
    });

    it('revokeTokenFamily throws ServiceUnavailableError when MongoDB is disconnected', async () => {
      const updateManySpy = jest.spyOn(RefreshTokenModel, 'updateMany');

      await expect(authRepo.revokeTokenFamily('family-123')).rejects.toThrow(
        ServiceUnavailableError
      );
      await expect(authRepo.revokeTokenFamily('family-123')).rejects.toThrow(
        'Authentication service unavailable: database disconnected'
      );
      expect(updateManySpy).not.toHaveBeenCalled();
    });

    it('findByEmailVerificationToken returns null when MongoDB is disconnected', async () => {
      const result = await authRepo.findByEmailVerificationToken('some-token-hash');
      expect(result).toBeNull();
    });
  });

  describe('Database Connected (readyState === 1) Normal Operation', () => {
    beforeEach(() => {
      (mongoose.connection as any).readyState = 1;
    });

    it('revokeRefreshToken executes updateOne and returns true when token was modified', async () => {
      const mockExec = jest.fn().mockResolvedValue({ modifiedCount: 1 });
      jest.spyOn(RefreshTokenModel, 'updateOne').mockReturnValue({ exec: mockExec } as any);

      const result = await authRepo.revokeRefreshToken('active-token-string');

      expect(result).toBe(true);
      expect(RefreshTokenModel.updateOne).toHaveBeenCalledWith(
        expect.objectContaining({ revoked: false }),
        expect.objectContaining({ $set: { revoked: true } })
      );
    });

    it('findByStoredTokenHash queries RefreshTokenModel directly by tokenHash', async () => {
      const mockExec = jest.fn().mockResolvedValue({ tokenHash: 'stored-hash-abc' });
      jest.spyOn(RefreshTokenModel, 'findOne').mockReturnValue({ exec: mockExec } as any);

      const result = await authRepo.findByStoredTokenHash('stored-hash-abc');

      expect(result).toEqual({ tokenHash: 'stored-hash-abc' });
      expect(RefreshTokenModel.findOne).toHaveBeenCalledWith({ tokenHash: 'stored-hash-abc' });
    });

    it('rollbackTokenRotation resets revoked to false and replacedByTokenHash to null', async () => {
      const mockExec = jest.fn().mockResolvedValue({ modifiedCount: 1 });
      jest.spyOn(RefreshTokenModel, 'updateOne').mockReturnValue({ exec: mockExec } as any);

      const result = await authRepo.rollbackTokenRotation('raw-token-to-rollback');

      expect(result).toBe(true);
      expect(RefreshTokenModel.updateOne).toHaveBeenCalledWith(
        expect.objectContaining({ revoked: true }),
        { $set: { revoked: false, replacedByTokenHash: null } }
      );
    });

    it('rollbackTokenRotation does NOT reactivate old token if replacement was already persisted in database', async () => {
      jest.spyOn(RefreshTokenModel, 'exists').mockReturnValue({
        exec: jest.fn().mockResolvedValue({ _id: new mongoose.Types.ObjectId() }),
      } as any);
      const updateSpy = jest.spyOn(RefreshTokenModel, 'updateOne');

      const result = await authRepo.rollbackTokenRotation('raw-token-to-rollback', 'persisted-replacement-hash');

      expect(result).toBe(false);
      expect(RefreshTokenModel.exists).toHaveBeenCalledWith({ tokenHash: 'persisted-replacement-hash' });
      expect(updateSpy).not.toHaveBeenCalled();
    });

    it('rollbackTokenRotation predicates on expectedReplacedByTokenHash to prevent race with another rotation', async () => {
      jest.spyOn(RefreshTokenModel, 'exists').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);
      const mockExec = jest.fn().mockResolvedValue({ modifiedCount: 1 });
      jest.spyOn(RefreshTokenModel, 'updateOne').mockReturnValue({ exec: mockExec } as any);

      const result = await authRepo.rollbackTokenRotation('raw-token-to-rollback', 'target-replacement-hash');

      expect(result).toBe(true);
      expect(RefreshTokenModel.updateOne).toHaveBeenCalledWith(
        expect.objectContaining({
          revoked: true,
          replacedByTokenHash: 'target-replacement-hash',
        }),
        { $set: { revoked: false, replacedByTokenHash: null } }
      );
    });

    it('rollbackTokenRotation returns false when another rotation has superseded replacedByTokenHash', async () => {
      jest.spyOn(RefreshTokenModel, 'exists').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);
      const mockExec = jest.fn().mockResolvedValue({ modifiedCount: 0 }); // superseded, 0 matched
      jest.spyOn(RefreshTokenModel, 'updateOne').mockReturnValue({ exec: mockExec } as any);

      const result = await authRepo.rollbackTokenRotation('raw-token-to-rollback', 'superseded-replacement-hash');

      expect(result).toBe(false);
    });

    it('detects TOCTOU race when replacement is persisted concurrently between pre-check and update, immediately re-revoking old token', async () => {
      // 1. Pre-check returns null (replacement not yet in DB)
      // 2. Post-check returns { _id } (replacement was inserted concurrently!)
      const existsMock = jest
        .fn()
        .mockReturnValueOnce({ exec: jest.fn().mockResolvedValue(null) }) // Pre-check
        .mockReturnValueOnce({ exec: jest.fn().mockResolvedValue({ _id: new mongoose.Types.ObjectId() }) }); // Post-check
      jest.spyOn(RefreshTokenModel, 'exists').mockImplementation(existsMock as any);

      const updateOneMock = jest.fn().mockReturnValue({ exec: jest.fn().mockResolvedValue({ modifiedCount: 1 }) });
      jest.spyOn(RefreshTokenModel, 'updateOne').mockImplementation(updateOneMock as any);

      const result = await authRepo.rollbackTokenRotation('raw-token-to-rollback', 'concurrent-replacement-hash');

      expect(result).toBe(false);
      expect(existsMock).toHaveBeenCalledTimes(2);
      expect(updateOneMock).toHaveBeenCalledTimes(2);
      expect(updateOneMock).toHaveBeenNthCalledWith(
        1,
        expect.objectContaining({
          revoked: true,
          replacedByTokenHash: 'concurrent-replacement-hash',
        }),
        { $set: { revoked: false, replacedByTokenHash: null } }
      );
      expect(updateOneMock).toHaveBeenNthCalledWith(
        2,
        expect.objectContaining({
          revoked: false,
        }),
        { $set: { revoked: true, replacedByTokenHash: 'concurrent-replacement-hash' } }
      );
    });

    it('findByStoredTokenHash returns null when database is disconnected', async () => {
      (mongoose.connection as any).readyState = 0;
      const result = await authRepo.findByStoredTokenHash('stored-hash-abc');
      expect(result).toBeNull();
    });

    it('rollbackTokenRotation returns false when database is disconnected', async () => {
      (mongoose.connection as any).readyState = 0;
      const result = await authRepo.rollbackTokenRotation('raw-token-to-rollback');
      expect(result).toBe(false);
    });

    it('resetPassword executes findByIdAndUpdate with new passwordHash and tokenVersion increment', async () => {
      const validUserId = new mongoose.Types.ObjectId().toString();
      const mockExec = jest.fn().mockResolvedValue({ _id: validUserId });
      jest.spyOn(UserModel, 'findByIdAndUpdate').mockReturnValue({ exec: mockExec } as any);

      await authRepo.resetPassword(validUserId, 'new-hashed-password');

      expect(UserModel.findByIdAndUpdate).toHaveBeenCalledWith(
        validUserId,
        expect.objectContaining({
          $set: expect.objectContaining({
            passwordHash: 'new-hashed-password',
            passwordResetTokenHash: null,
            passwordResetExpiresAt: null,
          }),
          $inc: { tokenVersion: 1 },
        })
      );
    });

  describe('markEmailVerified & findByEmailVerificationToken fail-closed behavior', () => {
    it('markEmailVerified throws NotFoundError if user document is not found during update', async () => {
      const validUserId = new mongoose.Types.ObjectId().toString();
      const mockExec = jest.fn().mockResolvedValue(null);
      jest.spyOn(UserModel, 'findByIdAndUpdate').mockReturnValue({ exec: mockExec } as any);

      await expect(authRepo.markEmailVerified(validUserId)).rejects.toThrow(NotFoundError);
    });

    it('markEmailVerified executes findByIdAndUpdate setting isEmailVerified to true', async () => {
      const validUserId = new mongoose.Types.ObjectId().toString();
      const mockExec = jest.fn().mockResolvedValue({ _id: validUserId, isEmailVerified: true });
      jest.spyOn(UserModel, 'findByIdAndUpdate').mockReturnValue({ exec: mockExec } as any);

      await authRepo.markEmailVerified(validUserId);

      expect(UserModel.findByIdAndUpdate).toHaveBeenCalledWith(
        validUserId,
        expect.objectContaining({
          $set: expect.objectContaining({
            isEmailVerified: true,
            emailVerificationTokenHash: null,
            emailVerificationExpiresAt: null,
          }),
        })
      );
    });
  });
  });

  describe('rotateAndSaveRefreshToken & supportsTransactions Topology Verification', () => {
    it('supportsTransactions returns false when MongoDB connection is not ready (readyState !== 1)', () => {
      // Disconnected state: must fail closed without even inspecting topology
      (mongoose.connection as any).readyState = 0;
      expect(authRepo.supportsTransactions()).toBe(false);
      // Restore
      (mongoose.connection as any).readyState = 1;
    });

    it('supportsTransactions returns false when topology description has compatibilityError', () => {
      jest.spyOn(mongoose.connection, 'getClient').mockReturnValue({
        topology: { description: { type: 'ReplicaSetNoPrimary', compatibilityError: 'Unsupported wire protocol' } },
      } as any);
      expect(authRepo.supportsTransactions()).toBe(false);
    });

    it('supportsTransactions returns true for ReplicaSetWithPrimary or Sharded', () => {
      jest.spyOn(mongoose.connection, 'getClient').mockReturnValue({
        topology: { description: { type: 'ReplicaSetWithPrimary' } },
      } as any);
      expect(authRepo.supportsTransactions()).toBe(true);

      jest.spyOn(mongoose.connection, 'getClient').mockReturnValue({
        topology: { description: { type: 'Sharded' } },
      } as any);
      expect(authRepo.supportsTransactions()).toBe(true);
    });

    it('supportsTransactions returns true for directConnection Single with RSPrimary server', () => {
      const servers = new Map();
      servers.set('127.0.0.1:27018', { type: 'RSPrimary' });
      jest.spyOn(mongoose.connection, 'getClient').mockReturnValue({
        topology: { description: { type: 'Single', servers } },
      } as any);
      expect(authRepo.supportsTransactions()).toBe(true);
    });

    it('supportsTransactions returns false for standalone deployment', () => {
      const servers = new Map();
      servers.set('127.0.0.1:27017', { type: 'Standalone' });
      jest.spyOn(mongoose.connection, 'getClient').mockReturnValue({
        topology: { description: { type: 'Single', servers } },
      } as any);
      expect(authRepo.supportsTransactions()).toBe(false);
    });

    it('rotateAndSaveRefreshToken executes in transaction session when supported', async () => {
      jest.spyOn(authRepo, 'supportsTransactions').mockReturnValue(true);
      const mockSession = {
        withTransaction: jest.fn().mockImplementation(async (cb: any) => {
          await cb();
        }),
        endSession: jest.fn().mockResolvedValue(undefined),
      };
      jest.spyOn(mongoose, 'startSession').mockResolvedValue(mockSession as any);

      const mockRotatedDoc = { tokenHash: 'rotated-old-hash' };
      const findOneAndUpdateMock = jest.fn().mockReturnValue({
        exec: jest.fn().mockResolvedValue(mockRotatedDoc),
      });
      jest.spyOn(RefreshTokenModel, 'findOneAndUpdate').mockImplementation(findOneAndUpdateMock as any);

      const mockCreatedDoc = { tokenHash: 'new-hash-xyz', revoked: false };
      jest.spyOn(RefreshTokenModel, 'create').mockResolvedValue([mockCreatedDoc] as any);

      const result = await authRepo.rotateAndSaveRefreshToken(
        'old-token-val',
        'new-token-val',
        new mongoose.Types.ObjectId().toString(),
        new Date(Date.now() + 100000),
        'fam-tx-1'
      );

      expect(result.rotated).toBe(true);
      expect(result.replacement).toEqual(mockCreatedDoc);
      expect(mockSession.withTransaction).toHaveBeenCalled();
      expect(mockSession.endSession).toHaveBeenCalled();
    });

    it('rotateAndSaveRefreshToken returns rotated: false when old token was already rotated concurrently', async () => {
      jest.spyOn(authRepo, 'supportsTransactions').mockReturnValue(true);
      const mockSession = {
        withTransaction: jest.fn().mockImplementation(async (cb: any) => {
          await cb();
        }),
        endSession: jest.fn().mockResolvedValue(undefined),
      };
      jest.spyOn(mongoose, 'startSession').mockResolvedValue(mockSession as any);

      jest.spyOn(RefreshTokenModel, 'findOneAndUpdate').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);
      const createSpy = jest.spyOn(RefreshTokenModel, 'create');

      const result = await authRepo.rotateAndSaveRefreshToken(
        'old-token-val',
        'new-token-val',
        new mongoose.Types.ObjectId().toString(),
        new Date(Date.now() + 100000),
        'fam-tx-1'
      );

      expect(result.rotated).toBe(false);
      expect(result.replacement).toBeNull();
      expect(createSpy).not.toHaveBeenCalled();
    });
  });

  describe('Document State Transitions & TOCTOU Interleaving Verification', () => {
    it('verifies persisted document state on legitimate retry: un-revokes old token and clears replacedByTokenHash', async () => {
      const dbDoc = {
        tokenHash: hashToken('legit-old-token'),
        revoked: true,
        replacedByTokenHash: 'unpersisted-replacement-hash',
      };

      jest.spyOn(RefreshTokenModel, 'exists').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      jest.spyOn(RefreshTokenModel, 'updateOne').mockImplementation(((filter: any, update: any) => {
        return {
          exec: async () => {
            if (filter.tokenHash === dbDoc.tokenHash && filter.revoked === true && filter.replacedByTokenHash === dbDoc.replacedByTokenHash) {
              dbDoc.revoked = update.$set.revoked;
              dbDoc.replacedByTokenHash = update.$set.replacedByTokenHash;
              return { modifiedCount: 1 };
            }
            return { modifiedCount: 0 };
          },
        };
      }) as any);

      const rolledBack = await authRepo.rollbackTokenRotation('legit-old-token', 'unpersisted-replacement-hash');
      expect(rolledBack).toBe(true);

      // Verify persisted state: old token is un-revoked and replacement pointer cleared
      expect(dbDoc.revoked).toBe(false);
      expect(dbDoc.replacedByTokenHash).toBeNull();
    });

    it('verifies persisted document state when replacement was already persisted: old token remains revoked', async () => {
      const dbDoc = {
        tokenHash: hashToken('persisted-old-token'),
        revoked: true,
        replacedByTokenHash: 'already-persisted-replacement-hash',
      };

      jest.spyOn(RefreshTokenModel, 'exists').mockReturnValue({
        exec: jest.fn().mockResolvedValue({ _id: new mongoose.Types.ObjectId() }),
      } as any);

      const updateSpy = jest.spyOn(RefreshTokenModel, 'updateOne');

      const rolledBack = await authRepo.rollbackTokenRotation('persisted-old-token', 'already-persisted-replacement-hash');
      expect(rolledBack).toBe(false);

      // Verify persisted state: old token remains strictly revoked and bound to replacement
      expect(dbDoc.revoked).toBe(true);
      expect(dbDoc.replacedByTokenHash).toBe('already-persisted-replacement-hash');
      expect(updateSpy).not.toHaveBeenCalled();
    });

    it('verifies persisted document state when rotation was superseded: old token remains revoked with superseding replacement', async () => {
      const dbDoc = {
        tokenHash: hashToken('superseded-old-token'),
        revoked: true,
        replacedByTokenHash: 'superseding-replacement-hash',
      };

      jest.spyOn(RefreshTokenModel, 'exists').mockReturnValue({
        exec: jest.fn().mockResolvedValue(null),
      } as any);

      jest.spyOn(RefreshTokenModel, 'updateOne').mockImplementation(((filter: any, update: any) => {
        return {
          exec: async () => {
            if (filter.tokenHash === dbDoc.tokenHash && filter.revoked === true && filter.replacedByTokenHash === dbDoc.replacedByTokenHash) {
              dbDoc.revoked = update.$set.revoked;
              dbDoc.replacedByTokenHash = update.$set.replacedByTokenHash;
              return { modifiedCount: 1 };
            }
            return { modifiedCount: 0 };
          },
        };
      }) as any);

      // Attempt rollback with stale replacement hash
      const rolledBack = await authRepo.rollbackTokenRotation('superseded-old-token', 'stale-replacement-hash');
      expect(rolledBack).toBe(false);

      // Verify persisted state: old token remains strictly revoked and still bound to superseding replacement
      expect(dbDoc.revoked).toBe(true);
      expect(dbDoc.replacedByTokenHash).toBe('superseding-replacement-hash');
    });

    it('verifies persisted document state during TOCTOU interleaving: immediately restores revoked state', async () => {
      const dbDoc = {
        tokenHash: hashToken('toctou-old-token'),
        revoked: true,
        replacedByTokenHash: 'interleaved-replacement-hash',
      };

      let replacementInDb = false;

      // Pre-check returns false (replacement not yet in DB)
      // Post-check returns true (replacement was inserted concurrently!)
      jest.spyOn(RefreshTokenModel, 'exists').mockImplementation((() => {
        return {
          exec: async () => {
            return replacementInDb ? { _id: new mongoose.Types.ObjectId() } : null;
          },
        };
      }) as any);

      jest.spyOn(RefreshTokenModel, 'updateOne').mockImplementation(((filter: any, update: any) => {
        return {
          exec: async () => {
            if (filter.tokenHash === dbDoc.tokenHash) {
              if (filter.revoked === undefined || filter.revoked === dbDoc.revoked) {
                dbDoc.revoked = update.$set.revoked;
                dbDoc.replacedByTokenHash = update.$set.replacedByTokenHash;
                // Simulate concurrent interleaving: replacement written to DB right after first update!
                replacementInDb = true;
                return { modifiedCount: 1 };
              }
            }
            return { modifiedCount: 0 };
          },
        };
      }) as any);

      const rolledBack = await authRepo.rollbackTokenRotation('toctou-old-token', 'interleaved-replacement-hash');
      expect(rolledBack).toBe(false);

      // Verify persisted state: TOCTOU guard caught the race and immediately restored revoked: true!
      expect(dbDoc.revoked).toBe(true);
      expect(dbDoc.replacedByTokenHash).toBe('interleaved-replacement-hash');
    });
  });
});
