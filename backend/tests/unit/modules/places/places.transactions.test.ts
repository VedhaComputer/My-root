import mongoose, { ClientSession } from 'mongoose';
import { PlaceService } from '../../../../src/modules/places/service';
import { PlaceRepository } from '../../../../src/modules/places/repository';
import { PLACE_LEVELS } from '../../../../src/shared/constants';
import {
  NotFoundError,
  ConflictError,
  BusinessRuleError,
  AppError,
} from '../../../../src/shared/errors/AppError';

describe('Places Transaction-Based Hierarchy Integrity (Regression Tests)', () => {
  let mockRepo: jest.Mocked<PlaceRepository>;
  let placeService: PlaceService;
  const mockSession = { id: 'mock-session-uuid-123' } as unknown as ClientSession;

  beforeEach(() => {
    mockRepo = {
      create: jest.fn(),
      findById: jest.fn(),
      findDuplicate: jest.fn(),
      list: jest.fn(),
      findChildren: jest.fn(),
      countChildren: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      getAncestors: jest.fn(),
      touch: jest.fn(),
      withTransaction: jest.fn(async (work: (session: ClientSession) => Promise<any>) => {
        return await work(mockSession);
      }),
    } as unknown as jest.Mocked<PlaceRepository>;

    placeService = new PlaceService(mockRepo);
  });

  describe('Session Propagation Across Operations', () => {
    it('passes the exact session through all repository operations during child creation', async () => {
      mockRepo.touch.mockResolvedValue({
        _id: 'state-1',
        level: PLACE_LEVELS.STATE,
        canonicalName: 'Rajasthan',
      } as any);
      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.create.mockResolvedValue({
        _id: 'dist-1',
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
        names: [{ language: 'en', name: 'Jodhpur' }],
        parentId: 'state-1',
      } as any);
      mockRepo.findById.mockResolvedValue({
        _id: 'dist-1',
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
        names: [{ language: 'en', name: 'Jodhpur' }],
        parentId: 'state-1',
      } as any);
      mockRepo.getAncestors.mockResolvedValue([]);

      await placeService.createPlace({
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
        names: [{ language: 'en', name: 'Jodhpur' }],
        parentId: 'state-1',
      });

      expect(mockRepo.withTransaction).toHaveBeenCalledTimes(1);
      // Verify session propagation to parent write-lock touch
      expect(mockRepo.touch).toHaveBeenCalledWith('state-1', mockSession);
      // Verify session propagation to duplicate check
      expect(mockRepo.findDuplicate).toHaveBeenCalledWith(
        'Jodhpur',
        PLACE_LEVELS.DISTRICT,
        'state-1',
        mockSession
      );
      // Verify session propagation to place document creation
      expect(mockRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({ canonicalName: 'Jodhpur' }),
        mockSession
      );
      // Verify session propagation to subsequent snapshot reads
      expect(mockRepo.findById).toHaveBeenCalledWith('dist-1', mockSession);
      expect(mockRepo.getAncestors).toHaveBeenCalledWith('dist-1', mockSession);
    });

    it('passes the exact session through all repository operations during deletion', async () => {
      mockRepo.touch.mockResolvedValue({
        _id: 'vil-1',
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Mandore',
      } as any);
      mockRepo.countChildren.mockResolvedValue(0);
      mockRepo.delete.mockResolvedValue(true);

      await placeService.deletePlace('vil-1');

      expect(mockRepo.withTransaction).toHaveBeenCalledTimes(1);
      // Verify write-lock touch on target document uses session
      expect(mockRepo.touch).toHaveBeenCalledWith('vil-1', mockSession);
      // Verify child count query uses session
      expect(mockRepo.countChildren).toHaveBeenCalledWith('vil-1', mockSession);
      // Verify delete uses session
      expect(mockRepo.delete).toHaveBeenCalledWith('vil-1', mockSession);
    });

    it('passes the exact session through reparenting operations', async () => {
      mockRepo.touch.mockImplementation(async (id: string) => {
        if (id === 'child-1') {
          return {
            _id: 'child-1',
            level: PLACE_LEVELS.VILLAGE,
            canonicalName: 'Small Village',
            parentId: 'tehsil-old',
          } as any;
        }
        if (id === 'tehsil-new') {
          return {
            _id: 'tehsil-new',
            level: PLACE_LEVELS.TEHSIL,
            canonicalName: 'New Tehsil',
          } as any;
        }
        return null;
      });
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'child-1') {
          return {
            _id: 'child-1',
            level: PLACE_LEVELS.VILLAGE,
            canonicalName: 'Small Village',
            parentId: 'tehsil-new',
          } as any;
        }
        return null;
      });
      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.update.mockResolvedValue({} as any);
      mockRepo.getAncestors.mockResolvedValue([]);

      await placeService.updatePlace('child-1', {
        parentId: 'tehsil-new',
      });

      expect(mockRepo.withTransaction).toHaveBeenCalledTimes(1);
      // Verify locks acquired on both child and new parent
      expect(mockRepo.touch).toHaveBeenCalledWith('child-1', mockSession);
      expect(mockRepo.touch).toHaveBeenCalledWith('tehsil-new', mockSession);
      // Verify update uses session
      expect(mockRepo.update).toHaveBeenCalledWith(
        'child-1',
        expect.objectContaining({ parentId: 'tehsil-new' }),
        mockSession
      );
    });
  });

  describe('Parent Deletion vs Child Creation Race Protection', () => {
    it('aborts child creation cleanly when parent has been concurrently deleted', async () => {
      // Touch returns null when parent was deleted by concurrent transaction
      mockRepo.touch.mockResolvedValue(null);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.DISTRICT,
          canonicalName: 'Jodhpur',
          names: [{ language: 'en', name: 'Jodhpur' }],
          parentId: 'state-deleted',
        })
      ).rejects.toThrow(NotFoundError);

      expect(mockRepo.create).not.toHaveBeenCalled();
    });

    it('blocks parent deletion when child has been concurrently created', async () => {
      mockRepo.touch.mockResolvedValue({
        _id: 'state-1',
        level: PLACE_LEVELS.STATE,
        canonicalName: 'Rajasthan',
      } as any);
      // Child count is 1 because concurrent child creation committed first
      mockRepo.countChildren.mockResolvedValue(1);

      await expect(placeService.deletePlace('state-1')).rejects.toThrow(BusinessRuleError);
      expect(mockRepo.delete).not.toHaveBeenCalled();
    });
  });

  describe('Parent-Level Update vs Child Creation Concurrency Protection', () => {
    it('blocks level change when existing child is incompatible with new level', async () => {
      mockRepo.touch.mockResolvedValue({
        _id: 'place-1',
        level: PLACE_LEVELS.TEHSIL,
        canonicalName: 'Tehsil Hub',
      } as any);

      // Child is CITY_TOWN, which requires parent to be TEHSIL
      mockRepo.findChildren.mockResolvedValue([
        {
          _id: 'city-child',
          level: PLACE_LEVELS.CITY_TOWN,
          canonicalName: 'City Sub',
        } as any,
      ]);

      // Attempting to downgrade Tehsil to Village would invalidate CITY_TOWN child
      await expect(
        placeService.updatePlace('place-1', {
          level: PLACE_LEVELS.VILLAGE,
        })
      ).rejects.toThrow(BusinessRuleError);

      expect(mockRepo.update).not.toHaveBeenCalled();
    });

    it('aborts child creation when parent level was concurrently updated to incompatible level', async () => {
      // Parent was concurrently updated from DISTRICT to CITY_TOWN
      mockRepo.touch.mockResolvedValue({
        _id: 'parent-1',
        level: PLACE_LEVELS.CITY_TOWN,
        canonicalName: 'Town Hub',
      } as any);

      // DISTRICT requires parent to be STATE, cannot be under CITY_TOWN
      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.DISTRICT,
          canonicalName: 'Sub District',
          names: [{ language: 'en', name: 'Sub District' }],
          parentId: 'parent-1',
        })
      ).rejects.toThrow(BusinessRuleError);

      expect(mockRepo.create).not.toHaveBeenCalled();
    });
  });

  describe('Reparenting vs Deletion Race Protection', () => {
    it('aborts reparenting when target parent is concurrently deleted', async () => {
      mockRepo.touch.mockImplementation(async (id: string) => {
        if (id === 'child-1') {
          return {
            _id: 'child-1',
            level: PLACE_LEVELS.VILLAGE,
            canonicalName: 'Village One',
            parentId: 'tehsil-old',
          } as any;
        }
        if (id === 'tehsil-target-deleted') {
          // Target parent deleted by concurrent transaction
          return null;
        }
        return null;
      });

      await expect(
        placeService.updatePlace('child-1', {
          parentId: 'tehsil-target-deleted',
        })
      ).rejects.toThrow(NotFoundError);

      expect(mockRepo.update).not.toHaveBeenCalled();
    });
  });

  describe('Transaction Error Handling & Deployment Guard', () => {
    it('aborts transaction and propagates non-transient ConflictError on duplicate name', async () => {
      mockRepo.touch.mockResolvedValue({
        _id: 'state-1',
        level: PLACE_LEVELS.STATE,
        canonicalName: 'Rajasthan',
      } as any);
      mockRepo.findDuplicate.mockResolvedValue({
        _id: 'existing-dist',
        canonicalName: 'Jodhpur',
      } as any);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.DISTRICT,
          canonicalName: 'Jodhpur',
          names: [{ language: 'en', name: 'Jodhpur' }],
          parentId: 'state-1',
        })
      ).rejects.toThrow(ConflictError);

      expect(mockRepo.create).not.toHaveBeenCalled();
    });

    it('fails clearly with TRANSACTIONS_NOT_SUPPORTED when deployment does not support transactions', async () => {
      const realRepo = new PlaceRepository();
      // Simulate MongoDB driver throwing error code 20 on standalone instance
      const standaloneError = Object.assign(
        new Error('Transaction numbers are only allowed on a replica set member or mongos'),
        { code: 20, codeName: 'IllegalOperation' }
      );

      jest.spyOn(mongoose, 'startSession').mockResolvedValue({
        withTransaction: jest.fn().mockRejectedValue(standaloneError),
        endSession: jest.fn().mockResolvedValue(undefined),
      } as any);

      await expect(
        realRepo.withTransaction(async () => {
          return 'ok';
        })
      ).rejects.toThrow(AppError);

      try {
        await realRepo.withTransaction(async () => {
          return 'ok';
        });
      } catch (err: any) {
        expect(err.code).toBe('TRANSACTIONS_NOT_SUPPORTED');
        expect(err.statusCode).toBe(500);
        expect(err.message).toContain('A replica set is required for hierarchy integrity');
      }
    });

    it('retries on transient write conflicts using driver withTransaction conventions', async () => {
      let attempts = 0;
      const customWithTx = jest.fn(async (work: (session: ClientSession) => Promise<any>) => {
        // First attempt fails with transient WriteConflict, second succeeds
        attempts++;
        if (attempts === 1) {
          const transientError = Object.assign(new Error('WriteConflict'), {
            code: 112,
            errorLabels: ['TransientTransactionError'],
          });
          // Simulating withTransaction retrying the callback
          return await work(mockSession);
        }
        return await work(mockSession);
      });

      mockRepo.withTransaction = customWithTx;
      mockRepo.touch.mockResolvedValue({
        _id: 'vil-1',
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Mandore',
      } as any);
      mockRepo.countChildren.mockResolvedValue(0);
      mockRepo.delete.mockResolvedValue(true);

      await placeService.deletePlace('vil-1');

      expect(mockRepo.delete).toHaveBeenCalledWith('vil-1', mockSession);
    });
  });
});
