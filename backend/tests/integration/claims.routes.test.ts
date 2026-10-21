import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { createApp } from '../../src/app';
import { claimRepository } from '../../src/modules/claims/repository';
import { placeRepository } from '../../src/modules/places/repository';
import { reviewRepository } from '../../src/modules/verification/repository';
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

describe('Claims Routes (Integration Tests)', () => {
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
  const testOtherUserId = new mongoose.Types.ObjectId().toString();
  const testLocationId = new mongoose.Types.ObjectId().toString();
  const testCountryId = new mongoose.Types.ObjectId().toString();
  const testStateId = new mongoose.Types.ObjectId().toString();
  const testClaimId = new mongoose.Types.ObjectId().toString();

  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(claimRepository, 'withTransaction').mockImplementation(async (cb) => cb({} as any));
    jest.spyOn(claimRepository, 'touch').mockImplementation(async (id, s) => claimRepository.findById(id, s));
    jest.spyOn(auditService, 'writeAuditLog').mockResolvedValue({} as any);
    jest.spyOn(reviewRepository, 'create').mockResolvedValue({ _id: new mongoose.Types.ObjectId() } as any);
    jest.spyOn(reviewRepository, 'findLatestByClaimId').mockResolvedValue(null);
  });

  describe('GET /api/v1/claims', () => {
    it('returns 401 when request is not authenticated', async () => {
      const res = await request(app).get('/api/v1/claims');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 200 with claims list and pagination when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      jest.spyOn(claimRepository, 'list').mockResolvedValue({
        claims: [
          {
            _id: new mongoose.Types.ObjectId(testClaimId),
            id: testClaimId,
            title: { original: 'Ancient Folklore', language: 'en' },
            body: { original: 'Folklore of Mandore passed down orally.', language: 'en' },
            category: CLAIM_CATEGORIES.FOLKLORE,
            status: CLAIM_STATUSES.SUBMITTED,
            locationId: new mongoose.Types.ObjectId(testLocationId),
            submittedAt: new Date(),
            evidenceIds: [],
          } as any,
        ],
        total: 1,
      });

      const res = await request(app)
        .get('/api/v1/claims?page=1&limit=20')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeInstanceOf(Array);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.pagination).toBeDefined();
      expect(res.body.pagination.total).toBe(1);
    });

    it('returns 400 on invalid category query filter when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const res = await request(app)
        .get('/api/v1/claims?category=INVALID_CAT')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('enforces publicOnly: true for general browsing by contributor (excludes drafts and restricted claims)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const listSpy = jest.spyOn(claimRepository, 'list').mockResolvedValue({
        claims: [],
        total: 0,
      });

      const res = await request(app)
        .get('/api/v1/claims?page=1&limit=10')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(listSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          publicOnly: true,
        }),
        expect.anything()
      );
    });

    it('enforces publicOnly: true when querying another user contributions (never exposes other user drafts)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const listSpy = jest.spyOn(claimRepository, 'list').mockResolvedValue({
        claims: [],
        total: 0,
      });

      const res = await request(app)
        .get(`/api/v1/claims?submittedBy=${testOtherUserId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(listSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          submittedBy: testOtherUserId,
          publicOnly: true,
        }),
        expect.anything()
      );
    });

    it('rejects attempt by contributor to query another user drafts with 403 UNAUTHORIZED', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const res = await request(app)
        .get(`/api/v1/claims?submittedBy=${testOtherUserId}&status=draft`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(res.body.error.message).toBe('You can only retrieve your own drafts');
    });

    it('allows contributor to query own drafts with publicOnly: false', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const listSpy = jest.spyOn(claimRepository, 'list').mockResolvedValue({
        claims: [],
        total: 0,
      });

      const res = await request(app)
        .get(`/api/v1/claims?submittedBy=${testUserId}&status=draft`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(listSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          submittedBy: testUserId,
          status: 'draft',
          publicOnly: false,
        }),
        expect.anything()
      );
    });
  });

  describe('GET /api/v1/claims/:id', () => {
    it('returns 401 when request is not authenticated', async () => {
      const res = await request(app).get(`/api/v1/claims/${testClaimId}`);
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 200 with claim details, populated location, and no submitter PII when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        title: { original: 'Ancient Temple', language: 'hi' },
        body: { original: 'मंडोर का प्राचीन मंदिर विवरण', language: 'hi' },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        status: CLAIM_STATUSES.VERIFIED,
        locationId: new mongoose.Types.ObjectId(testLocationId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        submittedAt: new Date(),
        evidenceIds: [],
        tags: ['temple'],
      } as any);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testLocationId),
        id: testLocationId,
        canonicalName: 'Jodhpur',
        level: PLACE_LEVELS.DISTRICT,
        names: [{ language: 'en', name: 'Jodhpur' }],
      } as any);
      jest.spyOn(placeRepository, 'getAncestors').mockResolvedValue([]);

      const res = await request(app)
        .get(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(testClaimId);
      expect(res.body.data.status).toBe(CLAIM_STATUSES.VERIFIED);
      expect(res.body.data.location).toBeDefined();
      expect(res.body.data.evidenceCount).toBe(0);
      expect(res.body.data.latestReview).toBeNull();
      // Verify PII is not leaked
      expect(res.body.data.submittedBy).toBeUndefined();
      expect(res.body.data.email).toBeUndefined();
    });

    it('returns 404 for non-existent claim when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .get(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('supports alias path /claims/:id identically to /api/v1/claims/:id when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        title: { original: 'Ancient Temple', language: 'hi' },
        body: { original: 'मंडोर का प्राचीन मंदिर विवरण', language: 'hi' },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        status: CLAIM_STATUSES.VERIFIED,
        locationId: new mongoose.Types.ObjectId(testLocationId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        submittedAt: new Date(),
        evidenceIds: [],
        tags: ['temple'],
      } as any);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testLocationId),
        id: testLocationId,
        canonicalName: 'Jodhpur',
        level: PLACE_LEVELS.DISTRICT,
        names: [{ language: 'en', name: 'Jodhpur' }],
      } as any);

      const res = await request(app)
        .get(`/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(testClaimId);
      expect(res.body.id).toBe(testClaimId);
    });
  });

  describe('POST /api/v1/claims', () => {
    it('returns 401 when no token is provided', async () => {
      const res = await request(app)
        .post('/api/v1/claims')
        .send({
          title: { original: 'Sample', language: 'en' },
          body: { original: 'Sample body text with enough length.', language: 'en' },
          category: CLAIM_CATEGORIES.FOLKLORE,
          locationId: testLocationId,
        });

      expect(res.status).toBe(401);
    });

    it('returns 400 if location is at COUNTRY level (must anchor to at least Country + State)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testCountryId),
        id: testCountryId,
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
      } as any);

      const res = await request(app)
        .post('/api/v1/claims')
        .set('Authorization', `Bearer ${token}`)
        .send({
          title: { original: 'Sample', language: 'en' },
          body: { original: 'Sample body text with enough length.', language: 'en' },
          category: CLAIM_CATEGORIES.FOLKLORE,
          locationId: testCountryId,
        });

      expect(res.status).toBe(422); // BusinessRuleError maps to 422
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
    });

    it('returns 201 with status draft when called with valid inputs', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testLocationId),
        id: testLocationId,
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
        names: [{ language: 'en', name: 'Jodhpur' }],
      } as any);
      jest.spyOn(placeRepository, 'getAncestors').mockResolvedValue([
        { id: testCountryId, level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
        { id: testStateId, level: PLACE_LEVELS.STATE, canonicalName: 'Rajasthan' },
      ]);

      jest.spyOn(claimRepository, 'create').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        title: { original: 'Sample Folklore', language: 'en' },
        body: { original: 'Detailed folklore text describing Mandore history.', language: 'en' },
        category: CLAIM_CATEGORIES.FOLKLORE,
        status: CLAIM_STATUSES.DRAFT,
        locationId: new mongoose.Types.ObjectId(testLocationId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        submittedAt: new Date(),
        evidenceIds: [],
        tags: ['folk'],
      } as any);

      const res = await request(app)
        .post('/api/v1/claims')
        .set('Authorization', `Bearer ${token}`)
        .send({
          title: { original: 'Sample Folklore', language: 'en' },
          body: { original: 'Detailed folklore text describing Mandore history.', language: 'en' },
          category: CLAIM_CATEGORIES.FOLKLORE,
          locationId: testLocationId,
          tags: ['folk'],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.status).toBe(CLAIM_STATUSES.DRAFT);
      expect(res.body.data.id).toBe(testClaimId);
    });
  });

  describe('PATCH /api/v1/claims/:id/submit', () => {
    it('returns 401 when not authenticated', async () => {
      const res = await request(app).patch(`/api/v1/claims/${testClaimId}/submit`);
      expect(res.status).toBe(401);
    });

    it('returns 403 when caller is not the claim owner', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testOtherUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/submit`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('returns 422 if claim is not in draft status (already submitted)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/submit`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
    });

    it('returns 200 and transitions status to submitted when owner submits draft', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.DRAFT,
      } as any);
      jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}/submit`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe(CLAIM_STATUSES.SUBMITTED);
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'claim',
          action: 'claim.submitted',
          before: { status: CLAIM_STATUSES.DRAFT },
          after: { status: CLAIM_STATUSES.SUBMITTED },
        }),
        expect.anything()
      );
    });
  });

  describe('PATCH /api/v1/claims/:id (Draft Edit)', () => {
    it('returns 422 if attempting to edit a submitted claim (immutability)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);

      const res = await request(app)
        .patch(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          title: { original: 'New Title', language: 'en' },
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
    });
  });

  describe('DELETE /api/v1/claims/:id (Soft-Archive)', () => {
    it('returns 403 when called by CONTRIBUTOR (requires MODERATOR+)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);

      const res = await request(app)
        .delete(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
    });

    it('returns 200 and archives claim when called by MODERATOR', async () => {
      const token = generateTestToken(USER_ROLES.MODERATOR, testUserId);

      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        status: CLAIM_STATUSES.SUBMITTED,
      } as any);
      jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const res = await request(app)
        .delete(`/api/v1/claims/${testClaimId}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Claim archived');
      expect(auditService.writeAuditLog).toHaveBeenCalledWith(
        expect.objectContaining({
          entityType: 'claim',
          action: 'claim.archived',
          before: { status: CLAIM_STATUSES.SUBMITTED },
          after: { status: CLAIM_STATUSES.ARCHIVED },
        }),
        expect.anything()
      );
    });
  });

  describe('POST /api/v1/claims/:id/review (Reviewer-Controlled Verification)', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/review`)
        .send({
          decisionStatus: 'verified',
          reason: 'This claim is verified by historical government archive records.',
        });

      expect(res.status).toBe(401);
    });

    it('returns 403 when called by CONTRIBUTOR (requires REVIEWER+)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/review`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          decisionStatus: 'verified',
          reason: 'This claim is verified by historical government archive records.',
        });

      expect(res.status).toBe(403);
    });

    it('returns 403 SELF_REVIEW_PROHIBITED when contributor attempts to review their own claim', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testUserId);

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId), // Same author
        status: CLAIM_STATUSES.SUBMITTED,
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
      } as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decisionStatus: 'verified',
          reason: 'Attempting to self-verify own historical claim submission.',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('SELF_REVIEW_PROHIBITED');
    });

    it('returns 422 BUSINESS_RULE_VIOLATION when attempting to verify FOLKLORE as verified historical fact', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testOtherUserId);

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.SUBMITTED,
        category: CLAIM_CATEGORIES.FOLKLORE,
      } as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decisionStatus: 'verified',
          reason: 'Attempting to mark local folklore story as verified historical fact.',
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toContain('Folklore and oral traditions cannot be marked as verified historical facts');
    });

    it('returns 422 BUSINESS_RULE_VIOLATION when attempting to verify PUBLIC_OPINION as verified fact', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testOtherUserId);

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.SUBMITTED,
        category: CLAIM_CATEGORIES.PUBLIC_OPINION,
      } as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decisionStatus: 'verified',
          reason: 'Attempting to mark public opinion as verified fact.',
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toContain('Public opinions and perspectives cannot be marked as verified facts');
    });

    it('returns 400 VALIDATION_ERROR when review reason is under 20 characters', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testOtherUserId);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decisionStatus: 'verified',
          reason: 'Too short',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 200 and commits review with status transition when approved by authorized REVIEWER', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testOtherUserId);

      jest.spyOn(claimRepository, 'touch').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        status: CLAIM_STATUSES.SUBMITTED,
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
      } as any);
      jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const reviewRecord = {
        _id: new mongoose.Types.ObjectId(),
        claimId: new mongoose.Types.ObjectId(testClaimId),
        reviewerId: new mongoose.Types.ObjectId(testOtherUserId),
        decisionStatus: 'verified',
        previousStatus: 'submitted',
        reason: 'Verified against local district gazetteer and archaeological records.',
      };
      jest.spyOn(reviewRepository, 'create').mockResolvedValue(reviewRecord as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/review`)
        .set('Authorization', `Bearer ${reviewerToken}`)
        .send({
          decisionStatus: 'verified',
          reason: 'Verified against local district gazetteer and archaeological records.',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.decisionStatus).toBe('verified');
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

  describe('GET /claims/review-queue', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app).get('/api/v1/claims/review-queue');
      expect(res.status).toBe(401);
    });

    it('returns 403 when authenticated as CONTRIBUTOR', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const res = await request(app)
        .get('/api/v1/claims/review-queue')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(403);
    });

    it('returns 200 with review queue items when authenticated as REVIEWER', async () => {
      const reviewerToken = generateTestToken(USER_ROLES.REVIEWER, testOtherUserId);
      jest.spyOn(claimRepository, 'list').mockResolvedValue({
        claims: [
          {
            _id: new mongoose.Types.ObjectId(testClaimId),
            id: testClaimId,
            title: { original: 'Village Folklore', language: 'hi' },
            body: { original: 'गाँव की ऐतिहासिक लोककथा विवरण', language: 'hi' },
            category: CLAIM_CATEGORIES.FOLKLORE,
            status: CLAIM_STATUSES.SUBMITTED,
            locationId: 'PL_VIL_06_077_00382_060008',
            submittedBy: new mongoose.Types.ObjectId(testUserId),
            submittedAt: new Date(),
            evidenceIds: [],
          } as any,
        ],
        total: 1,
      });

      const res = await request(app)
        .get('/api/v1/claims/review-queue')
        .set('Authorization', `Bearer ${reviewerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].status).toBe(CLAIM_STATUSES.SUBMITTED);
      expect(res.body.data[0].locationId).toBe('PL_VIL_06_077_00382_060008');
    });
  });

  describe('POST /api/v1/claims/:id/feedback (Matrbhoomi Feedback)', () => {
    it('returns 401 when unauthenticated', async () => {
      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/feedback`)
        .send({ previouslyKnown: 'yes' });
      expect(res.status).toBe(401);
    });

    it('returns 404 when claim is not found', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/feedback`)
        .set('Authorization', `Bearer ${token}`)
        .send({ previouslyKnown: 'yes' });

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 422 when submitting feedback on an unverified draft claim', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        status: CLAIM_STATUSES.DRAFT,
        submittedBy: new mongoose.Types.ObjectId(testUserId),
        isPublic: false,
      } as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/feedback`)
        .set('Authorization', `Bearer ${token}`)
        .send({ previouslyKnown: 'yes' });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toContain('Feedback can only be submitted on approved and published claims');
    });

    it('returns 422 when submitting feedback on a submitted pending-review claim', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        status: CLAIM_STATUSES.SUBMITTED,
        submittedBy: new mongoose.Types.ObjectId(testOtherUserId),
        isPublic: true,
      } as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/feedback`)
        .set('Authorization', `Bearer ${token}`)
        .send({ previouslyKnown: 'yes' });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
    });

    it('returns 422 when submitting feedback on a rejected claim', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      jest.spyOn(claimRepository, 'findById').mockResolvedValue({
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        status: CLAIM_STATUSES.REJECTED,
        submittedBy: new mongoose.Types.ObjectId(testOtherUserId),
        isPublic: true,
      } as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/feedback`)
        .set('Authorization', `Bearer ${token}`)
        .send({ previouslyKnown: 'yes' });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
    });

    it('submits feedback successfully and records all 4 optional responses', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const mockClaimDoc: any = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        status: CLAIM_STATUSES.VERIFIED,
        isPublic: true,
        submittedBy: new mongoose.Types.ObjectId(testOtherUserId),
        communityFeedbacks: [],
      };
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockClaimDoc);
      const updateSpy = jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/feedback`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          previouslyKnown: 'yes',
          agreement: 'agree',
          comment: 'Historical account verified through family tree archives.',
          knowsAuthor: 'personally',
        });

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.feedback).toBeDefined();
      expect(res.body.data.feedback.userId.toString()).toBe(testUserId);
      expect(res.body.data.feedback.previouslyKnown).toBe('yes');
      expect(res.body.data.feedback.agreement).toBe('agree');
      expect(res.body.data.feedback.comment).toBe('Historical account verified through family tree archives.');
      expect(res.body.data.feedback.knowsAuthor).toBe('personally');
      expect(updateSpy).toHaveBeenCalledWith(
        testClaimId,
        expect.objectContaining({ communityFeedbacks: expect.any(Array) })
      );
      expect(mockClaimDoc.communityFeedbacks).toHaveLength(1);
    });

    it('updates existing response when same user submits feedback again (single response per user/item)', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR, testUserId);
      const mockClaimDoc: any = {
        _id: new mongoose.Types.ObjectId(testClaimId),
        id: testClaimId,
        status: CLAIM_STATUSES.VERIFIED,
        isPublic: true,
        submittedBy: new mongoose.Types.ObjectId(testOtherUserId),
        communityFeedbacks: [
          {
            userId: new mongoose.Types.ObjectId(testUserId),
            previouslyKnown: 'no',
            agreement: 'not_sure',
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        ],
      };
      jest.spyOn(claimRepository, 'findById').mockResolvedValue(mockClaimDoc);
      const updateSpy = jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

      const res = await request(app)
        .post(`/api/v1/claims/${testClaimId}/feedback`)
        .set('Authorization', `Bearer ${token}`)
        .send({
          previouslyKnown: 'yes',
          agreement: 'agree',
          comment: 'Updated confirmation after visiting site.',
          knowsAuthor: 'by_name',
        });

      expect(res.status).toBe(200);
      expect(updateSpy).toHaveBeenCalled();
      expect(mockClaimDoc.communityFeedbacks).toHaveLength(1); // Single response per user
      expect(mockClaimDoc.communityFeedbacks[0].previouslyKnown).toBe('yes');
      expect(mockClaimDoc.communityFeedbacks[0].agreement).toBe('agree');
      expect(mockClaimDoc.communityFeedbacks[0].comment).toBe('Updated confirmation after visiting site.');
    });
  });
});

