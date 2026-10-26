import { PlaceService } from '../../../../src/modules/places/service';
import { PlaceRepository } from '../../../../src/modules/places/repository';
import { PLACE_LEVELS } from '../../../../src/shared/constants';
import {
  NotFoundError,
  ConflictError,
  BusinessRuleError,
} from '../../../../src/shared/errors/AppError';

describe('PlaceService (Unit Tests)', () => {
  let mockRepo: jest.Mocked<PlaceRepository>;
  let placeService: PlaceService;

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
      touch: jest.fn(async (id: string, session?: any) => mockRepo.findById(id, session)),
      withTransaction: jest.fn(async (work: (session: any) => Promise<any>) => work({} as any)),
    } as unknown as jest.Mocked<PlaceRepository>;

    placeService = new PlaceService(mockRepo);
  });

  describe('createPlace - Hierarchy Validation', () => {
    it('creates a COUNTRY place when parentId is null', async () => {
      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.create.mockResolvedValue({
        _id: 'c-1',
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
        names: [{ language: 'en', name: 'India' }, { language: 'hi', name: 'भारत' }],
        parentId: null,
      } as any);
      mockRepo.findById.mockResolvedValue({
        _id: 'c-1',
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
        names: [{ language: 'en', name: 'India' }, { language: 'hi', name: 'भारत' }],
        parentId: null,
      } as any);
      mockRepo.getAncestors.mockResolvedValue([]);

      const result = await placeService.createPlace({
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
        names: [{ language: 'en', name: 'India' }, { language: 'hi', name: 'भारत' }],
        parentId: null,
      });

      expect(result.id).toBe('c-1');
      expect(result.level).toBe(PLACE_LEVELS.COUNTRY);
      expect(mockRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          level: PLACE_LEVELS.COUNTRY,
          canonicalName: 'India',
          parentId: null,
        }),
        expect.anything()
      );
    });

    it('throws BusinessRuleError when creating a COUNTRY with a parentId', async () => {
      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.COUNTRY,
          canonicalName: 'Invalid Country',
          names: [{ language: 'en', name: 'Invalid Country' }],
          parentId: '507f1f77bcf86cd799439011',
        })
      ).rejects.toThrow(BusinessRuleError);

      expect(mockRepo.create).not.toHaveBeenCalled();
    });

    it('throws BusinessRuleError when creating a non-country place without parentId', async () => {
      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.STATE,
          canonicalName: 'Rajasthan',
          names: [{ language: 'en', name: 'Rajasthan' }],
          parentId: null,
        })
      ).rejects.toThrow(BusinessRuleError);
    });

    it('throws NotFoundError when parent place does not exist', async () => {
      mockRepo.findById.mockResolvedValue(null);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.STATE,
          canonicalName: 'Rajasthan',
          names: [{ language: 'en', name: 'Rajasthan' }],
          parentId: '507f1f77bcf86cd799439011',
        })
      ).rejects.toThrow(NotFoundError);
    });

    it('throws BusinessRuleError when parent place has invalid level for STATE', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'dist-1',
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
      } as any);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.STATE,
          canonicalName: 'Rajasthan',
          names: [{ language: 'en', name: 'Rajasthan' }],
          parentId: 'dist-1',
        })
      ).rejects.toThrow(BusinessRuleError);
    });

    it('allows DISTRICT under STATE', async () => {
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'state-1') {
          return {
            _id: 'state-1',
            level: PLACE_LEVELS.STATE,
            canonicalName: 'Rajasthan',
            names: [{ language: 'en', name: 'Rajasthan' }],
          } as any;
        }
        if (id === 'dist-1') {
          return {
            _id: 'dist-1',
            level: PLACE_LEVELS.DISTRICT,
            canonicalName: 'Jodhpur',
            names: [{ language: 'en', name: 'Jodhpur' }],
            parentId: 'state-1',
          } as any;
        }
        return null;
      });
      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.create.mockResolvedValue({
        _id: 'dist-1',
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
        names: [{ language: 'en', name: 'Jodhpur' }],
        parentId: 'state-1',
      } as any);
      mockRepo.getAncestors.mockResolvedValue([
        { id: 'c-1', level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
        { id: 'state-1', level: PLACE_LEVELS.STATE, canonicalName: 'Rajasthan' },
      ]);

      const result = await placeService.createPlace({
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
        names: [{ language: 'en', name: 'Jodhpur' }],
        parentId: 'state-1',
      });

      expect(result.id).toBe('dist-1');
      expect(result.parentPath).toHaveLength(2);
    });

    it('allows VILLAGE under TEHSIL', async () => {
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'tehsil-1') {
          return {
            _id: 'tehsil-1',
            level: PLACE_LEVELS.TEHSIL,
            canonicalName: 'Jodhpur Tehsil',
            names: [{ language: 'en', name: 'Jodhpur Tehsil' }],
          } as any;
        }
        if (id === 'vil-1') {
          return {
            _id: 'vil-1',
            level: PLACE_LEVELS.VILLAGE,
            canonicalName: 'Mandore',
            names: [{ language: 'en', name: 'Mandore' }],
            parentId: 'tehsil-1',
          } as any;
        }
        return null;
      });
      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.create.mockResolvedValue({
        _id: 'vil-1',
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Mandore',
        names: [{ language: 'en', name: 'Mandore' }],
        parentId: 'tehsil-1',
      } as any);
      mockRepo.getAncestors.mockResolvedValue([]);

      const result = await placeService.createPlace({
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Mandore',
        names: [{ language: 'en', name: 'Mandore' }],
        parentId: 'tehsil-1',
      });

      expect(result.id).toBe('vil-1');
    });

    it('throws ConflictError on duplicate canonical name under same parent and level', async () => {
      mockRepo.findDuplicate.mockResolvedValue({
        _id: 'existing-1',
        canonicalName: 'India',
        level: PLACE_LEVELS.COUNTRY,
      } as any);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.COUNTRY,
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
          parentId: null,
        })
      ).rejects.toThrow(ConflictError);

      expect(mockRepo.create).not.toHaveBeenCalled();
    });
  });

  describe('updatePlace - Cycle Detection and Self-Parenting', () => {
    it('throws BusinessRuleError when place is set as its own parent', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'place-1',
        level: PLACE_LEVELS.STATE,
        canonicalName: 'Rajasthan',
      } as any);

      await expect(
        placeService.updatePlace('place-1', {
          parentId: 'place-1',
        })
      ).rejects.toThrow(BusinessRuleError);
    });

    it('throws BusinessRuleError when setting parent creates a cycle', async () => {
      // Trying to set parent of place-A to place-C, but place-C's ancestor is place-A
      mockRepo.findById
        .mockImplementation(async (id: string) => {
          if (id === 'place-a') {
            return { _id: 'place-a', level: PLACE_LEVELS.STATE, canonicalName: 'State A' } as any;
          }
          if (id === 'place-c') {
            return { _id: 'place-c', level: PLACE_LEVELS.DISTRICT, parentId: 'place-b' } as any;
          }
          if (id === 'place-b') {
            return { _id: 'place-b', level: PLACE_LEVELS.DISTRICT, parentId: 'place-a' } as any;
          }
          return null;
        });

      await expect(
        placeService.updatePlace('place-a', {
          parentId: 'place-c',
        })
      ).rejects.toThrow(BusinessRuleError);
    });

    it('throws BusinessRuleError when changing place level invalidates existing children', async () => {
      // Place is a STATE under COUNTRY, with an existing DISTRICT child
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'state-1') {
          return {
            _id: 'state-1',
            level: PLACE_LEVELS.STATE,
            canonicalName: 'Rajasthan',
            parentId: 'c-1',
          } as any;
        }
        if (id === 'c-1') {
          return {
            _id: 'c-1',
            level: PLACE_LEVELS.COUNTRY,
            canonicalName: 'India',
          } as any;
        }
        return null;
      });

      // Child is DISTRICT which requires parent to be STATE
      mockRepo.findChildren.mockResolvedValue([
        {
          _id: 'dist-1',
          level: PLACE_LEVELS.DISTRICT,
          canonicalName: 'Jodhpur',
        } as any,
      ]);

      // Attempting to change STATE to VILLAGE (not allowed for DISTRICT)
      await expect(
        placeService.updatePlace('state-1', {
          level: PLACE_LEVELS.VILLAGE,
        })
      ).rejects.toThrow(BusinessRuleError);

      expect(mockRepo.update).not.toHaveBeenCalled();
    });

    it('disallows changing place level when existing children are incompatible with new level (e.g. VILLAGE child under CITY_TOWN)', async () => {
      // Place is under TEHSIL (tehsil-1). It attempts to change from VILLAGE to CITY_TOWN.
      // Its child is VILLAGE, but VILLAGE cannot be nested under CITY_TOWN in strict hierarchy.
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'place-1') {
          return {
            _id: 'place-1',
            level: PLACE_LEVELS.VILLAGE,
            canonicalName: 'Urbanizing Village',
            parentId: 'tehsil-1',
            names: [{ language: 'en', name: 'Urbanizing Village' }],
          } as any;
        }
        if (id === 'tehsil-1') {
          return {
            _id: 'tehsil-1',
            level: PLACE_LEVELS.TEHSIL,
            canonicalName: 'Jodhpur Tehsil',
          } as any;
        }
        return null;
      });

      // Child is VILLAGE which requires parent to be TEHSIL, not CITY_TOWN
      mockRepo.findChildren.mockResolvedValue([
        {
          _id: 'vil-child',
          level: PLACE_LEVELS.VILLAGE,
          canonicalName: 'Hamlet',
        } as any,
      ]);

      await expect(
        placeService.updatePlace('place-1', {
          level: PLACE_LEVELS.CITY_TOWN,
        })
      ).rejects.toThrow(BusinessRuleError);

      expect(mockRepo.update).not.toHaveBeenCalled();
    });

    it('allows changing place level when place has no children', async () => {
      // Leaf place under TEHSIL (tehsil-1) changing from VILLAGE to CITY_TOWN
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'leaf-1') {
          return {
            _id: 'leaf-1',
            level: PLACE_LEVELS.VILLAGE,
            canonicalName: 'Growing Town',
            parentId: 'tehsil-1',
            names: [{ language: 'en', name: 'Growing Town' }],
          } as any;
        }
        if (id === 'tehsil-1') {
          return {
            _id: 'tehsil-1',
            level: PLACE_LEVELS.TEHSIL,
            canonicalName: 'Jodhpur Tehsil',
          } as any;
        }
        return null;
      });

      mockRepo.findChildren.mockResolvedValue([]);
      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.update.mockResolvedValue({} as any);
      mockRepo.getAncestors.mockResolvedValue([]);

      await placeService.updatePlace('leaf-1', {
        level: PLACE_LEVELS.CITY_TOWN,
      });

      expect(mockRepo.update).toHaveBeenCalledWith(
        'leaf-1',
        expect.objectContaining({ level: PLACE_LEVELS.CITY_TOWN }),
        expect.anything()
      );
    });

    it('allows ordinary name and metadata updates without child-level check when level is unchanged', async () => {
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'state-1') {
          return {
            _id: 'state-1',
            level: PLACE_LEVELS.STATE,
            canonicalName: 'Rajasthan',
            parentId: 'c-1',
            names: [{ language: 'en', name: 'Rajasthan' }],
          } as any;
        }
        if (id === 'c-1') {
          return {
            _id: 'c-1',
            level: PLACE_LEVELS.COUNTRY,
            canonicalName: 'India',
          } as any;
        }
        return null;
      });

      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.update.mockResolvedValue({} as any);
      mockRepo.getAncestors.mockResolvedValue([]);

      await placeService.updatePlace('state-1', {
        canonicalName: 'Updated Rajasthan',
      });

      expect(mockRepo.findChildren).not.toHaveBeenCalled();
      expect(mockRepo.update).toHaveBeenCalledWith(
        'state-1',
        expect.objectContaining({ canonicalName: 'Updated Rajasthan' }),
        expect.anything()
      );
    });
  });

  describe('deletePlace - Safe Deletion', () => {
    it('throws BusinessRuleError when trying to delete place with sub-places', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'state-1',
        level: PLACE_LEVELS.STATE,
        canonicalName: 'Rajasthan',
      } as any);
      mockRepo.countChildren.mockResolvedValue(5);

      await expect(placeService.deletePlace('state-1')).rejects.toThrow(BusinessRuleError);
      expect(mockRepo.delete).not.toHaveBeenCalled();
    });

    it('successfully deletes a leaf place with 0 children', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'vil-1',
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Mandore',
      } as any);
      mockRepo.countChildren.mockResolvedValue(0);
      mockRepo.delete.mockResolvedValue(true);

      await placeService.deletePlace('vil-1');
      expect(mockRepo.delete).toHaveBeenCalledWith('vil-1', expect.anything());
    });

    it('throws NotFoundError when deleting non-existent place', async () => {
      mockRepo.findById.mockResolvedValue(null);

      await expect(placeService.deletePlace('nonexistent')).rejects.toThrow(NotFoundError);
    });
  });

  describe('listPlaces and getPlaceById', () => {
    it('returns places and pagination', async () => {
      mockRepo.list.mockResolvedValue({
        places: [{ _id: 'p1', canonicalName: 'India' } as any],
        total: 1,
      });

      const result = await placeService.listPlaces({ page: '1', limit: '10' });
      expect(result.data).toHaveLength(1);
      expect(result.pagination.total).toBe(1);
      expect(result.pagination.pages).toBe(1);
    });

    it('forwards search, level, parentId, and pagination parameters to repository', async () => {
      mockRepo.list.mockResolvedValue({
        places: [
          { _id: 'p-narwana', canonicalName: 'Narwana', level: PLACE_LEVELS.CITY_TOWN } as any,
        ],
        total: 1,
      });

      const result = await placeService.listPlaces({
        search: 'Narwana',
        level: PLACE_LEVELS.CITY_TOWN,
        parentId: 'tehsil-jind',
        page: 1,
        limit: 20,
      });

      expect(mockRepo.list).toHaveBeenCalledWith(
        {
          search: 'Narwana',
          level: PLACE_LEVELS.CITY_TOWN,
          parentId: 'tehsil-jind',
        },
        { page: 1, limit: 20 }
      );
      expect(result.data).toHaveLength(1);
      expect(result.pagination.total).toBe(1);
    });

    it('throws NotFoundError when getting non-existent place', async () => {
      mockRepo.findById.mockResolvedValue(null);
      await expect(placeService.getPlaceById('p-none')).rejects.toThrow(NotFoundError);
    });
  });
});
