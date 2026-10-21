import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { createApp } from '../../src/app';
import { evidenceRepository } from '../../src/modules/evidence/repository';
import { claimRepository } from '../../src/modules/claims/repository';
import { auditService } from '../../src/modules/audit/audit.service';
import { env } from '../../src/config/env';
import { USER_ROLES, UserRole } from '../../src/shared/constants';

const app = createApp();

function generateTestToken(role: UserRole, userId = '507f1f77bcf86cd799439011', tokenVersion = 1): string {
  return jwt.sign(
    {
      userId,
      email: 'testuser@example.com',
      role,
      displayName: 'Test User',
      tokenVersion,
    },
    env.JWT_ACCESS_SECRET,
    {
      algorithm: 'HS256',
      issuer: env.JWT_ISSUER,
      audience: env.JWT_AUDIENCE,
      expiresIn: '15m',
    }
  );
}

describe('Evidence Routes (Integration Tests)', () => {
  let originalFallback: string | undefined;

  beforeAll(() => {
    originalFallback = process.env.JWT_ALLOW_HS256_FALLBACK;
    process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
  });

  afterAll(() => {
    if (originalFallback === undefined) {
      delete process.env.JWT_ALLOW_HS256_FALLBACK;
    } else {
      process.env.JWT_ALLOW_HS256_FALLBACK = originalFallback;
    }
  });

  const testContributorId = new mongoose.Types.ObjectId().toString();
  const testReviewerId = new mongoose.Types.ObjectId().toString();
  const testClaimId = new mongoose.Types.ObjectId().toString();
  const testEvidenceId = new mongoose.Types.ObjectId().toString();

  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(claimRepository, 'withTransaction').mockImplementation(async (cb) => cb({} as any));
    jest.spyOn(claimRepository, 'touch').mockImplementation(async (id, s) => claimRepository.findById(id, s));
    jest.spyOn(auditService, 'writeAuditLog').mockResolvedValue({} as any);
  });

  describe('POST /api/v1/evidence', () => {
    const validEvidencePayload = {
      claimId: testClaimId,
      sourceType: 'DOCUMENT',
      title: 'Land Settlement Record 1923',
      description: 'Historical land survey archive page 42 confirming village boundaries.',
      documentRef: 'ARCH-1923-DOC-42',
      languageOfEvidence: 'en',
    };

    it('returns 401 when no token is provided', async () => {
      const res = await request(app)
        .post('/api/v1/evidence')
        .send(validEvidencePayload);

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 403 when user has insufficient role (GUEST)', async () => {
      const guestToken = generateTestToken(USER_ROLES.GUEST, testContributorId);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${guestToken}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('returns 400 when body fails schema validation', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send({
          claimId: 'invalid-claim-id',
          sourceType: 'UNKNOWN_TYPE',
          title: 'ab', // min 3 chars
          description: 'short', // min 10 chars
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 400 VALIDATION_ERROR when evidence URL uses dangerous or non-http/https schemes', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);

      const dangerousPayloads = [
        { ...validEvidencePayload, url: 'javascript:alert(1)' },
        { ...validEvidencePayload, url: 'file:///etc/passwd' },
        { ...validEvidencePayload, url: 'ftp://malicious.org/payload' },
      ];

      for (const payload of dangerousPayloads) {
        const res = await request(app)
          .post('/api/v1/evidence')
          .set('Authorization', `Bearer ${token}`)
          .send(payload);

        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_ERROR');
      }
    });

    it('returns 404 if associated claim does not exist', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);
      // Pre-check uses findById (read-only); returning null triggers 404 before touch() is called.
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
      // touch() must NOT be called — no write lock on a non-existent claim.
      expect(claimRepository.touch).not.toHaveBeenCalled();
    });

    // ── Phase-6 integrity: claim status eligibility guard ────────────────────
    // All three rejection cases assert that touch() is NOT called, confirming
    // no spurious __v increment occurs on ineligible claims (CHECK 2).
    it('returns 422 BUSINESS_RULE_VIOLATION when claim is rejected', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'rejected',
        submittedBy: new mongoose.Types.ObjectId(testContributorId),
        evidenceIds: [],
      } as any);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toMatch(/rejected/);
      // CHECK 2: touch() must NOT be called — __v must not increment on a closed claim.
      expect(claimRepository.touch).not.toHaveBeenCalled();
    });

    it('returns 422 BUSINESS_RULE_VIOLATION when claim is archived', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'archived',
        submittedBy: new mongoose.Types.ObjectId(testContributorId),
        evidenceIds: [],
      } as any);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toMatch(/archived/);
      // CHECK 2: touch() must NOT be called — __v must not increment on a closed claim.
      expect(claimRepository.touch).not.toHaveBeenCalled();
    });

    it('returns 403 UNAUTHORIZED when attaching evidence to another user\'s draft', async () => {
      const differentOwnerId = new mongoose.Types.ObjectId().toString();
      // The claim's submittedBy is differentOwnerId; contributor is testContributorId
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'draft',
        submittedBy: new mongoose.Types.ObjectId(differentOwnerId), // NOT the requester
        evidenceIds: [],
      } as any);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      // CHECK 2: touch() must NOT be called — __v must not increment on a foreign draft.
      expect(claimRepository.touch).not.toHaveBeenCalled();
    });

    // ── Phase-6 Concurrency: Deterministic Race Condition Tests ─────────────
    // Simulates concurrent status changes occurring between the pre-check
    // findById() and transactional touch() write lock.
    it('aborts transaction with 422 BUSINESS_RULE_VIOLATION when claim is rejected concurrently between read and lock', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);
      const eligibleClaim = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'submitted', // Active during initial read
        submittedBy: new mongoose.Types.ObjectId(testContributorId),
        evidenceIds: [],
      };
      const concurrentlyRejectedClaim = {
        ...eligibleClaim,
        status: 'rejected', // Rejection committed concurrently before lock acquired
      };

      // Initial read sees active claim (passes pre-check)
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(eligibleClaim as any);
      // touch() acquires the lock, revealing concurrent rejection
      jest.spyOn(claimRepository, 'touch').mockResolvedValue(concurrentlyRejectedClaim as any);

      const evidenceCreateSpy = jest.spyOn(evidenceRepository, 'create');
      const claimUpdateSpy = jest.spyOn(claimRepository, 'update');

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toMatch(/rejected/);

      // Verify that touch was called (entered transaction and acquired write lock)
      expect(claimRepository.touch).toHaveBeenCalled();
      // Verify NO evidence was created, NO claim was updated, and NO audit log was persisted
      expect(evidenceCreateSpy).not.toHaveBeenCalled();
      expect(claimUpdateSpy).not.toHaveBeenCalled();
      expect(auditService.writeAuditLog).not.toHaveBeenCalled();
    });

    it('aborts transaction with 422 BUSINESS_RULE_VIOLATION when claim is archived concurrently between read and lock', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);
      const eligibleClaim = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'under_review', // Active during initial read
        submittedBy: new mongoose.Types.ObjectId(testContributorId),
        evidenceIds: [],
      };
      const concurrentlyArchivedClaim = {
        ...eligibleClaim,
        status: 'archived', // Archived by moderator concurrently before lock acquired
      };

      // Initial read sees active claim (passes pre-check)
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(eligibleClaim as any);
      // touch() acquires the lock, revealing concurrent archive
      jest.spyOn(claimRepository, 'touch').mockResolvedValue(concurrentlyArchivedClaim as any);

      const evidenceCreateSpy = jest.spyOn(evidenceRepository, 'create');
      const claimUpdateSpy = jest.spyOn(claimRepository, 'update');

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toMatch(/archived/);

      // Verify that touch was called (entered transaction and acquired write lock)
      expect(claimRepository.touch).toHaveBeenCalled();
      // Verify NO evidence was created, NO claim was updated, and NO audit log was persisted
      expect(evidenceCreateSpy).not.toHaveBeenCalled();
      expect(claimUpdateSpy).not.toHaveBeenCalled();
      expect(auditService.writeAuditLog).not.toHaveBeenCalled();
    });
    // ─────────────────────────────────────────────────────────────────────────

    it('allows evidence on own draft (owner attaches to their unsubmitted draft)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);
      const mockClaim = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'draft',
        submittedBy: new mongoose.Types.ObjectId(testContributorId), // SAME as requester
        evidenceIds: [],
      };
      // Pre-check uses findById; touch() is called inside the transaction.
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockClaim as any);
      jest.spyOn(claimRepository, 'touch').mockResolvedValue(mockClaim as any);
      jest.spyOn(claimRepository, 'update').mockResolvedValue(mockClaim as any);

      const createdEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        sourceType: 'DOCUMENT',
        title: validEvidencePayload.title,
        description: validEvidencePayload.description,
        documentRef: validEvidencePayload.documentRef,
        status: 'submitted',
        uploadedBy: new mongoose.Types.ObjectId(testContributorId),
        uploadedAt: new Date(),
      };
      jest.spyOn(evidenceRepository, 'create').mockResolvedValue(createdEvidence as any);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(201);
      expect(res.body.data.status).toBe('submitted');
      // CHECK 2: touch() MUST be called — write lock is acquired for eligible claim.
      expect(claimRepository.touch).toHaveBeenCalled();
    });
    // ─────────────────────────────────────────────────────────────────────────

    it('creates evidence successfully, associates with claim, and returns 201', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);

      const mockClaim = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'submitted',
        evidenceIds: [],
      };
      // Pre-check uses findById; touch() is called inside the transaction.
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockClaim as any);
      jest.spyOn(claimRepository, 'touch').mockResolvedValue(mockClaim as any);
      jest.spyOn(claimRepository, 'update').mockResolvedValue(mockClaim as any);

      const createdEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        sourceType: 'DOCUMENT',
        title: validEvidencePayload.title,
        description: validEvidencePayload.description,
        documentRef: validEvidencePayload.documentRef,
        status: 'submitted',
        uploadedBy: new mongoose.Types.ObjectId(testContributorId),
        uploadedAt: new Date(),
      };
      jest.spyOn(evidenceRepository, 'create').mockResolvedValue(createdEvidence as any);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send(validEvidencePayload);

      expect(res.status).toBe(201);
      expect(res.body.data.title).toBe(validEvidencePayload.title);
      expect(res.body.data.status).toBe('submitted');
      expect(evidenceRepository.create).toHaveBeenCalled();
      expect(claimRepository.update).toHaveBeenCalledWith(
        testClaimId,
        { $push: { evidenceIds: createdEvidence._id } },
        expect.anything()
      );
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'evidence',
          action: 'evidence.created',
        }),
        expect.anything()
      );
      // CHECK 2: touch() MUST be called — write lock is acquired for eligible claim.
      expect(claimRepository.touch).toHaveBeenCalled();
    });

    it('permits evidence submission on a disputed claim with revoked consent for dispute resolution (Option 1 policy)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);

      // Claim is in disputed status with revoked consent and is not public
      const mockDisputedRevokedClaim = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'disputed',
        communityTopic: 'biography',
        consentState: 'consent_revoked',
        isPublic: false,
        submittedBy: new mongoose.Types.ObjectId(testContributorId),
        evidenceIds: [],
      };
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockDisputedRevokedClaim as any);
      jest.spyOn(claimRepository, 'touch').mockResolvedValue(mockDisputedRevokedClaim as any);
      jest.spyOn(claimRepository, 'update').mockResolvedValue(mockDisputedRevokedClaim as any);

      const createdEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        sourceType: 'DOCUMENT',
        title: 'Consent Withdrawal Documentation',
        description: 'Legal representation letter detailing consent withdrawal and proposed amended terms.',
        documentRef: 'DOC-WITHDRAWAL-01',
        status: 'submitted',
        uploadedBy: new mongoose.Types.ObjectId(testContributorId),
        uploadedAt: new Date(),
      };
      jest.spyOn(evidenceRepository, 'create').mockResolvedValue(createdEvidence as any);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send({
          ...validEvidencePayload,
          title: createdEvidence.title,
          description: createdEvidence.description,
          documentRef: createdEvidence.documentRef,
        });

      expect(res.status).toBe(201);
      expect(res.body.data.status).toBe('submitted');
      expect(evidenceRepository.create).toHaveBeenCalled();
      // Verify claimRepository.update only appends evidenceId and DOES NOT modify status, isPublic, or consentState
      expect(claimRepository.update).toHaveBeenCalledWith(
        testClaimId,
        { $push: { evidenceIds: createdEvidence._id } },
        expect.anything()
      );
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'evidence',
          action: 'evidence.created',
        }),
        expect.anything()
      );
    });
  });

  describe('GET /api/v1/evidence/claim/:claimId', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app).get(`/api/v1/evidence/claim/${testClaimId}`);
      expect(res.status).toBe(401);
    });

    it('returns 404 if claim does not exist', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/evidence/claim/${testClaimId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns evidence list for the specified claim', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({ _id: testClaimId } as any);

      const mockEvidenceList = [
        {
          _id: new mongoose.Types.ObjectId(testEvidenceId),
          claimId: new mongoose.Types.ObjectId(testClaimId),
          title: 'Document 1',
          status: 'verified',
        },
      ];
      jest.spyOn(evidenceRepository, 'findByClaimId').mockResolvedValue(mockEvidenceList as any);

      const res = await request(app)
        .get(`/api/v1/evidence/claim/${testClaimId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].title).toBe('Document 1');
    });
  });

  describe('GET /api/v1/evidence/:id', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app).get(`/api/v1/evidence/${testEvidenceId}`);
      expect(res.status).toBe(401);
    });

    it('returns 404 when evidence not found', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/evidence/${testEvidenceId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 404 Claim not found when parent claim does not exist (orphaned evidence fails closed)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      const mockEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        title: 'Orphaned Evidence Document',
        status: 'submitted',
      };
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue(mockEvidence as any);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/evidence/${testEvidenceId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
      expect(res.body.error.message).toBe('Claim not found');
    });

    it('returns 403 UNAUTHORIZED when parent claim is a draft owned by another user', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, '507f1f77bcf86cd799439099');
      const mockEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        title: 'Draft Evidence',
        status: 'draft',
      };
      const otherUserDraftClaim = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'draft',
        submittedBy: new mongoose.Types.ObjectId(testContributorId),
        isPublic: false,
      };
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue(mockEvidence as any);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(otherUserDraftClaim as any);

      const res = await request(app)
        .get(`/api/v1/evidence/${testEvidenceId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('returns evidence details when found and parent claim is readable', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      const mockEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        title: 'Census Document',
        status: 'submitted',
      };
      const mockClaim = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'submitted',
        isPublic: true,
        submittedBy: new mongoose.Types.ObjectId(testContributorId),
      };
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue(mockEvidence as any);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockClaim as any);

      const res = await request(app)
        .get(`/api/v1/evidence/${testEvidenceId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.title).toBe('Census Document');
    });
  });

  describe('PATCH /api/v1/evidence/:id/review', () => {
    const validReviewPayload = {
      decision: 'verified',
      reviewNotes: 'Verified against state gazetteer record page 112.',
    };

    it('returns 401 when unauthenticated', async () => {
      const res = await request(app)
        .patch(`/api/v1/evidence/${testEvidenceId}/review`)
        .send(validReviewPayload);

      expect(res.status).toBe(401);
    });

    it('returns 403 when user is not a REVIEWER or higher (CONTRIBUTOR role)', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testContributorId);

      const res = await request(app)
        .patch(`/api/v1/evidence/${testEvidenceId}/review`)
        .set('Authorization', `Bearer ${contributorToken}`)
        .send(validReviewPayload);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('returns 403 SELF_REVIEW_PROHIBITED when reviewer is the uploader', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testReviewerId);

      const mockEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        uploadedBy: new mongoose.Types.ObjectId(testReviewerId), // Same as reviewer!
        status: 'submitted',
      };
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue(mockEvidence as any);

      const res = await request(app)
        .patch(`/api/v1/evidence/${testEvidenceId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send(validReviewPayload);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('SELF_REVIEW_PROHIBITED');
    });

    it('returns 400 when review notes are under 10 characters', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testReviewerId);

      const res = await request(app)
        .patch(`/api/v1/evidence/${testEvidenceId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decision: 'verified',
          reviewNotes: 'Too short', // 9 characters
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 404 if evidence does not exist', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testReviewerId);
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .patch(`/api/v1/evidence/${testEvidenceId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send(validReviewPayload);

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('successfully reviews evidence and ensures parent claim is NOT automatically verified', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testReviewerId);

      const mockEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        uploadedBy: new mongoose.Types.ObjectId(testContributorId), // Different from reviewer
        status: 'submitted',
      };
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue(mockEvidence as any);

      const updatedEvidence = {
        ...mockEvidence,
        status: 'verified',
        reviewedBy: new mongoose.Types.ObjectId(testReviewerId),
        reviewedAt: new Date(),
        reviewNotes: validReviewPayload.reviewNotes,
      };
      jest.spyOn(evidenceRepository, 'update').mockResolvedValue(updatedEvidence as any);

      // Spy on claim update to verify claim status is NOT modified
      const claimUpdateSpy = jest.spyOn(claimRepository, 'update');

      const res = await request(app)
        .patch(`/api/v1/evidence/${testEvidenceId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send(validReviewPayload);

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('verified');
      expect(res.body.data.reviewNotes).toBe(validReviewPayload.reviewNotes);
      expect(evidenceRepository.update).toHaveBeenCalledWith(
        testEvidenceId,
        expect.objectContaining({
          status: 'verified',
          reviewNotes: validReviewPayload.reviewNotes,
        }),
        expect.anything()
      );
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'evidence',
          action: 'evidence.reviewed',
        }),
        expect.anything()
      );

      // Verify that claim was NOT marked verified
      expect(claimUpdateSpy).not.toHaveBeenCalled();
    });

    it('successfully reviews evidence attached to an archived claim without reactivating or verifying parent claim (Option B policy)', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testReviewerId);

      // Parent claim is archived
      const mockArchivedClaim = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: 'archived',
        submittedBy: new mongoose.Types.ObjectId(testContributorId),
        evidenceIds: [new mongoose.Types.ObjectId(testEvidenceId)],
      };
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockArchivedClaim as any);

      // Existing evidence attached to this archived claim
      const mockEvidence = {
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        uploadedBy: new mongoose.Types.ObjectId(testContributorId), // Different from reviewer
        status: 'submitted',
      };
      jest.spyOn(evidenceRepository, 'findById').mockResolvedValue(mockEvidence as any);

      const updatedEvidence = {
        ...mockEvidence,
        status: 'verified',
        reviewedBy: new mongoose.Types.ObjectId(testReviewerId),
        reviewedAt: new Date(),
        reviewNotes: validReviewPayload.reviewNotes,
      };
      jest.spyOn(evidenceRepository, 'update').mockResolvedValue(updatedEvidence as any);

      // Spy on claimRepository.update to verify the parent claim status is NEVER modified
      const claimUpdateSpy = jest.spyOn(claimRepository, 'update');

      const res = await request(app)
        .patch(`/api/v1/evidence/${testEvidenceId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send(validReviewPayload);

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('verified');
      expect(res.body.data.reviewNotes).toBe(validReviewPayload.reviewNotes);

      // 1. Evidence review decision and metadata persisted
      expect(evidenceRepository.update).toHaveBeenCalledWith(
        testEvidenceId,
        expect.objectContaining({
          status: 'verified',
          reviewedBy: new mongoose.Types.ObjectId(testReviewerId),
          reviewNotes: validReviewPayload.reviewNotes,
        }),
        expect.anything()
      );

      // 2. Audit log recorded for evidence review
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'evidence',
          action: 'evidence.reviewed',
          actorId: testReviewerId,
          after: expect.objectContaining({
            status: 'verified',
            reviewNotes: validReviewPayload.reviewNotes,
          }),
        }),
        expect.anything()
      );

      // 3. Parent claim remains untouched: NOT verified, NOT reactivated, NOT updated
      expect(claimUpdateSpy).not.toHaveBeenCalled();
    });
  });
});

