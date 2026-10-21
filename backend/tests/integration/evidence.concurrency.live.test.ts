import mongoose from 'mongoose';
import { EvidenceService } from '../../src/modules/evidence/service';
import { EvidenceRepository } from '../../src/modules/evidence/repository';
import { ClaimService } from '../../src/modules/claims/service';
import { ClaimRepository } from '../../src/modules/claims/repository';
import { AuditService } from '../../src/modules/audit/audit.service';
import { PlaceModel, IPlace } from '../../src/modules/places/place.model';
import { PlaceRepository } from '../../src/modules/places/repository';
import { PlaceService } from '../../src/modules/places/service';
import { ReviewModel } from '../../src/modules/verification/review.model';
import { ReviewRepository } from '../../src/modules/verification/repository';
import { VerificationService } from '../../src/modules/verification/service';
import { ClaimModel } from '../../src/modules/claims/claim.model';
import { EvidenceModel } from '../../src/modules/evidence/evidence.model';
import { AuditLogModel } from '../../src/modules/audit/auditLog.model';
import { CLAIM_CATEGORIES, CLAIM_STATUSES, PLACE_LEVELS, USER_ROLES } from '../../src/shared/constants';
import { BusinessRuleError } from '../../src/shared/errors/AppError';

// Target port and isolated test database configuration
const TEST_PORT = 27018;
const TEST_DB = 'myroot_concurrency_test';
const TEST_URI = `mongodb://127.0.0.1:${TEST_PORT}/${TEST_DB}?directConnection=true`;

describe('Evidence Live MongoDB Replica-Set Concurrency Tests', () => {
  let realClaimRepo: ClaimRepository;
  let realEvidenceRepo: EvidenceRepository;
  let realAuditService: AuditService;
  let realPlaceRepo: PlaceRepository;
  let realPlaceService: PlaceService;
  let realReviewRepo: ReviewRepository;
  let realVerificationService: VerificationService;
  let realEvidenceService: EvidenceService;
  let realClaimService: ClaimService;
  let sharedLivePlace: IPlace;

  const createdClaimIds: string[] = [];
  const createdEvidenceIds: string[] = [];
  const createdPlaceIds: string[] = [];

  beforeAll(async () => {
    // 1. Establish connection to isolated test replica set
    await mongoose.connect(TEST_URI, {
      serverSelectionTimeoutMS: 5000,
    });

    // 2. Strict Environment & Safety Guard: Assert connection properties
    const conn = mongoose.connection;
    const admin = conn.db!.admin();
    const helloRes = await admin.command({ hello: 1 });

    if (conn.port !== TEST_PORT) {
      throw new Error(`SAFETY BLOCKER: Expected port ${TEST_PORT}, but connected to ${conn.port}`);
    }
    if (conn.name !== TEST_DB) {
      throw new Error(`SAFETY BLOCKER: Expected database ${TEST_DB}, but connected to ${conn.name}`);
    }
    if (helloRes.setName !== 'rs0') {
      throw new Error(`SAFETY BLOCKER: Expected replica set rs0, but found ${helloRes.setName}`);
    }
    if (!helloRes.isWritablePrimary) {
      throw new Error('SAFETY BLOCKER: Connected node is not a writable primary');
    }

    // 3. Instantiate real repositories and service with actual MongoDB connections
    realClaimRepo = new ClaimRepository();
    realEvidenceRepo = new EvidenceRepository();
    realAuditService = new AuditService();
    realPlaceRepo = new PlaceRepository();
    realPlaceService = new PlaceService(realPlaceRepo);
    realReviewRepo = new ReviewRepository();
    realVerificationService = new VerificationService(realReviewRepo, realClaimRepo, realAuditService);
    realEvidenceService = new EvidenceService(realEvidenceRepo, realClaimRepo, realAuditService);
    realClaimService = new ClaimService(
      realClaimRepo,
      realPlaceRepo,
      realPlaceService,
      realAuditService,
      realReviewRepo,
      realVerificationService
    );

    // Create shared live place for realistic claim relations
    sharedLivePlace = await PlaceModel.create({
      level: PLACE_LEVELS.STATE,
      canonicalName: `Live Concurrency State ${Date.now()}`,
      canonicalNameLower: `live concurrency state ${Date.now()}`.toLowerCase(),
      names: [{ language: 'en', name: `Live Concurrency State ${Date.now()}` }],
      parentId: null,
    });
    createdPlaceIds.push(sharedLivePlace._id.toString());
  }, 15000);

  afterAll(async () => {
    // Clean up all records created by these tests
    if (createdClaimIds.length > 0) {
      await ClaimModel.deleteMany({ _id: { $in: createdClaimIds } }).exec();
      await ReviewModel.deleteMany({ claimId: { $in: createdClaimIds } }).exec();
      await AuditLogModel.deleteMany({
        $or: [
          { entityId: { $in: createdClaimIds } },
          { 'after.claimId': { $in: createdClaimIds } },
        ],
      }).exec();
    }
    if (createdEvidenceIds.length > 0) {
      await EvidenceModel.deleteMany({ _id: { $in: createdEvidenceIds } }).exec();
      await AuditLogModel.deleteMany({ entityId: { $in: createdEvidenceIds } }).exec();
    }
    if (createdPlaceIds.length > 0) {
      await PlaceModel.deleteMany({ _id: { $in: createdPlaceIds } }).exec();
    }
    await mongoose.disconnect();
  }, 15000);

  afterEach(async () => {
    // Clean up records tracked per test
    if (createdClaimIds.length > 0) {
      await ClaimModel.deleteMany({ _id: { $in: createdClaimIds } }).exec();
      await ReviewModel.deleteMany({ claimId: { $in: createdClaimIds } }).exec();
      await AuditLogModel.deleteMany({
        $or: [
          { entityId: { $in: createdClaimIds } },
          { 'after.claimId': { $in: createdClaimIds } },
        ],
      }).exec();
      createdClaimIds.length = 0;
    }
    if (createdEvidenceIds.length > 0) {
      await EvidenceModel.deleteMany({ _id: { $in: createdEvidenceIds } }).exec();
      await AuditLogModel.deleteMany({ entityId: { $in: createdEvidenceIds } }).exec();
      createdEvidenceIds.length = 0;
    }
    jest.restoreAllMocks();
  });

  // Helper to insert a realistic claim directly into the live MongoDB replica set
  async function createLiveClaim(
    status: string = CLAIM_STATUSES.SUBMITTED,
    userId?: string,
    overrides: Record<string, any> = {}
  ) {
    const claim = new ClaimModel({
      title: { original: `Live Claim ${Date.now()}`, language: 'en' },
      body: { original: `Live Claim Body for Concurrency Verification ${Date.now()}`, language: 'en' },
      category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
      status,
      locationId: overrides.locationId || sharedLivePlace._id,
      locationPath: overrides.locationPath || [sharedLivePlace._id],
      submittedBy: userId ? new mongoose.Types.ObjectId(userId) : new mongoose.Types.ObjectId(),
      tags: ['live-concurrency-test'],
      evidenceIds: [],
      isPublic: true,
      submittedAt: new Date(),
      updatedAt: new Date(),
      ...overrides,
    });
    const saved = await claim.save();
    createdClaimIds.push(saved._id.toString());
    return saved;
  }

  describe('Control Case: Successful Evidence Submission on Active Claim', () => {
    it('successfully commits evidence, updates claim.evidenceIds, and writes audit record in live replica set', async () => {
      const contributorId = new mongoose.Types.ObjectId().toString();
      const claim = await createLiveClaim(CLAIM_STATUSES.SUBMITTED, contributorId);
      const claimId = claim._id.toString();

      const evidencePayload = {
        claimId,
        sourceType: 'DOCUMENT' as const,
        title: 'Original Gazette Settlement 1904',
        description: 'Archival gazette entry recording settlement survey boundaries in full detail.',
        documentRef: 'GAZ-1904-B4',
        languageOfEvidence: 'en',
      };

      // Execute submission against real MongoDB replica set
      const result = await realEvidenceService.submitEvidence(evidencePayload, contributorId, '127.0.0.1');
      expect(result).toBeDefined();
      expect(result._id).toBeDefined();
      const evidenceId = result._id.toString();
      createdEvidenceIds.push(evidenceId);

      // Verify persisted state in live MongoDB:
      // 1. Evidence record exists in real collection
      const persistedEvidence = await EvidenceModel.findById(evidenceId).exec();
      expect(persistedEvidence).not.toBeNull();
      expect(persistedEvidence!.title).toBe(evidencePayload.title);
      expect(persistedEvidence!.status).toBe('submitted');
      expect(persistedEvidence!.claimId.toString()).toBe(claimId);

      // 2. Claim document in real collection has evidenceId in evidenceIds array
      const persistedClaim = await ClaimModel.findById(claimId).exec();
      expect(persistedClaim).not.toBeNull();
      const evidenceIdStrings = persistedClaim!.evidenceIds.map((id) => id.toString());
      expect(evidenceIdStrings).toContain(evidenceId);

      // 3. Audit log record was written in real collection
      const auditLog = await AuditLogModel.findOne({
        entityType: 'evidence',
        entityId: new mongoose.Types.ObjectId(evidenceId),
        action: 'evidence.created',
      }).exec();
      expect(auditLog).not.toBeNull();
      expect(auditLog!.after).not.toBeNull();
      expect(auditLog!.after!.claimId).toBe(claimId);
    }, 20000);
  });

  describe('Race Condition Scenario 1: Claim Rejected Concurrently Between Read and Lock', () => {
    it('aborts transaction, commits neither evidence nor claim reference when claim is rejected concurrently', async () => {
      const contributorId = new mongoose.Types.ObjectId().toString();
      const claim = await createLiveClaim(CLAIM_STATUSES.SUBMITTED, contributorId);
      const claimId = claim._id.toString();

      const evidencePayload = {
        claimId,
        sourceType: 'DOCUMENT' as const,
        title: 'Contested Land Record',
        description: 'Survey map attempting attachment during concurrent reviewer rejection.',
        documentRef: 'MAP-1920-RACE',
        languageOfEvidence: 'en',
      };

      // Deterministic Concurrency Coordination Hook:
      // Use the REAL claimRepo.findById to read the active claim from MongoDB.
      // Immediately after the real read returns, execute a SEPARATE database operation
      // that transitions the claim to 'rejected' in the live replica set.
      // Then return the real document from the initial read.
      const originalFindById = realClaimRepo.findById.bind(realClaimRepo);
      let concurrentRejectionExecuted = false;

      jest.spyOn(realClaimRepo, 'findById').mockImplementation(async (id: string, session?: mongoose.ClientSession) => {
        const realDoc = await originalFindById(id, session);
        if (id === claimId && !concurrentRejectionExecuted) {
          concurrentRejectionExecuted = true;
          // Separate concurrent database operation: reviewer rejects the claim in MongoDB
          await ClaimModel.findByIdAndUpdate(
            claimId,
            { status: CLAIM_STATUSES.REJECTED, updatedAt: new Date() },
            { new: true }
          ).exec();
        }
        return realDoc;
      });

      // Execute evidence submission — should enter transaction, acquire lock,
      // detect rejected status under lock, and throw BusinessRuleError.
      let caughtError: any = null;
      try {
        await realEvidenceService.submitEvidence(evidencePayload, contributorId, '127.0.0.1');
      } catch (err) {
        caughtError = err;
      }

      // Assert submission failure
      expect(caughtError).toBeInstanceOf(BusinessRuleError);
      expect(caughtError.message).toMatch(/rejected/);
      expect(concurrentRejectionExecuted).toBe(true);

      // Verify Persisted Database State in Live Replica Set:
      // 1. Zero evidence records exist in MongoDB for this claim
      const persistedEvidences = await EvidenceModel.find({
        claimId: new mongoose.Types.ObjectId(claimId),
      }).exec();
      expect(persistedEvidences).toHaveLength(0);

      // 2. Claim document in MongoDB has empty evidenceIds and status 'rejected'
      const persistedClaim = await ClaimModel.findById(claimId).exec();
      expect(persistedClaim).not.toBeNull();
      expect(persistedClaim!.status).toBe(CLAIM_STATUSES.REJECTED);
      expect(persistedClaim!.evidenceIds).toHaveLength(0);

      // 3. Zero creation audit logs committed for evidence on this claim
      const auditLogs = await AuditLogModel.find({
        entityType: 'evidence',
        'after.claimId': claimId,
      }).exec();
      expect(auditLogs).toHaveLength(0);
    }, 20000);
  });

  describe('Race Condition Scenario 2: Claim Archived Concurrently Between Read and Lock', () => {
    it('aborts transaction, commits neither evidence nor claim reference when claim is archived concurrently', async () => {
      const contributorId = new mongoose.Types.ObjectId().toString();
      const claim = await createLiveClaim(CLAIM_STATUSES.UNDER_REVIEW, contributorId);
      const claimId = claim._id.toString();

      const evidencePayload = {
        claimId,
        sourceType: 'GOVERNMENT_RECORD' as const,
        title: 'Municipal Archive File',
        description: 'Municipal gazette page attempting attachment during concurrent moderator archiving.',
        documentRef: 'MUN-1910-ARCH',
        languageOfEvidence: 'en',
      };

      // Deterministic Concurrency Coordination Hook:
      // Read active claim from live MongoDB, then concurrently archive it in MongoDB
      const originalFindById = realClaimRepo.findById.bind(realClaimRepo);
      let concurrentArchiveExecuted = false;

      jest.spyOn(realClaimRepo, 'findById').mockImplementation(async (id: string, session?: mongoose.ClientSession) => {
        const realDoc = await originalFindById(id, session);
        if (id === claimId && !concurrentArchiveExecuted) {
          concurrentArchiveExecuted = true;
          // Separate concurrent database operation: moderator archives the claim in MongoDB
          await ClaimModel.findByIdAndUpdate(
            claimId,
            { status: CLAIM_STATUSES.ARCHIVED, updatedAt: new Date() },
            { new: true }
          ).exec();
        }
        return realDoc;
      });

      let caughtError: any = null;
      try {
        await realEvidenceService.submitEvidence(evidencePayload, contributorId, '127.0.0.1');
      } catch (err) {
        caughtError = err;
      }

      // Assert submission failure
      expect(caughtError).toBeInstanceOf(BusinessRuleError);
      expect(caughtError.message).toMatch(/archived/);
      expect(concurrentArchiveExecuted).toBe(true);

      // Verify Persisted Database State in Live Replica Set:
      // 1. Zero evidence records exist in MongoDB
      const persistedEvidences = await EvidenceModel.find({
        claimId: new mongoose.Types.ObjectId(claimId),
      }).exec();
      expect(persistedEvidences).toHaveLength(0);

      // 2. Claim in MongoDB has empty evidenceIds and status 'archived'
      const persistedClaim = await ClaimModel.findById(claimId).exec();
      expect(persistedClaim).not.toBeNull();
      expect(persistedClaim!.status).toBe(CLAIM_STATUSES.ARCHIVED);
      expect(persistedClaim!.evidenceIds).toHaveLength(0);

      // 3. Zero creation audit logs committed
      const auditLogs = await AuditLogModel.find({
        entityType: 'evidence',
        'after.claimId': claimId,
      }).exec();
      expect(auditLogs).toHaveLength(0);
    }, 20000);
  });

  describe('Scenario 3: Option 1 — Dispute Resolution Model on Revoked Biography', () => {
    it('permits evidence submission on a disputed claim with revoked consent without reactivating or verifying it', async () => {
      const subjectContributorId = new mongoose.Types.ObjectId().toString();
      const disputeContributorId = new mongoose.Types.ObjectId().toString();
      const reviewerId = new mongoose.Types.ObjectId().toString();

      // Living-person biography whose consent was revoked:
      // status: 'disputed', consentState: 'consent_revoked', isPublic: false
      const claim = await createLiveClaim(CLAIM_STATUSES.DISPUTED, subjectContributorId, {
        category: CLAIM_CATEGORIES.PERSONAL_EXPERIENCE,
        communityTopic: 'biography',
        consentState: 'consent_revoked',
        isPublic: false,
      });
      const claimId = claim._id.toString();

      const evidencePayload = {
        claimId,
        sourceType: 'DOCUMENT' as const,
        title: 'Dispute Resolution Archival Record',
        description: 'Independent documentary record submitted to clarify disputed facts during active dispute resolution.',
        documentRef: 'DOC-DISPUTE-2026',
        languageOfEvidence: 'en',
      };

      // 1. Evidence submission MUST succeed under Option 1 (Dispute Resolution Model)
      const submitResult = await realEvidenceService.submitEvidence(
        evidencePayload,
        disputeContributorId,
        '127.0.0.1'
      );
      const evidenceId = submitResult._id.toString();
      createdEvidenceIds.push(evidenceId);

      // 2. Newly created evidence record exists in live MongoDB
      const persistedEvidence = await EvidenceModel.findById(evidenceId).exec();
      expect(persistedEvidence).not.toBeNull();
      expect(persistedEvidence!.title).toBe(evidencePayload.title);
      expect(persistedEvidence!.status).toBe('submitted');

      // 3. Claim document in live MongoDB has evidenceId appended in evidenceIds
      const updatedClaim = await ClaimModel.findById(claimId).exec();
      expect(updatedClaim).not.toBeNull();
      const evidenceIdStrings = updatedClaim!.evidenceIds.map((id) => id.toString());
      expect(evidenceIdStrings).toContain(evidenceId);

      // 4. Invariants strictly preserved in live database:
      // - Claim status REMAINS 'disputed' (NOT automatically verified or marked partially_verified)
      expect(updatedClaim!.status).toBe(CLAIM_STATUSES.DISPUTED);
      // - consentState REMAINS 'consent_revoked' (consent NOT granted or altered)
      expect(updatedClaim!.consentState).toBe('consent_revoked');
      // - isPublic REMAINS false (biography remains private/retracted)
      expect(updatedClaim!.isPublic).toBe(false);

      // 5. Evidence creation audit log committed to MongoDB
      const auditLog = await AuditLogModel.findOne({
        entityType: 'evidence',
        entityId: new mongoose.Types.ObjectId(evidenceId),
        action: 'evidence.created',
      }).exec();
      expect(auditLog).not.toBeNull();
      expect(auditLog!.after!.claimId).toBe(claimId);

      // 6. Verification Guard: Attempting to verify this claim while consent is revoked is strictly rejected
      let verificationError: any = null;
      try {
        await realClaimService.reviewClaim(
          claimId,
          {
            decisionStatus: CLAIM_STATUSES.VERIFIED,
            reason: 'Attempting approval on disputed biography with revoked consent',
            sourcesConsidered: [evidenceId],
          },
          reviewerId,
          USER_ROLES.REVIEWER,
          '127.0.0.1'
        );
      } catch (err) {
        verificationError = err;
      }

      expect(verificationError).toBeInstanceOf(BusinessRuleError);
      expect(verificationError.message).toContain(
        'Cannot verify a living-person biography while consent remains pending verification or revoked'
      );

      // Assert claim still remains disputed and unverified in MongoDB
      const postReviewClaim = await ClaimModel.findById(claimId).exec();
      expect(postReviewClaim!.status).toBe(CLAIM_STATUSES.DISPUTED);
    }, 20000);
  });

  describe('Scenario 4: Atomic Rollback of Consent Revocation on Audit Failure', () => {
    it('aborts transaction and rolls back consent revocation in live MongoDB when audit log write fails', async () => {
      const subjectContributorId = new mongoose.Types.ObjectId().toString();
      const reviewerId = new mongoose.Types.ObjectId().toString();

      // Given a live verified living-person biography claim with verified consent
      const claim = await createLiveClaim(CLAIM_STATUSES.VERIFIED, subjectContributorId, {
        category: CLAIM_CATEGORIES.PERSONAL_EXPERIENCE,
        communityTopic: 'biography',
        consentState: 'consent_verified',
        isPublic: true,
        consentNotes: 'Initial valid consent verified.',
      });
      const claimId = claim._id.toString();

      // Deterministic failure injection: Mock realAuditService.writeAuditLog to simulate failure
      jest.spyOn(realAuditService, 'writeAuditLog').mockRejectedValueOnce(
        new Error('Live replica set simulated audit service failure')
      );

      // Attempt consent revocation
      let caughtError: any = null;
      try {
        await realClaimService.verifyClaimConsent(
          claimId,
          {
            consentState: 'consent_revoked',
            notes: 'Attempting consent revocation during audit outage',
          },
          reviewerId,
          USER_ROLES.REVIEWER,
          '127.0.0.1'
        );
      } catch (err) {
        caughtError = err;
      }

      expect(caughtError).not.toBeNull();
      expect(caughtError.message).toContain('Live replica set simulated audit service failure');

      // Strict Live Database Verification:
      // Assert that the MongoDB transaction rolled back completely and no partial write committed
      const unchangedClaim = await ClaimModel.findById(claimId).exec();
      expect(unchangedClaim).not.toBeNull();
      // Status remains 'verified' (NOT changed to 'disputed')
      expect(unchangedClaim!.status).toBe(CLAIM_STATUSES.VERIFIED);
      // consentState remains 'consent_verified' (NOT changed to 'consent_revoked')
      expect(unchangedClaim!.consentState).toBe('consent_verified');
      // isPublic remains true (NOT flipped to false)
      expect(unchangedClaim!.isPublic).toBe(true);
      // notes remain initial notes
      expect(unchangedClaim!.consentNotes).toBe('Initial valid consent verified.');

      // Zero audit log records written for consent revocation on this claim
      const revocationAuditLogs = await AuditLogModel.find({
        entityId: new mongoose.Types.ObjectId(claimId),
        action: 'claim.consent_revoked',
      }).exec();
      expect(revocationAuditLogs).toHaveLength(0);
    }, 20000);

    it('successfully commits consent revocation, transitions status to disputed, sets isPublic to false, and commits audit log when audit succeeds', async () => {
      const subjectContributorId = new mongoose.Types.ObjectId().toString();
      const reviewerId = new mongoose.Types.ObjectId().toString();

      const claim = await createLiveClaim(CLAIM_STATUSES.VERIFIED, subjectContributorId, {
        category: CLAIM_CATEGORIES.PERSONAL_EXPERIENCE,
        communityTopic: 'biography',
        consentState: 'consent_verified',
        isPublic: true,
      });
      const claimId = claim._id.toString();

      // Execute revocation with healthy audit service
      const result = await realClaimService.verifyClaimConsent(
        claimId,
        {
          consentState: 'consent_revoked',
          notes: 'Legitimate consent revocation requested by subject.',
        },
        reviewerId,
        USER_ROLES.REVIEWER,
        '127.0.0.1'
      );

      expect(result).not.toBeNull();

      // Verify MongoDB state in live replica set
      const updatedClaim = await ClaimModel.findById(claimId).exec();
      expect(updatedClaim).not.toBeNull();
      expect(updatedClaim!.status).toBe(CLAIM_STATUSES.DISPUTED);
      expect(updatedClaim!.consentState).toBe('consent_revoked');
      expect(updatedClaim!.isPublic).toBe(false);
      expect(updatedClaim!.consentNotes).toBe('Legitimate consent revocation requested by subject.');

      // Verify audit log committed in MongoDB
      const revocationAuditLog = await AuditLogModel.findOne({
        entityId: new mongoose.Types.ObjectId(claimId),
        action: 'claim.consent_revoked',
      }).exec();
      expect(revocationAuditLog).not.toBeNull();
      expect(revocationAuditLog!.actorId.toString()).toBe(reviewerId);
      expect(revocationAuditLog!.before!.consentState).toBe('consent_verified');
      expect(revocationAuditLog!.after!.consentState).toBe('consent_revoked');
    }, 20000);
  });

  describe('Race Condition Scenario 5A: Consent Revocation Commits Between Evidence Read and Lock', () => {
    it('allows evidence submission to commit against disputed claim after concurrent revocation moves claim to disputed', async () => {
      const subjectContributorId = new mongoose.Types.ObjectId().toString();
      const disputeContributorId = new mongoose.Types.ObjectId().toString();
      const reviewerId = new mongoose.Types.ObjectId().toString();

      // Claim starts as verified living-person biography with verified consent
      const claim = await createLiveClaim(CLAIM_STATUSES.VERIFIED, subjectContributorId, {
        category: CLAIM_CATEGORIES.PERSONAL_EXPERIENCE,
        communityTopic: 'biography',
        consentState: 'consent_verified',
        isPublic: true,
      });
      const claimId = claim._id.toString();

      const evidencePayload = {
        claimId,
        sourceType: 'DOCUMENT' as const,
        title: 'Dispute Boundary Survey Map',
        description: 'Document submitted during concurrent revocation for dispute resolution.',
        documentRef: 'MAP-DISPUTE-2026',
        languageOfEvidence: 'en',
      };

      // Real execution boundary synchronization:
      // Hook findById outside transaction. As soon as the initial read sees 'verified',
      // execute realClaimService.verifyClaimConsent in full against live replica set.
      const originalFindById = realClaimRepo.findById.bind(realClaimRepo);
      let concurrentRevocationExecuted = false;

      jest.spyOn(realClaimRepo, 'findById').mockImplementation(async (id: string, session?: mongoose.ClientSession) => {
        const realDoc = await originalFindById(id, session);
        // Only intercept the initial pre-check read (no session) for this claim
        if (id === claimId && !session && !concurrentRevocationExecuted) {
          concurrentRevocationExecuted = true;
          // Concurrent operation: reviewer revokes consent in live replica set
          await realClaimService.verifyClaimConsent(
            claimId,
            {
              consentState: 'consent_revoked',
              notes: 'Revoked by subject request during concurrent submission window.',
            },
            reviewerId,
            USER_ROLES.REVIEWER,
            '127.0.0.1'
          );
        }
        return realDoc;
      });

      // Execute evidence submission
      const submitResult = await realEvidenceService.submitEvidence(
        evidencePayload,
        disputeContributorId,
        '127.0.0.1'
      );
      const evidenceId = submitResult._id.toString();
      createdEvidenceIds.push(evidenceId);

      expect(concurrentRevocationExecuted).toBe(true);

      // Verify Persisted Database State in Live Replica Set:
      // 1. Evidence record exists in MongoDB
      const persistedEvidence = await EvidenceModel.findById(evidenceId).exec();
      expect(persistedEvidence).not.toBeNull();
      expect(persistedEvidence!.status).toBe('submitted');

      // 2. Claim document in MongoDB has evidenceId appended in evidenceIds
      const updatedClaim = await ClaimModel.findById(claimId).exec();
      expect(updatedClaim).not.toBeNull();
      expect(updatedClaim!.evidenceIds.map((id) => id.toString())).toContain(evidenceId);

      // 3. Status remains 'disputed' (moved by revocation, preserved by submitEvidence)
      expect(updatedClaim!.status).toBe(CLAIM_STATUSES.DISPUTED);

      // 4. Consent remains 'consent_revoked' (Option 1 invariant preserved)
      expect(updatedClaim!.consentState).toBe('consent_revoked');

      // 5. isPublic remains false (Option 1 invariant preserved)
      expect(updatedClaim!.isPublic).toBe(false);

      // 6. Both audit logs committed in MongoDB
      const revocationAudit = await AuditLogModel.findOne({
        entityId: new mongoose.Types.ObjectId(claimId),
        action: 'claim.consent_revoked',
      }).exec();
      expect(revocationAudit).not.toBeNull();

      const evidenceAudit = await AuditLogModel.findOne({
        entityId: new mongoose.Types.ObjectId(evidenceId),
        action: 'evidence.created',
      }).exec();
      expect(evidenceAudit).not.toBeNull();
      expect(evidenceAudit!.after!.claimId).toBe(claimId);

      // 7. Verify that attempt to verify claim while consent is revoked continues to fail
      let verificationError: any = null;
      try {
        await realClaimService.reviewClaim(
          claimId,
          {
            decisionStatus: CLAIM_STATUSES.VERIFIED,
            reason: 'Attempting verification on disputed claim with revoked consent',
            sourcesConsidered: [evidenceId],
          },
          reviewerId,
          USER_ROLES.REVIEWER,
          '127.0.0.1'
        );
      } catch (err) {
        verificationError = err;
      }
      expect(verificationError).toBeInstanceOf(BusinessRuleError);
      expect(verificationError.message).toContain(
        'Cannot verify a living-person biography while consent remains pending verification or revoked'
      );
    }, 20000);
  });

  describe('Race Condition Scenario 5B: Evidence Submission Overlaps Revocation with Transaction Write Conflict', () => {
    it('handles concurrent transactions on the same claim document, serializing commits without state loss', async () => {
      const subjectContributorId = new mongoose.Types.ObjectId().toString();
      const disputeContributorId = new mongoose.Types.ObjectId().toString();
      const reviewerId = new mongoose.Types.ObjectId().toString();

      const claim = await createLiveClaim(CLAIM_STATUSES.VERIFIED, subjectContributorId, {
        category: CLAIM_CATEGORIES.PERSONAL_EXPERIENCE,
        communityTopic: 'biography',
        consentState: 'consent_verified',
        isPublic: true,
      });
      const claimId = claim._id.toString();

      const evidencePayload = {
        claimId,
        sourceType: 'DOCUMENT' as const,
        title: 'Overlapping Dispute Settlement Record',
        description: 'Document submitted during active overlapping transaction with revocation.',
        documentRef: 'DOC-OVERLAP-2026',
        languageOfEvidence: 'en',
      };

      // Create coordination deferred promises
      let resolveSubmitHoldingLock: () => void;
      const submitHoldingLockPromise = new Promise<void>((r) => {
        resolveSubmitHoldingLock = r;
      });

      let resolveAllowSubmitToCommit: () => void;
      const allowSubmitToCommitPromise = new Promise<void>((r) => {
        resolveAllowSubmitToCommit = r;
      });

      // Hook realAuditService.writeAuditLog so that when submitEvidence reaches the audit step
      // (after touch, create evidence, update claim), it pauses before committing the transaction.
      const originalWriteAuditLog = realAuditService.writeAuditLog.bind(realAuditService);
      let submitEvidenceAuditPaused = false;

      jest.spyOn(realAuditService, 'writeAuditLog').mockImplementation(async (payload, session) => {
        if (payload.action === 'evidence.created' && payload.after?.claimId === claimId && !submitEvidenceAuditPaused) {
          submitEvidenceAuditPaused = true;
          // Signal that submitEvidence has locked the claim and performed writes in its session
          resolveSubmitHoldingLock();
          // Wait until the overlapping transaction has attempted write / reached lock
          await allowSubmitToCommitPromise;
        }
        return await originalWriteAuditLog(payload, session);
      });

      // Instrument verifyClaimConsent transaction execution attempts
      let revocationTransactionAttempts = 0;
      const originalTouch = realClaimRepo.touch.bind(realClaimRepo);
      jest.spyOn(realClaimRepo, 'touch').mockImplementation(async (id: string, session?: mongoose.ClientSession) => {
        if (id === claimId && session && submitEvidenceAuditPaused) {
          revocationTransactionAttempts++;
        }
        return await originalTouch(id, session);
      });

      // Launch submitEvidence in background
      const submitPromise = realEvidenceService.submitEvidence(
        evidencePayload,
        disputeContributorId,
        '127.0.0.1'
      );

      // Wait until submitEvidence is inside transaction holding the lock
      await submitHoldingLockPromise;

      // Now launch verifyClaimConsent while submitEvidence transaction is active and uncommitted
      const revocationPromise = realClaimService.verifyClaimConsent(
        claimId,
        {
          consentState: 'consent_revoked',
          notes: 'Revoked during active overlapping submission transaction.',
        },
        reviewerId,
        USER_ROLES.REVIEWER,
        '127.0.0.1'
      );

      // Yield event loop briefly (100ms) to allow verifyClaimConsent to execute touch() against live MongoDB
      // and encounter document contention / WriteConflict
      await new Promise((resolve) => setTimeout(resolve, 100));

      // Now allow submitEvidence to complete writeAuditLog and commit its transaction
      resolveAllowSubmitToCommit!();

      // Await both operations
      const [submitResult, revocationResult] = await Promise.all([submitPromise, revocationPromise]);
      const evidenceId = submitResult._id.toString();
      createdEvidenceIds.push(evidenceId);

      expect(submitResult).not.toBeNull();
      expect(revocationResult).not.toBeNull();

      // Verify Persisted Database State in Live Replica Set after both settle:
      // 1. Evidence is committed in MongoDB
      const persistedEvidence = await EvidenceModel.findById(evidenceId).exec();
      expect(persistedEvidence).not.toBeNull();
      expect(persistedEvidence!.status).toBe('submitted');

      // 2. Claim document in MongoDB has evidenceId appended in evidenceIds
      const updatedClaim = await ClaimModel.findById(claimId).exec();
      expect(updatedClaim).not.toBeNull();
      expect(updatedClaim!.evidenceIds.map((id) => id.toString())).toContain(evidenceId);

      // 3. Status is 'disputed'
      expect(updatedClaim!.status).toBe(CLAIM_STATUSES.DISPUTED);

      // 4. Consent is 'consent_revoked'
      expect(updatedClaim!.consentState).toBe('consent_revoked');

      // 5. isPublic is false
      expect(updatedClaim!.isPublic).toBe(false);

      // 6. Both audit logs committed in MongoDB
      const revocationAudit = await AuditLogModel.findOne({
        entityId: new mongoose.Types.ObjectId(claimId),
        action: 'claim.consent_revoked',
      }).exec();
      expect(revocationAudit).not.toBeNull();
      expect(revocationAudit!.actorId.toString()).toBe(reviewerId);

      const evidenceAudit = await AuditLogModel.findOne({
        entityId: new mongoose.Types.ObjectId(evidenceId),
        action: 'evidence.created',
      }).exec();
      expect(evidenceAudit).not.toBeNull();
      expect(evidenceAudit!.after!.claimId).toBe(claimId);

      // 7. Verify claim remains unverified and cannot be approved while consent is revoked
      let verificationError: any = null;
      try {
        await realClaimService.reviewClaim(
          claimId,
          {
            decisionStatus: CLAIM_STATUSES.VERIFIED,
            reason: 'Attempting verification on settled disputed claim',
            sourcesConsidered: [evidenceId],
          },
          reviewerId,
          USER_ROLES.REVIEWER,
          '127.0.0.1'
        );
      } catch (err) {
        verificationError = err;
      }
      expect(verificationError).toBeInstanceOf(BusinessRuleError);
      expect(verificationError.message).toContain(
        'Cannot verify a living-person biography while consent remains pending verification or revoked'
      );
    }, 25000);
  });
});
