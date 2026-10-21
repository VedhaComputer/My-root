import { PlaceService } from '../../../../src/modules/places/service';
import { PlaceRepository } from '../../../../src/modules/places/repository';
import { PLACE_LEVELS } from '../../../../src/shared/constants';
import { BusinessRuleError } from '../../../../src/shared/errors/AppError';

describe('TEHSIL Geographic Level Hierarchy Validation', () => {
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

  describe('TEHSIL Creation and Parent Validation', () => {
    it('allows creating TEHSIL under DISTRICT', async () => {
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'dist-1') {
          return {
            _id: 'dist-1',
            id: 'dist-1',
            level: PLACE_LEVELS.DISTRICT,
            canonicalName: 'Jodhpur',
          } as any;
        }
        if (id === 'tehsil-1') {
          return {
            _id: 'tehsil-1',
            id: 'tehsil-1',
            level: PLACE_LEVELS.TEHSIL,
            canonicalName: 'Luni',
            parentId: 'dist-1',
            names: [{ language: 'en', name: 'Luni' }],
          } as any;
        }
        return null;
      });

      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.create.mockResolvedValue({
        _id: 'tehsil-1',
        id: 'tehsil-1',
        level: PLACE_LEVELS.TEHSIL,
        canonicalName: 'Luni',
        parentId: 'dist-1',
        names: [{ language: 'en', name: 'Luni' }],
      } as any);
      mockRepo.getAncestors.mockResolvedValue([
        { id: 'c-1', level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
        { id: 's-1', level: PLACE_LEVELS.STATE, canonicalName: 'Rajasthan' },
        { id: 'dist-1', level: PLACE_LEVELS.DISTRICT, canonicalName: 'Jodhpur' },
      ]);

      const result = await placeService.createPlace({
        level: PLACE_LEVELS.TEHSIL,
        canonicalName: 'Luni',
        names: [{ language: 'en', name: 'Luni' }],
        parentId: 'dist-1',
      });

      expect(result.id).toBe('tehsil-1');
      expect(result.level).toBe(PLACE_LEVELS.TEHSIL);
      expect(mockRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          level: PLACE_LEVELS.TEHSIL,
          parentId: 'dist-1',
        }),
        expect.anything()
      );
    });

    it('rejects TEHSIL creation when parentId is null (requires DISTRICT)', async () => {
      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.TEHSIL,
          canonicalName: 'Orphan Tehsil',
          names: [{ language: 'en', name: 'Orphan Tehsil' }],
          parentId: null,
        })
      ).rejects.toThrow(BusinessRuleError);
    });

    it('rejects TEHSIL creation under STATE', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'state-1',
        id: 'state-1',
        level: PLACE_LEVELS.STATE,
        canonicalName: 'Rajasthan',
      } as any);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.TEHSIL,
          canonicalName: 'Invalid Tehsil',
          names: [{ language: 'en', name: 'Invalid Tehsil' }],
          parentId: 'state-1',
        })
      ).rejects.toThrow(BusinessRuleError);
    });

    it('rejects TEHSIL creation under another TEHSIL (nested tehsils prohibited)', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'tehsil-parent',
        id: 'tehsil-parent',
        level: PLACE_LEVELS.TEHSIL,
        canonicalName: 'Parent Tehsil',
      } as any);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.TEHSIL,
          canonicalName: 'Sub Tehsil',
          names: [{ language: 'en', name: 'Sub Tehsil' }],
          parentId: 'tehsil-parent',
        })
      ).rejects.toThrow(BusinessRuleError);
    });
  });

  describe('CITY_TOWN Creation under TEHSIL & Rejection of Old Mappings', () => {
    it('allows creating CITY_TOWN under TEHSIL', async () => {
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'tehsil-1') {
          return {
            _id: 'tehsil-1',
            id: 'tehsil-1',
            level: PLACE_LEVELS.TEHSIL,
            canonicalName: 'Luni',
          } as any;
        }
        if (id === 'city-1') {
          return {
            _id: 'city-1',
            id: 'city-1',
            level: PLACE_LEVELS.CITY_TOWN,
            canonicalName: 'Luni Town',
            parentId: 'tehsil-1',
            names: [{ language: 'en', name: 'Luni Town' }],
          } as any;
        }
        return null;
      });

      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.create.mockResolvedValue({
        _id: 'city-1',
        id: 'city-1',
        level: PLACE_LEVELS.CITY_TOWN,
        canonicalName: 'Luni Town',
        parentId: 'tehsil-1',
        names: [{ language: 'en', name: 'Luni Town' }],
      } as any);
      mockRepo.getAncestors.mockResolvedValue([
        { id: 'c-1', level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
        { id: 's-1', level: PLACE_LEVELS.STATE, canonicalName: 'Rajasthan' },
        { id: 'dist-1', level: PLACE_LEVELS.DISTRICT, canonicalName: 'Jodhpur' },
        { id: 'tehsil-1', level: PLACE_LEVELS.TEHSIL, canonicalName: 'Luni' },
      ]);

      const result = await placeService.createPlace({
        level: PLACE_LEVELS.CITY_TOWN,
        canonicalName: 'Luni Town',
        names: [{ language: 'en', name: 'Luni Town' }],
        parentId: 'tehsil-1',
      });

      expect(result.id).toBe('city-1');
      expect(result.level).toBe(PLACE_LEVELS.CITY_TOWN);
    });

    it('rejects CITY_TOWN creation directly under DISTRICT (old direct-parent mapping rejected)', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'dist-1',
        id: 'dist-1',
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
      } as any);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.CITY_TOWN,
          canonicalName: 'Jodhpur City',
          names: [{ language: 'en', name: 'Jodhpur City' }],
          parentId: 'dist-1',
        })
      ).rejects.toThrow(BusinessRuleError);
    });
  });

  describe('VILLAGE Creation under TEHSIL & Rejection of Old Mappings', () => {
    it('allows creating VILLAGE under TEHSIL', async () => {
      mockRepo.findById.mockImplementation(async (id: string) => {
        if (id === 'tehsil-1') {
          return {
            _id: 'tehsil-1',
            id: 'tehsil-1',
            level: PLACE_LEVELS.TEHSIL,
            canonicalName: 'Luni',
          } as any;
        }
        if (id === 'vil-1') {
          return {
            _id: 'vil-1',
            id: 'vil-1',
            level: PLACE_LEVELS.VILLAGE,
            canonicalName: 'Shikarpura',
            parentId: 'tehsil-1',
            names: [{ language: 'en', name: 'Shikarpura' }],
          } as any;
        }
        return null;
      });

      mockRepo.findDuplicate.mockResolvedValue(null);
      mockRepo.create.mockResolvedValue({
        _id: 'vil-1',
        id: 'vil-1',
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Shikarpura',
        parentId: 'tehsil-1',
        names: [{ language: 'en', name: 'Shikarpura' }],
      } as any);
      mockRepo.getAncestors.mockResolvedValue([
        { id: 'c-1', level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
        { id: 's-1', level: PLACE_LEVELS.STATE, canonicalName: 'Rajasthan' },
        { id: 'dist-1', level: PLACE_LEVELS.DISTRICT, canonicalName: 'Jodhpur' },
        { id: 'tehsil-1', level: PLACE_LEVELS.TEHSIL, canonicalName: 'Luni' },
      ]);

      const result = await placeService.createPlace({
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Shikarpura',
        names: [{ language: 'en', name: 'Shikarpura' }],
        parentId: 'tehsil-1',
      });

      expect(result.id).toBe('vil-1');
      expect(result.level).toBe(PLACE_LEVELS.VILLAGE);
    });

    it('rejects VILLAGE creation directly under DISTRICT (old direct-parent mapping rejected)', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'dist-1',
        id: 'dist-1',
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
      } as any);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.VILLAGE,
          canonicalName: 'Mandore Village',
          names: [{ language: 'en', name: 'Mandore Village' }],
          parentId: 'dist-1',
        })
      ).rejects.toThrow(BusinessRuleError);
    });

    it('rejects VILLAGE nested under CITY_TOWN (nesting under city/town prohibited)', async () => {
      mockRepo.findById.mockResolvedValue({
        _id: 'city-1',
        id: 'city-1',
        level: PLACE_LEVELS.CITY_TOWN,
        canonicalName: 'Jodhpur City',
      } as any);

      await expect(
        placeService.createPlace({
          level: PLACE_LEVELS.VILLAGE,
          canonicalName: 'Suburban Village',
          names: [{ language: 'en', name: 'Suburban Village' }],
          parentId: 'city-1',
        })
      ).rejects.toThrow(BusinessRuleError);
    });
  });
});
