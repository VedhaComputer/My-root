import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { createApp } from '../../src/app';
import { claimRepository } from '../../src/modules/claims/repository';
import { placeRepository } from '../../src/modules/places/repository';
import { evidenceRepository } from '../../src/modules/evidence/repository';
import { reviewRepository } from '../../src/modules/verification/repository';
import { placeAttributeRepository } from '../../src/modules/places/placeAttribute.repository';
import { placeProgressService } from '../../src/modules/places/placeProgress.service';
import { auditService } from '../../src/modules/audit/audit.service';
import { env } from '../../src/config/env';
import {
  USER_ROLES,
  CLAIM_CATEGORIES,
  CLAIM_STATUSES,
  PLACE_LEVELS,
  UserRole,
} from '../../src/shared/constants';

const app = createApp();

function generateTestToken(role: UserRole, userId = 'user-test-1', tokenVersion = 1): string {
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

describe('Community Features & Progressive Contribution Integration Tests', () => {
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

  const testUserId = new mongoose.Types.ObjectId().toString();
  const reviewerUserId = new mongoose.Types.ObjectId().toString();
  const testLocationId = new mongoose.Types.ObjectId().toString();
  const testClaimId = new mongoose.Types.ObjectId().toString();
  const testEvidenceId = new mongoose.Types.ObjectId().toString();

  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(claimRepository, 'withTransaction').mockImplementation(async (cb) => cb({} as any));
    jest.spyOn(claimRepository, 'touch').mockImplementation(async (id, s) => claimRepository.findById(id, s));
    jest.spyOn(auditService, 'writeAuditLog').mockResolvedValue({} as any);
  });

  describe('1. Evidence Submission & Association', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app).post('/api/v1/evidence').send({
        claimId: testClaimId,
        sourceType: 'DOCUMENT',
        title: 'Gram Panchayat Minutes',
        description: 'Official record of the village meeting',
      });
      expect(res.status).toBe(401);
    });

    it('attaches evidence to claim and writes audit log in transaction', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      jest.spyOn(evidenceRepository, 'create').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        id: testEvidenceId,
        claimId: new mongoose.Types.ObjectId(testClaimId),
        sourceType: 'DOCUMENT',
        title: 'Gram Panchayat Minutes',
        description: 'Official record of the village meeting',
        uploadedBy: new mongoose.Types.ObjectId(testUserId),
        uploadedAt: new Date(),
      } as any);

      jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${token}`)
        .send({
          claimId: testClaimId,
          sourceType: 'DOCUMENT',
          title: 'Gram Panchayat Minutes',
          description: 'Official record of the village meeting',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBe(testEvidenceId);
      expect(claimRepository.update).toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({
          $push: { evidenceIds: expect.anything() },
        }),
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

  describe('2. Verification Workflow & Self-Review Prohibition', () => {
    it('returns 403 when contributor attempts to review their own claim', async () => {
      const token = generateTestToken(USER_ROLES.REVIEWER, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId), // Same as reviewer
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const res = await request(app)
        .post('/api/v1/verification')
        .set('Authorization', `Bearer ${token}`)
        .send({
          claimId: testClaimId,
          decisionStatus: 'verified',
          reason: 'I am verifying this claim with my own personal knowledge and records.',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('SELF_REVIEW_PROHIBITED');
    });

    it('returns 201 and transitions claim to verified status when an independent reviewer approves', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId), // Different user
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const reviewId = new mongoose.Types.ObjectId().toString();
      jest.spyOn(reviewRepository, 'create').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(reviewId),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        reviewerId: new mongoose.Types.ObjectId(reviewerUserId),
        previousStatus: CLAIM_STATUSES.SUBMITTED,
        decisionStatus: 'verified',
        reason: 'Archival documents and photograph confirm the historic temple location.',
      } as any);

      jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const res = await request(app)
        .post('/api/v1/verification')
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          claimId: testClaimId,
          decisionStatus: 'verified',
          reason: 'Archival documents and photograph confirm the historic temple location.',
        });

      expect(res.status).toBe(201);
      expect(claimRepository.update).toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({ status: 'verified' }),
        expect.anything()
      );
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'review',
          action: 'claim.reviewed',
        }),
        expect.anything()
      );
    });
  });

  describe('3. Traceable Local Attributes & Progressive Quality Score', () => {
    it('creates a timestamped place attribute with source description', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(placeAttributeRepository, 'create').mockResolvedValue({
        id: 'attr-1',
        placeId: testLocationId,
        category: 'facility',
        key: 'Primary Healthcare Centre',
        value: 'Operational with 10 beds',
        sourceDescription: 'District Health Report 2024',
        reportedPeriod: '2024',
      } as any);

      const res = await request(app)
        .post(`/api/v1/places/${testLocationId}/attributes`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          category: 'facility',
          key: 'Primary Healthcare Centre',
          value: 'Operational with 10 beds',
          sourceDescription: 'District Health Report 2024',
          reportedPeriod: '2024',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.key).toBe('Primary Healthcare Centre');
    });

    it('returns explainable quality coverage score independent of population size', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(placeProgressService, 'calculatePlaceProgress').mockImplementationOnce(async () => ({
        placeId: testLocationId,
        totalContributions: 5,
        verifiedFactsCount: 2,
        pendingReviewCount: 1,
        folkloreCount: 1,
        opinionsCount: 1,
        biographiesCount: 0,
        facilitiesCount: 1,
        evidenceAttachmentsCount: 2,
        qualityCoverageScore: 40,
        criteriaExplanation: 'Score is based strictly on documented local heritage, verified evidence, cultural folklore...',
      }));

      const res = await request(app)
        .get(`/api/v1/places/${testLocationId}/progress`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.qualityCoverageScore).toBe(40);
      expect(res.body.data.verifiedFactsCount).toBe(2);
      expect(res.body.data.criteriaExplanation).toContain('Score is based strictly on documented local heritage');
    });
  });

  describe('4. Persistent Draft Resumption & Ownership Isolation (Rule 1)', () => {
    it('rejects unauthenticated attempts to access drafts', async () => {
      const res = await request(app).get(`/api/v1/claims?status=draft&submittedBy=${testUserId}`);
      expect(res.status).toBe(401);
    });

    it('rejects attempt to retrieve another users private drafts', async () => {
      const userAToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const otherUserId = new mongoose.Types.ObjectId().toString();

      const res = await request(app)
        .get(`/api/v1/claims?status=draft&submittedBy=${otherUserId}`)
        .set('Authorization', `Bearer ${userAToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('allows a user to list only their own drafts', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const mockDraft = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        title: { original: 'My Custom Draft', language: 'en' },
        body: { original: 'Working on this lore description.', language: 'en' },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        status: CLAIM_STATUSES.DRAFT,
        locationId: new mongoose.Types.ObjectId(testLocationId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        submittedAt: new Date(),
        evidenceIds: [],
        communityTopic: 'history',
      };

      jest.spyOn(claimRepository, 'list').mockResolvedValue({
        claims: [mockDraft as any],
        total: 1,
      });

      const res = await request(app)
        .get(`/api/v1/claims?status=draft&submittedBy=${testUserId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.length).toBe(1);
      expect(res.body.data[0].id).toBe(testClaimId);
      expect(res.body.data[0].status).toBe('draft');
    });

    it('blocks an unauthorized user from reading another users draft by ID', async () => {
      const otherUserToken = generateTestToken(USER_ROLES.CONTRIBUTOR, new mongoose.Types.ObjectId().toString());

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      const res = await request(app)
        .get(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${otherUserToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('blocks an unauthorized user from editing another users draft', async () => {
      const otherUserToken = generateTestToken(USER_ROLES.CONTRIBUTOR, new mongoose.Types.ObjectId().toString());

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${otherUserToken}`)
        .send({
          title: { original: 'Hijacked Title', language: 'en' },
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });
  });

  describe('5. Four Information Classes Semantic Separation (Rule 2)', () => {
    it('disallows reviewer from marking FOLKLORE category as verified historical fact', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        category: 'FOLKLORE',
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const res = await request(app)
        .post('/api/v1/verification')
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          claimId: testClaimId,
          decisionStatus: 'verified',
          reason: 'This folklore has 10,000 views and is very popular.',
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toContain('Folklore and oral traditions cannot be marked as verified historical facts');
    });

    it('disallows reviewer from marking PUBLIC_OPINION category as verified fact', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        category: 'PUBLIC_OPINION',
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const res = await request(app)
        .post('/api/v1/verification')
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          claimId: testClaimId,
          decisionStatus: 'verified',
          reason: 'This opinion is strongly supported by many people.',
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toContain('Public opinions and perspectives cannot be marked as verified facts');
    });

    it('submitting evidence leaves claim in submitted state and does NOT auto-verify it', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      jest.spyOn(evidenceRepository, 'create').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testEvidenceId),
        id: testEvidenceId,
      } as any);

      const updateSpy = jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const res = await request(app)
        .post('/api/v1/evidence')
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          claimId: testClaimId,
          sourceType: 'GOVERNMENT_RECORD',
          title: 'Official Gazette Notification',
          description: 'Government Gazette record confirming place establishment',
        });

      expect(res.status).toBe(201);
      // Verify claim status was NOT changed to verified
      expect(updateSpy).not.toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({ status: 'verified' }),
        expect.anything()
      );
    });
  });

  describe('6. Living-Person Consent & Privacy Safeguards (Rule 3)', () => {
    it('sets consentState to pending_verification on biography creation with contributor declaration', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testLocationId),
        id: testLocationId,
        level: PLACE_LEVELS.VILLAGE,
      } as any);

      const countryId = new mongoose.Types.ObjectId().toString();
      const stateId = new mongoose.Types.ObjectId().toString();

      jest.spyOn(placeRepository, 'getAncestors').mockResolvedValue([
        { id: countryId, level: PLACE_LEVELS.COUNTRY } as any,
        { id: stateId, level: PLACE_LEVELS.STATE } as any,
      ]);

      const createSpy = jest.spyOn(claimRepository, 'create').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
      } as any);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        title: { original: 'Biography of Shri Ram', language: 'en' },
        body: { original: 'Life story of community builder.', language: 'en' },
        category: CLAIM_CATEGORIES.PERSONAL_EXPERIENCE,
        status: CLAIM_STATUSES.DRAFT,
        locationId: new mongoose.Types.ObjectId(testLocationId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        consentObtained: true,
        consentState: 'pending_verification',
      } as any);

      const res = await request(app)
        .post('/api/v1/claims')
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          locationId: testLocationId,
          title: { original: 'Biography of Shri Ram', language: 'en' },
          body: { original: 'Life story of community builder.', language: 'en' },
          category: CLAIM_CATEGORIES.PERSONAL_EXPERIENCE,
          communityTopic: 'biography',
          consentObtained: true,
          consentDetails: 'Subject verbally agreed during interview on 2026-01-10',
        });

      expect(res.status).toBe(201);
      expect(createSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          consentObtained: true,
          consentState: 'pending_verification',
        })
      );
      expect(res.body.data.consentState).toBe('pending_verification');
    });

    it('blocks submitting a biography claim for review without declared consent', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.DRAFT,
        communityTopic: 'biography',
        consentObtained: false, // No consent
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/submit`)
        .set('Authorization', `Bearer ${contributorToken}`);

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toContain('Cannot submit living-person biography without declared consent');
    });

    it('blocks public users from reading unverified living-person biography by ID', async () => {
      const otherUserToken = generateTestToken(USER_ROLES.CONTRIBUTOR, new mongoose.Types.ObjectId().toString());

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        communityTopic: 'biography',
        consentState: 'pending_verification',
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const res = await request(app)
        .get(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${otherUserToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(res.body.error.message).toContain('pending independent consent verification');
    });

    it('blocks reviewer from verifying living-person biography when consent remains pending', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        communityTopic: 'biography',
        consentState: 'pending_verification',
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const res = await request(app)
        .post('/api/v1/verification')
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          claimId: testClaimId,
          decisionStatus: 'verified',
          reason: 'Attempting to approve living biography without verified consent',
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toContain('Cannot verify a living-person biography while consent remains pending verification');
    });

    it('blocks contributor from self-verifying consentState on update', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.DRAFT,
        communityTopic: 'biography',
        consentState: 'pending_verification',
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          consentState: 'consent_verified',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(res.body.error.message).toContain('Contributors cannot self-verify consent');
    });

    it('blocks contributor from bypassing biography consent via consentState: not_applicable on update', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.DRAFT,
        communityTopic: 'biography',
        consentState: 'pending_verification',
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          consentState: 'not_applicable',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(res.body.error.message).toContain('Contributors cannot self-verify consent');
    });

    it('authorizes reviewer to independently verify consent, enabling public access and subsequent claim verification', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);
      const updateSpy = jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        communityTopic: 'biography',
        consentState: 'pending_verification',
        status: CLAIM_STATUSES.SUBMITTED,
        locationId: new mongoose.Types.ObjectId(testLocationId),
        title: { original: 'Biography of Freedom Fighter', language: 'en' },
        body: { original: 'Life of hero', language: 'en' },
        evidenceIds: [],
        tags: [],
      } as any);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testLocationId),
        id: testLocationId,
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Mandore',
        names: [{ language: 'en', name: 'Mandore' }],
        parentId: null,
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/consent`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          consentState: 'consent_verified',
          notes: 'Signed physical consent form inspected in person on 2026-02-01.',
        });

      expect(res.status).toBe(200);
      expect(updateSpy).toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({
          consentState: 'consent_verified',
          consentNotes: 'Signed physical consent form inspected in person on 2026-02-01.',
        }),
        expect.anything()
      );
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'claim.consent_verified',
          after: expect.objectContaining({
            consentState: 'consent_verified',
          }),
        }),
        expect.anything()
      );
    });

    it('rejects consent verification attempts by unauthorized contributors', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/consent`)
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          consentState: 'consent_verified',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('rejects reviewer from verifying consent for their own submitted biography', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(reviewerUserId), // Same user as reviewer!
        communityTopic: 'biography',
        consentState: 'pending_verification',
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/consent`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          consentState: 'consent_verified',
          notes: 'Self-verifying consent form',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('SELF_REVIEW_PROHIBITED');
    });

    it('allows reviewer to revoke consent, which prevents public access and verification', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);
      const otherUserToken = generateTestToken(USER_ROLES.CONTRIBUTOR, new mongoose.Types.ObjectId().toString());
      const updateSpy = jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        communityTopic: 'biography',
        consentState: 'consent_verified',
        status: CLAIM_STATUSES.SUBMITTED,
        locationId: new mongoose.Types.ObjectId(testLocationId),
        title: { original: 'Biography of Subject', language: 'en' },
        body: { original: 'Details', language: 'en' },
        evidenceIds: [],
        tags: [],
      } as any);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testLocationId),
        id: testLocationId,
        level: PLACE_LEVELS.VILLAGE,
        canonicalName: 'Mandore',
        names: [{ language: 'en', name: 'Mandore' }],
        parentId: null,
      } as any);

      // 1. Revoke consent
      const revokeRes = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/consent`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          consentState: 'consent_revoked',
          notes: 'Subject requested removal of biography on 2026-03-01.',
        });

      expect(revokeRes.status).toBe(200);
      expect(updateSpy).toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({
          consentState: 'consent_revoked',
          isPublic: false,
        }),
        expect.anything()
      );
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'claim.consent_revoked',
        }),
        expect.anything()
      );

      // 2. Public detail read must now be blocked with 403
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        communityTopic: 'biography',
        consentState: 'consent_revoked',
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const publicReadRes = await request(app)
        .get(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${otherUserToken}`);

      expect(publicReadRes.status).toBe(403);
      expect(publicReadRes.body.error.code).toBe('UNAUTHORIZED');

      // 3. Reviewer cannot verify a claim whose consent is revoked
      const reviewRes = await request(app)
        .post('/api/v1/verification')
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          claimId: testClaimId,
          decisionStatus: 'verified',
          reason: 'Attempting approval on revoked biography',
        });

      expect(reviewRes.status).toBe(422);
      expect(reviewRes.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(reviewRes.body.error.message).toContain('Cannot verify a living-person biography while consent remains pending verification or revoked');
    });

    it('aborts consent revocation and rolls back if audit log write fails', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        communityTopic: 'biography',
        consentState: 'consent_verified',
        status: CLAIM_STATUSES.VERIFIED,
      } as any);

      // Simulate audit log write failure
      jest.spyOn(auditService, 'writeAuditLog').mockRejectedValueOnce(new Error('Audit log storage unavailable'));

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/consent`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          consentState: 'consent_revoked',
          notes: 'Attempting revocation with failing audit service.',
        });

      // Transaction aborts; error propagated to global error handler
      expect(res.status).toBe(500);
      expect(res.body.error.code).toBe('INTERNAL_ERROR');
    });
  });

  describe('7. Resilient Scoring & Deduplication (Rule 4)', () => {
    it('deduplicates multiple claims with identical titles and ignores unverified public opinions', async () => {
      const { ClaimModel } = await import('../../src/modules/claims/claim.model');
      const { PlaceAttributeModel } = await import('../../src/modules/places/placeAttribute.model');
      const { EvidenceModel } = await import('../../src/modules/evidence/evidence.model');

      const mockClaims = [
        // Two identical verified historical facts
        {
          _id: new mongoose.Types.ObjectId(),
          title: { original: 'Ancient Fort Gate' },
          category: 'HISTORICAL_RECORD',
          status: 'verified',
        },
        {
          _id: new mongoose.Types.ObjectId(),
          title: { original: 'Ancient Fort Gate' }, // Duplicate!
          category: 'HISTORICAL_RECORD',
          status: 'verified',
        },
        // Another distinct verified fact
        {
          _id: new mongoose.Types.ObjectId(),
          title: { original: 'Riverside Ghat' },
          category: 'CURRENT_FACT',
          status: 'verified',
        },
        // Two duplicate folklore entries
        {
          _id: new mongoose.Types.ObjectId(),
          title: { original: 'Tale of the Banyan Spirit' },
          category: 'FOLKLORE',
          status: 'submitted',
        },
        {
          _id: new mongoose.Types.ObjectId(),
          title: { original: 'tale of the banyan spirit' }, // Duplicate with different casing
          category: 'FOLKLORE',
          status: 'submitted',
        },
        // Public opinions (Must NOT count toward verified facts or culture)
        {
          _id: new mongoose.Types.ObjectId(),
          title: { original: 'We need a new bridge' },
          category: 'PUBLIC_OPINION',
          status: 'submitted',
        },
        {
          _id: new mongoose.Types.ObjectId(),
          title: { original: 'The old market is the best' },
          category: 'PUBLIC_OPINION',
          status: 'submitted',
        },
      ];

      jest.spyOn(ClaimModel, 'find').mockReturnValue({
        lean: jest.fn().mockResolvedValue(mockClaims),
      } as any);

      jest.spyOn(PlaceAttributeModel, 'find').mockReturnValue({
        lean: jest.fn().mockResolvedValue([
          { category: 'facility', key: 'Hospital' },
          { category: 'facility', key: 'hospital' }, // Duplicate key
        ]),
      } as any);

      jest.spyOn(EvidenceModel, 'countDocuments').mockResolvedValue(1);

      const metrics = await placeProgressService.calculatePlaceProgress(testLocationId);

      // Verified facts count must be 2 (Ancient Fort Gate + Riverside Ghat), NOT 3
      expect(metrics.verifiedFactsCount).toBe(2);
      // Folklore count must be 1 (Tale of the Banyan Spirit), NOT 2
      expect(metrics.folkloreCount).toBe(1);
      // Opinions must be recorded separately and NOT in verified facts
      expect(metrics.opinionsCount).toBe(2);
      // Facilities count must be 1, deduplicating case-insensitive keys
      expect(metrics.facilitiesCount).toBe(1);
      // Verified facts pts: min(40, 2*10 + 1*5) = 25 pts
      // Culture pts: min(25, 1*5) = 5 pts
      // Facilities pts: min(25, 1*5) = 5 pts
      // Total qualityCoverageScore = 35
      expect(metrics.qualityCoverageScore).toBe(35);
    });
  });

  describe('8. Correction-Request Workflow', () => {
    it('rejects unauthenticated correction requests', async () => {
      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/correction`)
        .send({
          reason: 'This historical date is inaccurate according to the gazetteer.',
        });

      expect(res.status).toBe(401);
    });

    it('rejects correction requests against unsubmitted drafts', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/correction`)
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          reason: 'Attempting correction on an unsubmitted private draft.',
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toContain('Cannot submit correction requests against unsubmitted drafts');
    });

    it('transitions submitted claim to disputed and persistently creates a pending correction request', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const updateSpy = jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: CLAIM_STATUSES.VERIFIED,
        title: { original: 'Ancient Stepwell of Mandore' },
        body: { original: 'Built in 14th century.' },
      } as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/correction`)
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          reason: 'Archaeological Survey inscription dates construction to 12th century, not 14th.',
          proposedChanges: {
            timePeriod: '12th Century CE',
            sourceAttribution: 'ASI Inscription Plate No. 42',
          },
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('disputed');
      expect(res.body.data.correctionId).toBeDefined();

      expect(updateSpy).toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({
          status: 'disputed',
          userAgreementStatus: 'correction',
          $push: {
            correctionRequests: expect.objectContaining({
              reason: 'Archaeological Survey inscription dates construction to 12th century, not 14th.',
              status: 'pending',
            }),
          },
        }),
        expect.anything()
      );

      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'claim.correction_requested',
          after: expect.objectContaining({
            status: 'disputed',
            reason: expect.stringContaining('Archaeological Survey'),
          }),
        }),
        expect.anything()
      );
    });

    it('allows an independent reviewer to accept a correction request, updating request status and preserving original claim', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);
      const correctionId = new mongoose.Types.ObjectId().toString();
      const updateSpy = jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const mockCorrection = {
        _id: new mongoose.Types.ObjectId(correctionId),
        requestedBy: new mongoose.Types.ObjectId(testUserId), // different from reviewerUserId
        reason: 'ASI gazetteer citation proof',
        status: 'pending',
      };

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: CLAIM_STATUSES.DISPUTED,
        title: { original: 'Ancient Fort of Mandore' },
        body: { original: 'Original uncorrupted claim body.' },
        correctionRequests: [mockCorrection],
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/corrections/${correctionId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decision: 'accepted',
          reviewNotes: 'Copper plate inscription verified against gazetteer. Correction accepted.',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('accepted');
      expect(res.body.data.claimStatus).toBe('verified');

      expect(updateSpy).toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({
          status: 'verified',
          userAgreementStatus: 'correction',
          correctionRequests: expect.arrayContaining([
            expect.objectContaining({
              status: 'accepted',
              reviewNotes: 'Copper plate inscription verified against gazetteer. Correction accepted.',
            }),
          ]),
        }),
        expect.anything()
      );

      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          action: 'claim.correction_reviewed',
          after: expect.objectContaining({
            correctionStatus: 'accepted',
          }),
        }),
        expect.anything()
      );
    });

    it('allows an independent reviewer to reject a correction request, restoring claim to verified', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);
      const correctionId = new mongoose.Types.ObjectId().toString();
      const updateSpy = jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const mockCorrection = {
        _id: new mongoose.Types.ObjectId(correctionId),
        requestedBy: new mongoose.Types.ObjectId(testUserId),
        reason: 'Unsubstantiated rumor',
        status: 'pending',
      };

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: CLAIM_STATUSES.DISPUTED,
        correctionRequests: [mockCorrection],
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/corrections/${correctionId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decision: 'rejected',
          reviewNotes: 'Proposed change contradicts authenticated revenue records. Rejected.',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('rejected');
      expect(res.body.data.claimStatus).toBe('verified');

      expect(updateSpy).toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({
          status: 'verified',
          userAgreementStatus: 'agreed',
          correctionRequests: expect.arrayContaining([
            expect.objectContaining({
              status: 'rejected',
            }),
          ]),
        }),
        expect.anything()
      );
    });

    it('prohibits a contributor from reviewing their own correction request', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerUserId);
      const correctionId = new mongoose.Types.ObjectId().toString();

      // correction was requested by reviewerUserId itself
      const mockCorrection = {
        _id: new mongoose.Types.ObjectId(correctionId),
        requestedBy: new mongoose.Types.ObjectId(reviewerUserId),
        reason: 'Self-requested correction',
        status: 'pending',
      };

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: CLAIM_STATUSES.DISPUTED,
        correctionRequests: [mockCorrection],
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/corrections/${correctionId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decision: 'accepted',
          reviewNotes: 'Attempting to self-approve correction',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('SELF_REVIEW_PROHIBITED');
    });

    it('rejects correction review attempts by unauthorized contributors', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const correctionId = new mongoose.Types.ObjectId().toString();

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/corrections/${correctionId}/review`)
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          decision: 'accepted',
          reviewNotes: 'Contributor trying to review',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('allows authenticated retrieval of all correction requests via GET /:id/corrections', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const correctionId = new mongoose.Types.ObjectId().toString();

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.VERIFIED,
        correctionRequests: [
          {
            _id: new mongoose.Types.ObjectId(correctionId),
            requestedBy: new mongoose.Types.ObjectId(testUserId),
            reason: 'ASI inscription evidence',
            status: 'accepted',
            reviewedBy: new mongoose.Types.ObjectId(reviewerUserId),
            reviewedAt: new Date('2026-02-15'),
            reviewNotes: 'Verified and accepted.',
            createdAt: new Date('2026-02-14'),
          },
        ],
      } as any);

      const res = await request(app)
        .get(`/api/v1/claims/${testClaimId}/corrections`)
        .set('Authorization', `Bearer ${contributorToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].id).toBe(correctionId);
      expect(res.body.data[0].status).toBe('accepted');
      expect(res.body.data[0].reviewNotes).toBe('Verified and accepted.');
    });
  });

  describe('9. Traceable Place-Attribute Correction History', () => {
    const testAttrId = new mongoose.Types.ObjectId().toString();

    it('rejects unauthenticated attribute corrections', async () => {
      const res = await request(app)
        .patch(`/api/v1/places/${testLocationId}/attributes/${testAttrId}`)
        .send({
          value: 'Corrected population count: 5200',
          sourceDescription: '2026 Local Census Update',
        });

      expect(res.status).toBe(401);
    });

    it('preserves complete chronological ordered history across at least two successive corrections', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const secondUserId = new mongoose.Types.ObjectId().toString();
      const secondToken = generateTestToken(USER_ROLES.REVIEWER, secondUserId);

      // In-memory attribute document simulating real Mongoose save() and history push
      const attrDoc: any = {
        _id: new mongoose.Types.ObjectId(testAttrId),
        placeId: new mongoose.Types.ObjectId(testLocationId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        category: 'population',
        key: 'Total Population',
        value: '4500 residents',
        sourceDescription: 'Census 2011',
        reportedPeriod: '2011',
        reportedDate: new Date('2011-03-01'),
        uncertainty: 'Estimated +/- 5%',
        history: [],
        save: jest.fn().mockImplementation(function (this: any) {
          return Promise.resolve(this);
        }),
      };

      jest.spyOn(placeAttributeRepository, 'findById').mockResolvedValue(attrDoc);

      // Correction 1: Update to 5200 residents
      const res1 = await request(app)
        .patch(`/api/v1/places/${testLocationId}/attributes/${testAttrId}`)
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          value: '5200 residents',
          sourceDescription: 'Panchayat Survey 2021',
          reportedPeriod: '2021',
          uncertainty: 'Survey estimate',
          correctionReason: 'First update from 2021 survey',
        });

      expect(res1.status).toBe(200);
      expect(res1.body.data.value).toBe('5200 residents');
      expect(res1.body.data.history).toHaveLength(1);
      expect(res1.body.data.history[0].value).toBe('4500 residents');
      expect(res1.body.data.history[0].correctionReason).toBe('First update from 2021 survey');

      // Correction 2: Successive update to 5850 residents
      const res2 = await request(app)
        .patch(`/api/v1/places/${testLocationId}/attributes/${testAttrId}`)
        .set('Authorization', `Bearer ${secondToken}`)
        .send({
          value: '5850 residents',
          sourceDescription: 'Electoral Roll 2026',
          reportedPeriod: '2026',
          uncertainty: 'Door-to-door verification',
          correctionReason: 'Second update from 2026 voter list verification',
        });

      expect(res2.status).toBe(200);
      expect(res2.body.data.value).toBe('5850 residents');
      expect(res2.body.data.sourceDescription).toBe('Electoral Roll 2026');

      // Verify that history array preserves both snapshots in chronological order
      expect(res2.body.data.history).toHaveLength(2);
      expect(res2.body.data.history[0].value).toBe('4500 residents');
      expect(res2.body.data.history[0].sourceDescription).toBe('Census 2011');
      expect(res2.body.data.history[0].correctionReason).toBe('First update from 2021 survey');

      expect(res2.body.data.history[1].value).toBe('5200 residents');
      expect(res2.body.data.history[1].sourceDescription).toBe('Panchayat Survey 2021');
      expect(res2.body.data.history[1].correctionReason).toBe('Second update from 2026 voter list verification');
    });

    it('allows authenticated retrieval of complete ordered attribute history via GET /:id/attributes/:attrId/history', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      const mockHistory = [
        {
          value: '4500 residents',
          sourceDescription: 'Census 2011',
          reportedPeriod: '2011',
          uncertainty: 'Estimated +/- 5%',
          correctedBy: new mongoose.Types.ObjectId(testUserId),
          correctedAt: new Date('2026-01-01'),
          correctionReason: 'Initial baseline',
        },
        {
          value: '5200 residents',
          sourceDescription: 'Panchayat Survey 2021',
          reportedPeriod: '2021',
          uncertainty: 'Survey estimate',
          correctedBy: new mongoose.Types.ObjectId(reviewerUserId),
          correctedAt: new Date('2026-02-01'),
          correctionReason: 'First update from 2021 survey',
        },
      ];

      jest.spyOn(placeAttributeRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testAttrId),
        history: mockHistory,
      } as any);

      const res = await request(app)
        .get(`/api/v1/places/${testLocationId}/attributes/${testAttrId}/history`)
        .set('Authorization', `Bearer ${contributorToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(2);
      expect(res.body.data[0].value).toBe('4500 residents');
      expect(res.body.data[1].value).toBe('5200 residents');
    });

    it('rejects unauthenticated retrieval of attribute history', async () => {
      const res = await request(app)
        .get(`/api/v1/places/${testLocationId}/attributes/${testAttrId}/history`);

      expect(res.status).toBe(401);
    });

    it('rejects another contributor from modifying an attribute they did not submit (HTTP 403)', async () => {
      const otherContributorId = new mongoose.Types.ObjectId().toString();
      const otherContributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR, otherContributorId);

      const attrDoc: any = {
        _id: new mongoose.Types.ObjectId(testAttrId),
        placeId: new mongoose.Types.ObjectId(testLocationId),
        submittedBy: new mongoose.Types.ObjectId(testUserId), // Submitted by original contributor
        category: 'facility',
        key: 'Community Hall',
        value: 'Capacity 200',
        sourceDescription: 'Official Panchayat Records',
        history: [],
        save: jest.fn(),
      };

      jest.spyOn(placeAttributeRepository, 'findById').mockResolvedValue(attrDoc);

      const res = await request(app)
        .patch(`/api/v1/places/${testLocationId}/attributes/${testAttrId}`)
        .set('Authorization', `Bearer ${otherContributorToken}`)
        .send({
          value: 'Capacity 500',
          sourceDescription: 'Unofficial rumor',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(res.body.error.message).toContain('Only the original contributor or a reviewer/admin can modify this attribute');
      expect(attrDoc.save).not.toHaveBeenCalled();
    });

    it('allows an authorized reviewer or admin to modify any attribute with audit history', async () => {
      const reviewerId = new mongoose.Types.ObjectId().toString();
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, reviewerId);

      const attrDoc: any = {
        _id: new mongoose.Types.ObjectId(testAttrId),
        placeId: new mongoose.Types.ObjectId(testLocationId),
        submittedBy: new mongoose.Types.ObjectId(testUserId), // Original contributor is different
        category: 'facility',
        key: 'Community Hall',
        value: 'Capacity 200',
        sourceDescription: 'Official Panchayat Records',
        history: [],
        save: jest.fn().mockImplementation(function (this: any) {
          return Promise.resolve(this);
        }),
      };

      jest.spyOn(placeAttributeRepository, 'findById').mockResolvedValue(attrDoc);

      const res = await request(app)
        .patch(`/api/v1/places/${testLocationId}/attributes/${testAttrId}`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          value: 'Capacity 350',
          sourceDescription: 'Verified PWD Inspection Report 2026',
          correctionReason: 'Official audit expansion verification',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.value).toBe('Capacity 350');
      expect(res.body.data.history).toHaveLength(1);
      expect(res.body.data.history[0].correctedBy.toString()).toBe(reviewerId);
      expect(attrDoc.save).toHaveBeenCalled();
    });
  });
});


