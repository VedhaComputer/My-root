import mongoose from 'mongoose';
import { ClaimService } from '../../../../src/modules/claims/service';
import { ClaimRepository } from '../../../../src/modules/claims/repository';
import { PlaceRepository } from '../../../../src/modules/places/repository';
import { PlaceService } from '../../../../src/modules/places/service';
import { AuditService } from '../../../../src/modules/audit/audit.service';
import {
  CLAIM_CATEGORIES,
  CLAIM_STATUSES,
  PLACE_LEVELS,
  USER_ROLES,
} from '../../../../src/shared/constants';
import {
  NotFoundError,
  AuthorizationError,
  BusinessRuleError,
} from '../../../../src/shared/errors/AppError';
import { PlaceGatewayService } from '../../../../src/modules/places/gateway';

describe('ClaimService Unit Tests', () => {
  let mockClaimRepo: jest.Mocked<ClaimRepository>;
  let mockPlaceRepo: jest.Mocked<PlaceRepository>;
  let mockPlaceService: jest.Mocked<PlaceService>;
  let mockAuditService: jest.Mocked<AuditService>;
  let mockGateway: jest.Mocked<PlaceGatewayService>;
  let service: ClaimService;

  const validCountryId = new mongoose.Types.ObjectId().toString();
  const validStateId = new mongoose.Types.ObjectId().toString();
  const validDistrictId = new mongoose.Types.ObjectId().toString();
  const validUserId = new mongoose.Types.ObjectId().toString();

  beforeEach(() => {
    mockClaimRepo = {
      create: jest.fn(),
      findById: jest.fn(),
      update: jest.fn(),
      list: jest.fn(),
      touch: jest.fn(),
      withTransaction: jest.fn(async (cb) => cb({} as any)),
    } as unknown as jest.Mocked<ClaimRepository>;

    mockPlaceRepo = {
      findById: jest.fn(),
      getAncestors: jest.fn(),
    } as unknown as jest.Mocked<PlaceRepository>;

    mockPlaceService = {
      getPlaceById: jest.fn(),
    } as unknown as jest.Mocked<PlaceService>;

    mockAuditService = {
      writeAuditLog: jest.fn(),
    } as unknown as jest.Mocked<AuditService>;

    mockGateway = {
      isProxyEnabled: jest.fn().mockReturnValue(false),
      executeProxy: jest.fn(),
      mapIncomingPlaceData: jest.fn((data) => data),
    } as unknown as jest.Mocked<PlaceGatewayService>;

    service = new ClaimService(
      mockClaimRepo,
      mockPlaceRepo,
      mockPlaceService,
      mockAuditService,
      undefined,
      undefined,
      mockGateway
    );
  });

  describe('resolveAndValidateLocationHierarchy', () => {
    it('throws NotFoundError if location does not exist', async () => {
      mockPlaceRepo.findById.mockResolvedValue(null);

      await expect(
        service.resolveAndValidateLocationHierarchy(validDistrictId)
      ).rejects.toThrow(NotFoundError);
    });

    it('rejects a place at level COUNTRY directly', async () => {
      mockPlaceRepo.findById.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validCountryId),
        id: validCountryId,
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
      } as any);

      await expect(
        service.resolveAndValidateLocationHierarchy(validCountryId)
      ).rejects.toThrow(BusinessRuleError);
    });

    it('rejects hierarchy if ancestor chain does not resolve to Country and State', async () => {
      mockPlaceRepo.findById.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validDistrictId),
        id: validDistrictId,
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Orphan District',
      } as any);
      mockPlaceRepo.getAncestors.mockResolvedValue([]); // No ancestors

      await expect(
        service.resolveAndValidateLocationHierarchy(validDistrictId)
      ).rejects.toThrow(BusinessRuleError);
    });

    it('resolves valid locationPath from Country down to leaf place', async () => {
      mockPlaceRepo.findById.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validDistrictId),
        id: validDistrictId,
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
      } as any);

      mockPlaceRepo.getAncestors.mockResolvedValue([
        { id: validCountryId, level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
        { id: validStateId, level: PLACE_LEVELS.STATE, canonicalName: 'Rajasthan' },
      ]);

      const result = await service.resolveAndValidateLocationHierarchy(validDistrictId);

      expect(result.locationPath).toHaveLength(3);
      expect(result.locationPath[0].toString()).toBe(validCountryId);
      expect(result.locationPath[1].toString()).toBe(validStateId);
      expect(result.locationPath[2].toString()).toBe(validDistrictId);
    });
  });

  describe('createClaim', () => {
    it('always creates claims in draft status and ignores client status overrides', async () => {
      mockPlaceRepo.findById.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validStateId),
        id: validStateId,
        level: PLACE_LEVELS.STATE,
        canonicalName: 'Rajasthan',
      } as any);
      mockPlaceRepo.getAncestors.mockResolvedValue([
        { id: validCountryId, level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
      ]);

      const claimId = new mongoose.Types.ObjectId().toString();
      mockClaimRepo.create.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(claimId),
        id: claimId,
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      mockClaimRepo.findById.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(claimId),
        id: claimId,
        title: { original: 'Test Claim', language: 'en' },
        body: { original: 'Test body description', language: 'en' },
        category: CLAIM_CATEGORIES.FOLKLORE,
        status: CLAIM_STATUSES.DRAFT,
        locationId: new mongoose.Types.ObjectId(validStateId),
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        submittedAt: new Date(),
        evidenceIds: [],
        tags: [],
      } as any);

      const result = await service.createClaim(
        {
          title: { original: 'Test Claim', language: 'en' },
          body: { original: 'Test body description', language: 'en' },
          category: CLAIM_CATEGORIES.FOLKLORE,
          locationId: validStateId,
          tags: [],
        },
        validUserId
      );

      expect(result.status).toBe(CLAIM_STATUSES.DRAFT);
      expect(mockClaimRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          status: CLAIM_STATUSES.DRAFT,
        })
      );
    });

    it('creates a claim anchored to an external Place ID without throwing BSON error', async () => {
      const externalPlaceId = 'PL_VIL_06_077_00382_060008';
      mockPlaceRepo.findById.mockResolvedValue(null);

      mockGateway.isProxyEnabled.mockReturnValue(true);
      mockGateway.executeProxy.mockResolvedValue({
        status: 200,
        body: {
          data: {
            id: externalPlaceId,
            level: PLACE_LEVELS.VILLAGE,
            canonicalName: 'Mohal Khera',
            parentPath: [
              { id: 'c-ind', level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
              { id: 's-raj', level: PLACE_LEVELS.STATE, canonicalName: 'Rajasthan' },
              { id: 'd-jod', level: PLACE_LEVELS.DISTRICT, canonicalName: 'Jodhpur' },
            ],
          },
        },
      });

      const createdClaim = {
        _id: new mongoose.Types.ObjectId(),
        id: 'clm-ext-1',
        title: { original: 'Village Chronicle', language: 'en' },
        body: { original: 'Historical chronicle of the village community.', language: 'en' },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        status: CLAIM_STATUSES.DRAFT,
        locationId: externalPlaceId,
        locationPath: ['c-ind', 's-raj', 'd-jod', externalPlaceId],
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        submittedAt: new Date(),
        evidenceIds: [],
        tags: [],
        isPublic: false,
      } as any;

      mockClaimRepo.create.mockResolvedValue(createdClaim);
      mockClaimRepo.findById.mockResolvedValue(createdClaim);
      mockPlaceService.getPlaceById.mockResolvedValue({
        id: externalPlaceId,
        canonicalName: 'Mohal Khera',
        level: PLACE_LEVELS.VILLAGE,
      } as any);

      const result = await service.createClaim(
        {
          title: { original: 'Village Chronicle', language: 'en' },
          body: { original: 'Historical chronicle of the village community.', language: 'en' },
          category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
          locationId: externalPlaceId,
          tags: [],
        },
        validUserId
      );

      expect(result.status).toBe(CLAIM_STATUSES.DRAFT);
      expect(mockClaimRepo.create).toHaveBeenCalledWith(
        expect.objectContaining({
          locationId: externalPlaceId,
          locationPath: ['c-ind', 's-raj', 'd-jod', externalPlaceId],
        })
      );
    });
  });

  describe('updateClaim', () => {
    const claimId = new mongoose.Types.ObjectId().toString();

    it('throws AuthorizationError when user is not the claim submitter', async () => {
      mockClaimRepo.findById.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(claimId),
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      const otherUserId = new mongoose.Types.ObjectId().toString();
      await expect(
        service.updateClaim(claimId, { title: { original: 'New', language: 'en' } }, otherUserId)
      ).rejects.toThrow(AuthorizationError);
    });

    it('throws BusinessRuleError when claim is not in draft status (content is immutable)', async () => {
      mockClaimRepo.findById.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(claimId),
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      await expect(
        service.updateClaim(claimId, { title: { original: 'New', language: 'en' } }, validUserId)
      ).rejects.toThrow(BusinessRuleError);
    });
  });

  describe('Privacy & PII Protection in getClaimById', () => {
    it('never exposes submitter email or sensitive identity information', async () => {
      const claimId = new mongoose.Types.ObjectId().toString();
      mockClaimRepo.findById.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(claimId),
        id: claimId,
        title: { original: 'Public Story', language: 'en' },
        body: { original: 'Public body description', language: 'en' },
        category: CLAIM_CATEGORIES.FOLKLORE,
        status: CLAIM_STATUSES.VERIFIED,
        locationId: new mongoose.Types.ObjectId(validStateId),
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        submittedAt: new Date(),
        evidenceIds: [],
        tags: [],
      } as any);

      mockPlaceService.getPlaceById.mockResolvedValue({
        id: validStateId,
        canonicalName: 'Rajasthan',
        level: PLACE_LEVELS.STATE,
      } as any);

      const result = await service.getClaimById(claimId);

      expect((result as any).submittedBy).toBeUndefined();
      expect((result as any).email).toBeUndefined();
      expect(result.evidenceCount).toBe(0);
      expect(result.latestReview).toBeNull();
    });
  });

  describe('getReviewQueue', () => {
    it('throws AuthorizationError when called by non-reviewer (CONTRIBUTOR)', async () => {
      await expect(
        service.getReviewQueue({ page: 1, limit: 20 }, validUserId, USER_ROLES.CONTRIBUTOR)
      ).rejects.toThrow(AuthorizationError);
    });

    it('returns submitted and under_review claims for REVIEWER role', async () => {
      const mockClaim = {
        _id: new mongoose.Types.ObjectId(),
        title: { original: 'Pending Heritage Story', language: 'en' },
        body: { original: 'A detailed story about the village heritage.', language: 'en' },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        status: CLAIM_STATUSES.SUBMITTED,
        locationId: 'PL_VIL_06_077_00382_060008',
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        submittedAt: new Date(),
        evidenceIds: [],
        tags: [],
      } as any;

      mockClaimRepo.list.mockResolvedValue({
        claims: [mockClaim],
        total: 1,
      });

      const result = await service.getReviewQueue(
        { page: 1, limit: 20 },
        'reviewer-id-123',
        USER_ROLES.REVIEWER
      );

      expect(result.data).toHaveLength(1);
      expect(result.data[0].status).toBe(CLAIM_STATUSES.SUBMITTED);
      expect(result.data[0].locationId).toBe('PL_VIL_06_077_00382_060008');
      expect(mockClaimRepo.list).toHaveBeenCalledWith(
        expect.objectContaining({
          publicOnly: false,
        }),
        expect.anything()
      );
    });
  });

  describe('listClaims - User-Scoped Self Query Isolation', () => {
    it('sets publicOnly to false when a user queries their own submissions', async () => {
      mockClaimRepo.list.mockResolvedValue({
        claims: [],
        total: 0,
      });

      await service.listClaims(
        { page: 1, limit: 20, submittedBy: validUserId },
        validUserId,
        USER_ROLES.CONTRIBUTOR
      );

      expect(mockClaimRepo.list).toHaveBeenCalledWith(
        expect.objectContaining({
          submittedBy: validUserId,
          publicOnly: false,
        }),
        expect.anything()
      );
    });
  });
});
