import mongoose from 'mongoose';
import { PlaceProgressService } from '../../../../src/modules/places/placeProgress.service';
import { ClaimModel } from '../../../../src/modules/claims/claim.model';
import { PlaceAttributeModel } from '../../../../src/modules/places/placeAttribute.model';
import { EvidenceModel } from '../../../../src/modules/evidence/evidence.model';
import { ValidationError } from '../../../../src/shared/errors/AppError';

describe('PlaceProgressService - External Place ID Handling', () => {
  let service: PlaceProgressService;

  beforeEach(() => {
    service = new PlaceProgressService();
    jest.clearAllMocks();
    jest.spyOn(EvidenceModel, 'countDocuments').mockResolvedValue(0);
    jest.spyOn(PlaceAttributeModel, 'find').mockReturnValue({
      lean: jest.fn().mockResolvedValue([]),
    } as any);
  });

  it('rejects invalid place ID format with ValidationError', async () => {
    await expect(service.calculatePlaceProgress('invalid!format#')).rejects.toThrow(ValidationError);
    await expect(service.calculatePlaceProgress('a')).rejects.toThrow(ValidationError);
    await expect(service.calculatePlaceProgress('place with spaces')).rejects.toThrow(ValidationError);
  });

  it('handles external place ID PL_VIL_06_077_00382_060008 without BSON error and returns baseline metrics', async () => {
    const externalId = 'PL_VIL_06_077_00382_060008';

    const mockLean = jest.fn().mockResolvedValue([]);
    jest.spyOn(ClaimModel, 'find').mockReturnValue({ lean: mockLean } as any);

    const progress = await service.calculatePlaceProgress(externalId);

    expect(progress).toBeDefined();
    expect(progress.placeId).toBe(externalId);
    expect(progress.totalContributions).toBe(0);
    expect(progress.qualityCoverageScore).toBe(0);
    expect(ClaimModel.find).toHaveBeenCalledWith(
      expect.objectContaining({
        locationId: externalId,
      })
    );
  });

  it('handles local MongoDB ObjectId place ID correctly', async () => {
    const localId = new mongoose.Types.ObjectId().toString();

    const mockLean = jest.fn().mockResolvedValue([]);
    jest.spyOn(ClaimModel, 'find').mockReturnValue({ lean: mockLean } as any);

    const progress = await service.calculatePlaceProgress(localId);

    expect(progress).toBeDefined();
    expect(progress.placeId).toBe(localId);
    expect(progress.totalContributions).toBe(0);
    expect(progress.qualityCoverageScore).toBe(0);
    expect(ClaimModel.find).toHaveBeenCalledWith(
      expect.objectContaining({
        locationId: new mongoose.Types.ObjectId(localId),
      })
    );
  });
});
