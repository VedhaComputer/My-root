import mongoose, { ClientSession } from 'mongoose';
import { ClaimService } from '../../../../src/modules/claims/service';
import { ClaimRepository } from '../../../../src/modules/claims/repository';
import { PlaceRepository } from '../../../../src/modules/places/repository';
import { PlaceService } from '../../../../src/modules/places/service';
import { AuditService } from '../../../../src/modules/audit/audit.service';
import {
  CLAIM_STATUSES,
  USER_ROLES,
} from '../../../../src/shared/constants';
import {
  NotFoundError,
  AuthorizationError,
  BusinessRuleError,
} from '../../../../src/shared/errors/AppError';

describe('Claims Atomic Audit & Transaction Lifecycle Tests', () => {
  let mockClaimRepo: jest.Mocked<ClaimRepository>;
  let mockPlaceRepo: jest.Mocked<PlaceRepository>;
  let mockPlaceService: jest.Mocked<PlaceService>;
  let mockAuditService: jest.Mocked<AuditService>;
  let service: ClaimService;

  const mockSession = { id: 'mock-session-claim-1' } as unknown as ClientSession;
  const validClaimId = new mongoose.Types.ObjectId().toString();
  const validUserId = new mongoose.Types.ObjectId().toString();
  const otherUserId = new mongoose.Types.ObjectId().toString();

  beforeEach(() => {
    mockClaimRepo = {
      create: jest.fn(),
      findById: jest.fn(),
      update: jest.fn(),
      list: jest.fn(),
      touch: jest.fn(),
      withTransaction: jest.fn(async (work: (session: ClientSession) => Promise<any>) => {
        return await work(mockSession);
      }),
    } as unknown as jest.Mocked<ClaimRepository>;

    mockPlaceRepo = {} as unknown as jest.Mocked<PlaceRepository>;
    mockPlaceService = {} as unknown as jest.Mocked<PlaceService>;

    mockAuditService = {
      writeAuditLog: jest.fn().mockResolvedValue({} as any),
    } as unknown as jest.Mocked<AuditService>;

    service = new ClaimService(
      mockClaimRepo,
      mockPlaceRepo,
      mockPlaceService,
      mockAuditService
    );
  });

  describe('submitClaim', () => {
    it('executes in a transaction, updates status to submitted, and writes audit log with session', async () => {
      mockClaimRepo.touch.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validClaimId),
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      const result = await service.submitClaim(validClaimId, validUserId, '127.0.0.1');

      expect(result.status).toBe(CLAIM_STATUSES.SUBMITTED);
      expect(mockClaimRepo.withTransaction).toHaveBeenCalledTimes(1);
      expect(mockClaimRepo.touch).toHaveBeenCalledWith(validClaimId, mockSession);
      expect(mockClaimRepo.update).toHaveBeenCalledWith(
        validClaimId,
        expect.objectContaining({ status: CLAIM_STATUSES.SUBMITTED }),
        mockSession
      );
      expect(mockAuditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'claim',
          action: 'claim.submitted',
          before: { status: CLAIM_STATUSES.DRAFT },
          after: { status: CLAIM_STATUSES.SUBMITTED },
          ipAddress: '127.0.0.1',
        }),
        mockSession
      );
    });

    it('aborts transaction when audit log write fails (atomic rollback guarantee)', async () => {
      mockClaimRepo.touch.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validClaimId),
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      const auditError = new Error('Database disk full or audit failure');
      mockAuditService.writeAuditLog.mockRejectedValue(auditError);

      await expect(
        service.submitClaim(validClaimId, validUserId)
      ).rejects.toThrow(auditError);
    });

    it('rejects submission if user is not the claim submitter', async () => {
      mockClaimRepo.touch.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validClaimId),
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      await expect(
        service.submitClaim(validClaimId, otherUserId)
      ).rejects.toThrow(AuthorizationError);

      expect(mockClaimRepo.update).not.toHaveBeenCalled();
      expect(mockAuditService.writeAuditLog).not.toHaveBeenCalled();
    });

    it('rejects submission if claim is not in draft status (concurrent or duplicate submit prevention)', async () => {
      mockClaimRepo.touch.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validClaimId),
        submittedBy: new mongoose.Types.ObjectId(validUserId),
        status: CLAIM_STATUSES.SUBMITTED, // Already submitted
      } as any);

      await expect(
        service.submitClaim(validClaimId, validUserId)
      ).rejects.toThrow(BusinessRuleError);

      expect(mockClaimRepo.update).not.toHaveBeenCalled();
      expect(mockAuditService.writeAuditLog).not.toHaveBeenCalled();
    });
  });

  describe('archiveClaim', () => {
    it('rejects archive attempt by a non-moderator (CONTRIBUTOR role)', async () => {
      await expect(
        service.archiveClaim(validClaimId, validUserId, USER_ROLES.CONTRIBUTOR)
      ).rejects.toThrow(AuthorizationError);

      expect(mockClaimRepo.withTransaction).not.toHaveBeenCalled();
    });

    it('archives claim and writes audit log in the same transaction session when called by MODERATOR', async () => {
      mockClaimRepo.touch.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validClaimId),
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const result = await service.archiveClaim(
        validClaimId,
        validUserId,
        USER_ROLES.MODERATOR,
        '10.0.0.1'
      );

      expect(result.message).toBe('Claim archived');
      expect(mockClaimRepo.withTransaction).toHaveBeenCalledTimes(1);
      expect(mockClaimRepo.touch).toHaveBeenCalledWith(validClaimId, mockSession);
      expect(mockClaimRepo.update).toHaveBeenCalledWith(
        validClaimId,
        { status: CLAIM_STATUSES.ARCHIVED },
        mockSession
      );
      expect(mockAuditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'claim',
          action: 'claim.archived',
          before: { status: CLAIM_STATUSES.SUBMITTED },
          after: { status: CLAIM_STATUSES.ARCHIVED },
          ipAddress: '10.0.0.1',
        }),
        mockSession
      );
    });

    it('aborts archive transaction if audit write fails', async () => {
      mockClaimRepo.touch.mockResolvedValue({
        _id: new mongoose.Types.ObjectId(validClaimId),
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const auditError = new Error('Audit collection write conflict');
      mockAuditService.writeAuditLog.mockRejectedValue(auditError);

      await expect(
        service.archiveClaim(validClaimId, validUserId, USER_ROLES.MODERATOR)
      ).rejects.toThrow(auditError);
    });
  });
});
