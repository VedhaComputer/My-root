import { Request } from 'express';
import mongoose, { ClientSession } from 'mongoose';
import { AuthenticatedRequest } from '../../shared/types';
import { ClaimRepository, claimRepository } from './repository';
import { PlaceRepository, placeRepository } from '../places/repository';
import { PlaceService, placeService, PlaceDetailResult } from '../places/service';
import { assertCanReadClaim } from './authorization';
import { PlaceGatewayService, placeGatewayService } from '../places/gateway';
import { AuditService, auditService } from '../audit/audit.service';
import { ReviewRepository, reviewRepository } from '../verification/repository';
import { VerificationService, verificationService } from '../verification/service';
import { UserModel } from '../auth/user.model';
import {
  CreateClaimInput,
  UpdateClaimInput,
  QueryClaimsInput,
  RequestCorrectionInput,
  VerifyConsentInput,
  ReviewCorrectionInput,
  ReviewClaimInput,
  SubmitHistoryFeedbackInput,
} from './validation';
import {
  CLAIM_STATUSES,
  PLACE_LEVELS,
  PlaceLevel,
  USER_ROLES,
  UserRole,
  hasMinimumRole,
} from '../../shared/constants';
import {
  NotFoundError,
  AuthorizationError,
  BusinessRuleError,
  SelfReviewError,
} from '../../shared/errors/AppError';

export interface ClaimSummary {
  id: string;
  title: { original: string; language: string };
  body: { original: string; language: string };
  category: string;
  status: string;
  locationId: string;
  submittedAt: string;
  submittedBy?: string | null;
  evidenceCount: number;
  communityTopic?: string | null;
  sourceAttribution?: string | null;
  timePeriod?: string | null;
  consentObtained?: boolean;
  consentState?: string | null;
  userAgreementStatus?: string | null;
}

export interface ClaimDetailResult {
  id: string;
  locationId?: string;
  title: { original: string; language: string };
  body: { original: string; language: string };
  category: string;
  status: string;
  location: PlaceDetailResult;
  submittedAt: string;
  submittedBy?: string | null;
  evidenceCount: number;
  latestReview: any | null;
  translations: any[];
  tags: string[];
  communityTopic?: string | null;
  sourceAttribution?: string | null;
  timePeriod?: string | null;
  consentObtained?: boolean;
  consentDetails?: string | null;
  consentState?: string | null;
  consentVerifiedBy?: string | null;
  consentVerifiedAt?: string | null;
  consentNotes?: string | null;
  userAgreementStatus?: string | null;
  correctionRequests?: any[];
  communityFeedbacks?: Array<{
    id: string;
    userId: string;
    previouslyKnown?: string | null;
    agreement?: string | null;
    comment?: string | null;
    knowsAuthor?: string | null;
    createdAt: string;
    updatedAt: string;
  }>;
}

export class ClaimService {
  private claimRepo: ClaimRepository;
  private placeRepo: PlaceRepository;
  private placeServ: PlaceService;
  private auditServ: AuditService;
  private reviewRepo: ReviewRepository;
  private verificationServ: VerificationService;
  private gateway: PlaceGatewayService;

  constructor(
    claimRepo: ClaimRepository = claimRepository,
    placeRepo: PlaceRepository = placeRepository,
    placeServ: PlaceService = placeService,
    auditServ: AuditService = auditService,
    reviewRepo: ReviewRepository = reviewRepository,
    verificationServ: VerificationService = verificationService,
    gateway: PlaceGatewayService = placeGatewayService
  ) {
    this.claimRepo = claimRepo;
    this.placeRepo = placeRepo;
    this.placeServ = placeServ;
    this.auditServ = auditServ;
    this.reviewRepo = reviewRepo;
    this.verificationServ = verificationServ;
    this.gateway = gateway;
  }

  /**
   * Validates location existence and resolves the authoritative ancestor path.
   * Mandates anchoring to at least Country and State levels without skipping levels.
   */
  async resolveAndValidateLocationHierarchy(
    locationId: string,
    session?: ClientSession,
    req?: Request
  ): Promise<{ leafPlace: any; locationPath: (mongoose.Types.ObjectId | string)[] }> {
    let leafPlace: any = await this.placeRepo.findById(locationId, session);
    let ancestors: Array<{ id: string; level: PlaceLevel; canonicalName: string }> = [];

    if (leafPlace) {
      ancestors = await this.placeRepo.getAncestors(locationId, session);
    } else if (this.gateway.isProxyEnabled()) {
      try {
        const response = await this.gateway.executeProxy('GET', `/places/${encodeURIComponent(locationId)}`, req);
        if (response && response.status === 200 && response.body?.data) {
          leafPlace = this.gateway.mapIncomingPlaceData(response.body.data);

          if (Array.isArray(leafPlace.parentPath) && leafPlace.parentPath.length > 0) {
            ancestors = leafPlace.parentPath.map((p: any) => {
              const mapped = this.gateway.mapIncomingPlaceData(p);
              return {
                id: mapped.id || mapped._id,
                level: mapped.level as PlaceLevel,
                canonicalName: mapped.canonicalName,
              };
            });
          } else {
            const ancRes = await this.gateway.executeProxy(
              'GET',
              `/places/${encodeURIComponent(locationId)}/ancestors`,
              req
            );
            if (ancRes && ancRes.status === 200 && Array.isArray(ancRes.body?.data)) {
              ancestors = ancRes.body.data
                .map((p: any) => this.gateway.mapIncomingPlaceData(p))
                .filter((p: any) => (p.id || p._id) !== (leafPlace.id || leafPlace._id))
                .map((p: any) => ({
                  id: p.id || p._id,
                  level: p.level as PlaceLevel,
                  canonicalName: p.canonicalName,
                }));
            }
          }
        }
      } catch {
        // upstream error
      }
    }

    if (!leafPlace) {
      throw new NotFoundError('Place');
    }

    if (leafPlace.level === PLACE_LEVELS.COUNTRY) {
      throw new BusinessRuleError(
        'Claims must be anchored to at least Country and State levels. A Country-only location is not permitted.'
      );
    }

    const leafObjId = leafPlace._id ? leafPlace._id.toString() : (leafPlace.id || locationId);

    const fullChain = [
      ...ancestors,
      {
        id: leafObjId,
        level: leafPlace.level,
        canonicalName: leafPlace.canonicalName,
      },
    ];

    if (fullChain.length > 0 && fullChain[0].level === PLACE_LEVELS.STATE) {
      fullChain.unshift({
        id: 'PL_IND',
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
      });
    }

    if (fullChain.length < 2) {
      throw new BusinessRuleError(
        'Invalid place hierarchy: claim must be anchored to at least Country and State.'
      );
    }

    if (fullChain[0].level !== PLACE_LEVELS.COUNTRY) {
      throw new BusinessRuleError(
        'Invalid place hierarchy: top ancestor must be a COUNTRY.'
      );
    }

    if (fullChain[1].level !== PLACE_LEVELS.STATE) {
      throw new BusinessRuleError(
        'Invalid place hierarchy: second level ancestor must be a STATE.'
      );
    }

    const locationPath = fullChain.map((p) =>
      mongoose.Types.ObjectId.isValid(p.id) ? new mongoose.Types.ObjectId(p.id) : p.id
    );

    return { leafPlace, locationPath };
  }

  /**
   * Creates a new claim.
   * Domain rules:
   * - Always created strictly in 'draft' status.
   * - Client cannot supply status or locationPath.
   * - locationPath is resolved authoritatively from the Places hierarchy.
   */
  async createClaim(
    input: CreateClaimInput,
    userId: string,
    req?: AuthenticatedRequest
  ): Promise<ClaimDetailResult> {
    const { leafPlace, locationPath } = await this.resolveAndValidateLocationHierarchy(
      input.locationId,
      undefined,
      req
    );

    const userObjectId = new mongoose.Types.ObjectId(userId);

    if (req && req.user) {
      let effectiveSelectedPlaceId = req.user.selectedPlaceId;
      let isUserAdmin = req.user.role === USER_ROLES.ADMIN;

      if (effectiveSelectedPlaceId === undefined) {
        if (mongoose.Types.ObjectId.isValid(userId)) {
          try {
            const query = UserModel.findById(userId).select('selectedPlaceId role placeRelationships');
            const userDoc: any =
              query && typeof (query as any).exec === 'function'
                ? await (query as any).exec()
                : query && typeof (query as any).then === 'function'
                ? await query
                : null;
            if (userDoc && userDoc.selectedPlaceId !== undefined) {
              const selectedStr = userDoc.selectedPlaceId ? userDoc.selectedPlaceId.toString() : null;
              const rel = selectedStr && Array.isArray(userDoc.placeRelationships)
                ? userDoc.placeRelationships.find((r: any) => r.placeId === selectedStr)
                : null;
              effectiveSelectedPlaceId =
                rel && (rel.indigenousClassification === 'Indigenous' || rel.indigenousClassification === 'Non-Indigenous')
                  ? selectedStr
                  : null;
            }
            if (userDoc?.role === USER_ROLES.ADMIN) isUserAdmin = true;
          } catch (_) {}
        }
      }

      if (!isUserAdmin) {
        if (effectiveSelectedPlaceId === null) {
          throw new AuthorizationError(
            'No place selected. Guest / View-only mode does not allow creating claims.'
          );
        }
        if (effectiveSelectedPlaceId && effectiveSelectedPlaceId.toString() !== input.locationId.toString()) {
          throw new AuthorizationError(
            'Contributions must be scoped to the currently selected place ID.'
          );
        }
      }
    }
    const placeIdValue = leafPlace._id
      ? (mongoose.Types.ObjectId.isValid(leafPlace._id) ? new mongoose.Types.ObjectId(leafPlace._id) : leafPlace._id.toString())
      : (leafPlace.id
        ? (mongoose.Types.ObjectId.isValid(leafPlace.id) ? new mongoose.Types.ObjectId(leafPlace.id) : leafPlace.id)
        : input.locationId);

    if (input.consentState === 'consent_verified') {
      throw new AuthorizationError('Contributors cannot self-verify consent. Independent verification is required.');
    }

    // If topic is biography or personal living details, require consentDeclaration
    let initialConsentState: 'not_applicable' | 'pending_verification' | 'consent_verified' | 'consent_revoked' = 'not_applicable';
    if (input.communityTopic === 'biography' || input.category === 'PERSONAL_EXPERIENCE') {
      if (!input.consentObtained) {
        throw new BusinessRuleError(
          'Living-person biographies and identifiable personal information require explicit consent declaration.'
        );
      }
      // Contributor declaration does NOT mean verified consent. It sets consentState to pending_verification!
      initialConsentState = 'pending_verification';
    }

    const created = await this.claimRepo.create({
      title: input.title,
      body: input.body,
      category: input.category,
      status: CLAIM_STATUSES.DRAFT,
      locationId: placeIdValue,
      locationPath,
      submittedBy: userObjectId,
      tags: input.tags ?? [],
      isPublic: true,
      communityTopic: input.communityTopic,
      sourceAttribution: input.sourceAttribution,
      timePeriod: input.timePeriod,
      consentObtained: input.consentObtained ?? false,
      consentDetails: input.consentDetails,
      consentState: initialConsentState,
      userAgreementStatus: input.userAgreementStatus,
    });

    const claimId = created._id ? created._id.toString() : created.id;
    return await this.getClaimById(claimId, userId, USER_ROLES.CONTRIBUTOR, undefined, req);
  }

  /**
   * Retrieves claim details with authorization guards:
   * - Private drafts and pending-consent records are visible ONLY to author and reviewers/moderators.
   * - Submitter email and sensitive PII are strictly NEVER exposed.
   */
  async getClaimById(
    id: string,
    callerUserId?: string,
    callerRole?: UserRole,
    session?: ClientSession,
    req?: Request
  ): Promise<ClaimDetailResult> {
    const claim = await this.claimRepo.findById(id, session);
    if (!claim) {
      throw new NotFoundError('Claim');
    }

    // Access control via centralized, typed policy:
    assertCanReadClaim({ userId: callerUserId, role: callerRole } as any, claim);

    const claimId = claim._id ? claim._id.toString() : claim.id;
    const locationIdStr = claim.locationId.toString();
    const locationData: PlaceDetailResult = await this.placeServ.getPlaceById(locationIdStr, session, req);
    let latestRev = null;
    try {
      if (mongoose.connection.readyState === 1) {
        latestRev = await this.reviewRepo.findLatestByClaimId(claimId, session);
      }
    } catch {
      latestRev = null;
    }

    return {
      id: claimId,
      locationId: locationIdStr,
      title: claim.title,
      body: claim.body,
      category: claim.category,
      status: claim.status,
      location: locationData,
      submittedAt: claim.submittedAt ? claim.submittedAt.toISOString() : new Date().toISOString(),
      evidenceCount: claim.evidenceIds ? claim.evidenceIds.length : 0,
      latestReview: latestRev
        ? {
            id: latestRev._id ? latestRev._id.toString() : (latestRev as any).id,
            reviewerId: latestRev.reviewerId ? latestRev.reviewerId.toString() : null,
            decisionStatus: latestRev.decisionStatus,
            reason: latestRev.reason,
            timestamp: latestRev.timestamp ? latestRev.timestamp.toISOString() : new Date().toISOString(),
            reviewerNote: latestRev.reviewerNote ?? null,
          }
        : null,
      translations: [],
      tags: claim.tags || [],
      communityTopic: claim.communityTopic ?? null,
      sourceAttribution: claim.sourceAttribution ?? null,
      timePeriod: claim.timePeriod ?? null,
      consentObtained: claim.consentObtained ?? false,
      consentDetails: claim.consentDetails ?? null,
      consentState: claim.consentState ?? null,
      consentVerifiedBy: claim.consentVerifiedBy ? claim.consentVerifiedBy.toString() : null,
      consentVerifiedAt: claim.consentVerifiedAt ? claim.consentVerifiedAt.toISOString() : null,
      consentNotes: claim.consentNotes ?? null,
      userAgreementStatus: claim.userAgreementStatus ?? null,
      correctionRequests: (claim.correctionRequests || []).map((c: any) => ({
        id: c._id ? c._id.toString() : c.id,
        requestedBy: c.requestedBy ? c.requestedBy.toString() : null,
        reason: c.reason,
        proposedChanges: c.proposedChanges ?? null,
        status: c.status,
        reviewedBy: c.reviewedBy ? c.reviewedBy.toString() : null,
        reviewedAt: c.reviewedAt ? c.reviewedAt.toISOString() : null,
        reviewNotes: c.reviewNotes ?? null,
        createdAt: c.createdAt ? c.createdAt.toISOString() : null,
      })),
      communityFeedbacks: (claim.communityFeedbacks || []).map((f: any) => ({
        id: f._id ? f._id.toString() : f.id,
        userId: f.userId ? f.userId.toString() : '',
        previouslyKnown: f.previouslyKnown ?? null,
        agreement: f.agreement ?? null,
        comment: f.comment ?? null,
        knowsAuthor: f.knowsAuthor ?? null,
        createdAt: f.createdAt ? f.createdAt.toISOString() : new Date().toISOString(),
        updatedAt: f.updatedAt ? f.updatedAt.toISOString() : new Date().toISOString(),
      })),
    };
  }

  /**
   * Lists claims with optional filters, pagination, and draft isolation.
   * - Public list excludes drafts unless caller explicitly queries their own drafts.
   */
  async listClaims(
    query: QueryClaimsInput,
    callerUserId?: string,
    callerRole?: UserRole
  ): Promise<{ data: ClaimSummary[]; pagination: { page: number; limit: number; total: number; pages: number } }> {
    const isReviewerOrAdmin = callerRole && hasMinimumRole(callerRole, USER_ROLES.REVIEWER);
    const isSelfQuery = callerUserId && query.submittedBy === callerUserId;

    // If querying drafts, only allow if querying own drafts or if caller is reviewer/admin
    if (query.status === CLAIM_STATUSES.DRAFT && !isSelfQuery && !isReviewerOrAdmin) {
      throw new AuthorizationError('You can only retrieve your own drafts');
    }

    // Public browsing: exclude drafts, private claims, and unconsented living-person biographies
    // unless the caller is a reviewer/admin, or the caller is querying their own claims.
    const publicOnly = !(isReviewerOrAdmin || isSelfQuery);

    const { claims, total } = await this.claimRepo.list(
      {
        status: query.status,
        category: query.category,
        locationId: query.locationId,
        communityTopic: query.communityTopic,
        submittedBy: query.submittedBy,
        publicOnly,
      },
      {
        page: query.page,
        limit: query.limit,
      }
    );

    const data: ClaimSummary[] = claims.map((c) => ({
      id: c._id ? c._id.toString() : c.id,
      title: c.title,
      body: c.body,
      category: c.category,
      status: c.status,
      locationId: c.locationId.toString(),
      submittedAt: c.submittedAt ? c.submittedAt.toISOString() : new Date().toISOString(),
      submittedBy: c.submittedBy ? c.submittedBy.toString() : null,
      evidenceCount: c.evidenceIds ? c.evidenceIds.length : 0,
      communityTopic: c.communityTopic ?? null,
      sourceAttribution: c.sourceAttribution ?? null,
      timePeriod: c.timePeriod ?? null,
      consentObtained: c.consentObtained ?? false,
      consentState: c.consentState ?? null,
      userAgreementStatus: c.userAgreementStatus ?? null,
    }));

    const pages = Math.ceil(total / query.limit) || 1;

    return {
      data,
      pagination: {
        page: query.page,
        limit: query.limit,
        total,
        pages,
      },
    };
  }

  /**
   * Retrieves pending review queue for Reviewers / Admins.
   * - Shows claims with status 'submitted' or 'under_review' (or filter requested).
   * - Excludes drafts from review queue.
   */
  async getReviewQueue(
    query: QueryClaimsInput,
    reviewerId: string,
    reviewerRole: UserRole
  ): Promise<{ data: ClaimSummary[]; pagination: { page: number; limit: number; total: number; pages: number } }> {
    if (!hasMinimumRole(reviewerRole, USER_ROLES.REVIEWER)) {
      throw new AuthorizationError('Reviewer or Admin role required to access the review queue');
    }

    const statusFilter = query.status || { $in: [CLAIM_STATUSES.SUBMITTED, CLAIM_STATUSES.UNDER_REVIEW] };

    const { claims, total } = await this.claimRepo.list(
      {
        status: statusFilter as any,
        category: query.category,
        locationId: query.locationId,
        communityTopic: query.communityTopic,
        publicOnly: false,
      },
      {
        page: query.page,
        limit: query.limit,
      }
    );

    const data: ClaimSummary[] = claims.map((c) => ({
      id: c._id ? c._id.toString() : c.id,
      title: c.title,
      body: c.body,
      category: c.category,
      status: c.status,
      locationId: c.locationId.toString(),
      submittedAt: c.submittedAt ? c.submittedAt.toISOString() : new Date().toISOString(),
      submittedBy: c.submittedBy ? c.submittedBy.toString() : null,
      evidenceCount: c.evidenceIds ? c.evidenceIds.length : 0,
      communityTopic: c.communityTopic ?? null,
      sourceAttribution: c.sourceAttribution ?? null,
      timePeriod: c.timePeriod ?? null,
      consentObtained: c.consentObtained ?? false,
      consentState: c.consentState ?? null,
      userAgreementStatus: c.userAgreementStatus ?? null,
    }));

    const pages = Math.ceil(total / query.limit) || 1;

    return {
      data,
      pagination: {
        page: query.page,
        limit: query.limit,
        total,
        pages,
      },
    };
  }

  /**
   * Updates a draft claim.
   * Only the owner can edit, and only while in 'draft' status.
   */
  async updateClaim(
    id: string,
    input: UpdateClaimInput,
    userId: string,
    req?: Request
  ): Promise<ClaimDetailResult> {
    const claim = await this.claimRepo.findById(id);
    if (!claim) {
      throw new NotFoundError('Claim');
    }

    if (claim.submittedBy.toString() !== userId) {
      throw new AuthorizationError('Only the claim owner can edit this draft');
    }

    if (claim.status !== CLAIM_STATUSES.DRAFT) {
      throw new BusinessRuleError(
        'Only draft claims can be edited. Content is immutable after submission.'
      );
    }

    const updateFields: Record<string, any> = {};
    if (input.title) updateFields.title = input.title;
    if (input.body) updateFields.body = input.body;
    if (input.tags) updateFields.tags = input.tags;
    if (input.communityTopic !== undefined) updateFields.communityTopic = input.communityTopic;
    if (input.sourceAttribution !== undefined) updateFields.sourceAttribution = input.sourceAttribution;
    if (input.timePeriod !== undefined) updateFields.timePeriod = input.timePeriod;
    if (input.consentObtained !== undefined) {
      updateFields.consentObtained = input.consentObtained;
      if (input.consentObtained && (claim.communityTopic === 'biography' || input.communityTopic === 'biography')) {
        updateFields.consentState = 'pending_verification';
      }
    }
    if (input.consentDetails !== undefined) updateFields.consentDetails = input.consentDetails;
    if (input.consentState !== undefined) {
      if (input.consentState === 'consent_verified') {
        throw new AuthorizationError('Contributors cannot self-verify consent. Independent verification is required.');
      }
      throw new AuthorizationError('Contributors cannot self-verify consent. Independent verification is required.');
    }
    if (input.userAgreementStatus !== undefined) updateFields.userAgreementStatus = input.userAgreementStatus;

    await this.claimRepo.update(id, updateFields);
    return await this.getClaimById(id, userId, USER_ROLES.CONTRIBUTOR, undefined, req);
  }

  /**
   * Submits a claim for review (draft -> submitted).
   * - Exclusive submission endpoint.
   * - Preconditions: Owner check, draft status check, and mandatory consent verification for living persons.
   * - Atomic MongoDB Transaction: status change and auditLog entry commit together.
   *   If auditLog write fails, transaction rolls back completely.
   */
  async submitClaim(
    id: string,
    userId: string,
    ipAddress?: string | null
  ): Promise<{ status: string }> {
    return await this.claimRepo.withTransaction(async (session: ClientSession) => {
      const claim = await this.claimRepo.touch(id, session);
      if (!claim) {
        throw new NotFoundError('Claim');
      }

      if (claim.submittedBy.toString() !== userId) {
        throw new AuthorizationError('Only the claim owner can submit this claim');
      }

      if (claim.status !== CLAIM_STATUSES.DRAFT) {
        throw new BusinessRuleError('Claim is not in draft status');
      }

      // Safeguard: Check biography consent
      if (
        (claim.communityTopic === 'biography' || claim.category === 'PERSONAL_EXPERIENCE') &&
        !claim.consentObtained
      ) {
        throw new BusinessRuleError(
          'Cannot submit living-person biography without declared consent.'
        );
      }

      const beforeStatus = claim.status;
      const afterStatus = CLAIM_STATUSES.SUBMITTED;

      await this.claimRepo.update(
        id,
        {
          status: afterStatus,
          submittedAt: new Date(),
        },
        session
      );

      await this.auditServ.writeAuditLog(
        {
          entityType: 'claim',
          entityId: claim._id,
          actorId: userId,
          action: 'claim.submitted',
          before: { status: beforeStatus },
          after: { status: afterStatus },
          ipAddress: ipAddress ?? null,
        },
        session
      );

      return { status: afterStatus };
    });
  }

  /**
   * Soft-archives a claim (status -> archived).
   * - MODERATOR+ only.
   * - Atomic MongoDB Transaction: status change and auditLog entry commit together.
   */
  async archiveClaim(
    id: string,
    actorId: string,
    actorRole: UserRole,
    ipAddress?: string | null
  ): Promise<{ message: string }> {
    if (!hasMinimumRole(actorRole, USER_ROLES.MODERATOR)) {
      throw new AuthorizationError('Moderator or Admin role required to archive claims');
    }

    return await this.claimRepo.withTransaction(async (session: ClientSession) => {
      const claim = await this.claimRepo.touch(id, session);
      if (!claim) {
        throw new NotFoundError('Claim');
      }

      const beforeStatus = claim.status;
      const afterStatus = CLAIM_STATUSES.ARCHIVED;

      await this.claimRepo.update(
        id,
        {
          status: afterStatus,
        },
        session
      );

      await this.auditServ.writeAuditLog(
        {
          entityType: 'claim',
          entityId: claim._id,
          actorId,
          action: 'claim.archived',
          before: { status: beforeStatus },
          after: { status: afterStatus },
          ipAddress: ipAddress ?? null,
        },
        session
      );

      return { message: 'Claim archived' };
    });
  }

  /**
   * Submits a formal correction request against an existing claim.
   * - Does NOT silently overwrite verified facts.
   * - Transition to disputed or under_review for independent review.
   * - Persists audit trail.
   */
  async requestClaimCorrection(
    id: string,
    input: RequestCorrectionInput,
    userId: string,
    ipAddress?: string | null,
    userRole?: UserRole
  ): Promise<{ message: string; claimId: string; correctionId: string; status: string }> {
    return await this.claimRepo.withTransaction(async (session: ClientSession) => {
      const claim = await this.claimRepo.touch(id, session);
      if (!claim) {
        throw new NotFoundError('Claim');
      }

      // Cannot request correction on unpublished private draft
      if (claim.status === CLAIM_STATUSES.DRAFT) {
        throw new BusinessRuleError('Cannot submit correction requests against unsubmitted drafts.');
      }

      // Cannot request correction on archived or rejected claims
      if (claim.status === CLAIM_STATUSES.ARCHIVED || claim.status === CLAIM_STATUSES.REJECTED) {
        throw new BusinessRuleError(`Cannot submit correction requests against ${claim.status} claims.`);
      }

      // Authorization guard:
      // Only the claim submitter (owner) or an authorized reviewer can dispute a claim
      const isOwner = Boolean(claim.submittedBy && claim.submittedBy.toString() === userId);
      const isReviewer = Boolean(userRole && hasMinimumRole(userRole, USER_ROLES.REVIEWER));

      if (claim.submittedBy && !isOwner && !isReviewer) {
        throw new AuthorizationError(
          'Unauthorized: Only the claim submitter or an authorized reviewer can request a correction or dispute this claim.'
        );
      }

      const beforeStatus = claim.status;
      const newStatus = CLAIM_STATUSES.DISPUTED;
      const correctionId = new mongoose.Types.ObjectId();

      const newCorrection = {
        _id: correctionId,
        requestedBy: new mongoose.Types.ObjectId(userId),
        reason: input.reason.trim(),
        proposedChanges: input.proposedChanges ?? null,
        status: 'pending' as const,
        createdAt: new Date(),
      };

      await this.claimRepo.update(
        id,
        {
          status: newStatus,
          userAgreementStatus: 'correction',
          $push: { correctionRequests: newCorrection },
        },
        session
      );

      await this.auditServ.writeAuditLog(
        {
          entityType: 'claim',
          entityId: claim._id,
          actorId: userId,
          action: 'claim.correction_requested',
          before: { status: beforeStatus },
          after: {
            correctionId: correctionId.toString(),
            status: newStatus,
            reason: input.reason,
            proposedChanges: input.proposedChanges ?? null,
          },
          ipAddress: ipAddress ?? null,
        },
        session
      );

      return {
        message: 'Correction request submitted successfully and queued for independent review.',
        claimId: id,
        correctionId: correctionId.toString(),
        status: newStatus,
      };
    });
  }

  /**
   * Reviews a pending correction request against a claim.
   * - Authorized reviewers / moderators only.
   * - Contributor cannot review their own correction request (Self-review prohibition).
   * - Records review outcome (accepted/rejected), review notes, reviewer, timestamp.
   * - Preserves the original claim and records audit trail.
   */
  async reviewClaimCorrection(
    id: string,
    correctionId: string,
    input: ReviewCorrectionInput,
    reviewerId: string,
    reviewerRole: UserRole,
    ipAddress?: string | null
  ): Promise<{ message: string; claimId: string; correctionId: string; status: string; claimStatus: string }> {
    if (!hasMinimumRole(reviewerRole, USER_ROLES.REVIEWER)) {
      throw new AuthorizationError('Requires REVIEWER role or higher to review correction requests');
    }

    return await this.claimRepo.withTransaction(async (session: ClientSession) => {
      const claim = await this.claimRepo.touch(id, session);
      if (!claim) {
        throw new NotFoundError('Claim');
      }

      const correction = (claim.correctionRequests || []).find(
        (c: any) => c._id.toString() === correctionId
      );
      if (!correction) {
        throw new NotFoundError('CorrectionRequest');
      }

      // STRICT RULE: Self-review prohibited - requester cannot approve their own correction
      if (correction.requestedBy.toString() === reviewerId) {
        throw new SelfReviewError();
      }

      if (correction.status !== 'pending') {
        throw new BusinessRuleError('Correction request has already been reviewed');
      }

      const beforeCorrectionStatus = correction.status;
      const beforeClaimStatus = claim.status;

      correction.status = input.decision;
      correction.reviewedBy = new mongoose.Types.ObjectId(reviewerId);
      correction.reviewedAt = new Date();
      correction.reviewNotes = input.reviewNotes.trim();

      // If accepted, keep original claim preserved but resolve dispute to verified
      // If rejected, dispute is dismissed and claim restored to verified
      const afterClaimStatus = CLAIM_STATUSES.VERIFIED;

      await this.claimRepo.update(
        id,
        {
          correctionRequests: claim.correctionRequests,
          status: afterClaimStatus,
          userAgreementStatus: input.decision === 'accepted' ? 'correction' : 'agreed',
        },
        session
      );

      await this.auditServ.writeAuditLog(
        {
          entityType: 'claim',
          entityId: claim._id,
          actorId: reviewerId,
          action: 'claim.correction_reviewed',
          before: {
            correctionId,
            correctionStatus: beforeCorrectionStatus,
            claimStatus: beforeClaimStatus,
          },
          after: {
            correctionId,
            correctionStatus: input.decision,
            reviewNotes: input.reviewNotes,
            claimStatus: afterClaimStatus,
          },
          ipAddress: ipAddress ?? null,
        },
        session
      );

      return {
        message: `Correction request ${input.decision} successfully.`,
        claimId: id,
        correctionId,
        status: input.decision,
        claimStatus: afterClaimStatus,
      };
    });
  }

  /**
   * Retrieves all correction requests for a claim.
   */
  async getClaimCorrections(
    id: string,
    callerUserId?: string,
    callerRole?: UserRole
  ): Promise<any[]> {
    const claim = await this.claimRepo.findById(id);
    if (!claim) {
      throw new NotFoundError('Claim');
    }

    assertCanReadClaim({ userId: callerUserId, role: callerRole } as any, claim);

    return (claim.correctionRequests || []).map((c: any) => ({
      id: c._id ? c._id.toString() : c.id,
      requestedBy: c.requestedBy ? c.requestedBy.toString() : null,
      reason: c.reason,
      proposedChanges: c.proposedChanges ?? null,
      status: c.status,
      reviewedBy: c.reviewedBy ? c.reviewedBy.toString() : null,
      reviewedAt: c.reviewedAt ? c.reviewedAt.toISOString() : null,
      reviewNotes: c.reviewNotes ?? null,
      createdAt: c.createdAt ? c.createdAt.toISOString() : null,
    }));
  }

  /**
   * Independently verifies or revokes consent for a living-person biography or sensitive personal record.
   * - Authorized reviewers / moderators only.
   * - Contributors cannot self-verify (Self-review prohibition).
   * - Records verifier, timestamp, outcome, and notes.
   * - Writes immutable audit log.
   */
  async verifyClaimConsent(
    id: string,
    input: VerifyConsentInput,
    verifierId: string,
    verifierRole: UserRole,
    ipAddress?: string | null
  ): Promise<ClaimDetailResult> {
    if (!hasMinimumRole(verifierRole, USER_ROLES.REVIEWER)) {
      throw new AuthorizationError('Requires REVIEWER role or higher to verify or revoke consent');
    }

    return await this.claimRepo.withTransaction(async (session: ClientSession) => {
      const claim = await this.claimRepo.touch(id, session);
      if (!claim) {
        throw new NotFoundError('Claim');
      }

      // Contributor cannot self-verify consent
      if (claim.submittedBy.toString() === verifierId) {
        throw new SelfReviewError();
      }

      const previousConsentState = claim.consentState || 'not_applicable';

      const updateData: Record<string, any> = {
        consentState: input.consentState,
        consentVerifiedBy: new mongoose.Types.ObjectId(verifierId),
        consentVerifiedAt: new Date(),
        consentNotes: input.notes ? input.notes.trim() : null,
      };

      // If revoked, ensure claim is not publicly listed or verified
      if (input.consentState === 'consent_revoked') {
        updateData.isPublic = false;
        if (claim.status === CLAIM_STATUSES.VERIFIED) {
          updateData.status = CLAIM_STATUSES.DISPUTED;
        }
      }

      await this.claimRepo.update(id, updateData, session);

      await this.auditServ.writeAuditLog(
        {
          entityType: 'claim',
          entityId: claim._id,
          actorId: verifierId,
          action: input.consentState === 'consent_verified' ? 'claim.consent_verified' : 'claim.consent_revoked',
          before: { consentState: previousConsentState },
          after: {
            consentState: input.consentState,
            notes: input.notes ?? null,
          },
          ipAddress: ipAddress ?? null,
        },
        session
      );

      return await this.getClaimById(id, verifierId, verifierRole, session);
    });
  }

  /**
   * Reviews a submitted claim (reviewer-controlled verification).
   * Authorized reviewers / moderators only.
   * Contributor cannot review their own claim (Self-review prohibition).
   * Enforces Information Classes integrity:
   * - Folklore and Opinions can never be verified as historical facts.
   * - Living person biographies cannot be verified while consent is pending/revoked.
   * Delegates atomically to VerificationService with audit logging.
   */
  async reviewClaim(
    id: string,
    input: ReviewClaimInput,
    reviewerId: string,
    reviewerRole: UserRole,
    ipAddress?: string | null
  ): Promise<any> {
    if (!hasMinimumRole(reviewerRole, USER_ROLES.REVIEWER)) {
      throw new AuthorizationError('Requires REVIEWER role or higher to review claims');
    }
    return await this.verificationServ.submitReview(
      {
        claimId: id,
        decisionStatus: input.decisionStatus,
        reason: input.reason,
        sourcesConsidered: input.sourcesConsidered,
        reviewerNote: input.reviewerNote,
      },
      reviewerId,
      ipAddress
    );
  }

  /**
   * Submits or updates community feedback on a history claim.
   * Requirement 4:
   * - "क्या आप पहले इसके बारे में जानते थे?" — previouslyKnown
   * - "क्या आप इस जानकारी से सहमत हैं?" — agreement
   * - "क्या आप इस पर कुछ लिखना चाहेंगे?" — comment
   * - "क्या आप इस जानकारी के लेखक को जानते हैं?" — knowsAuthor
   * Rules:
   * - Authenticated user scoped.
   * - One feedback entry per user per claim (upserted idempotently).
   * - Cannot provide feedback on unapproved/private drafts.
   * - Author opinion is kept separate as community feedback, not historical proof.
   */
  async submitHistoryFeedback(
    claimId: string,
    input: SubmitHistoryFeedbackInput,
    userId: string,
    userRole?: UserRole
  ): Promise<any> {
    const claim = await this.claimRepo.findById(claimId);
    if (!claim) {
      throw new NotFoundError('Claim');
    }

    // Must be permitted to read the claim
    assertCanReadClaim({ userId, role: userRole } as any, claim);

    // Feedback can only be submitted on published/approved claims, never on unverified, pending, rejected, or private claims
    if (!claim.isPublic || (claim.status !== CLAIM_STATUSES.VERIFIED && claim.status !== CLAIM_STATUSES.PARTIALLY_VERIFIED)) {
      throw new BusinessRuleError('Feedback can only be submitted on approved and published claims');
    }

    const feedbacks = claim.communityFeedbacks || [];
    const existingIndex = feedbacks.findIndex(
      (f: any) => f.userId && f.userId.toString() === userId
    );

    const now = new Date();
    if (existingIndex >= 0) {
      const existing = feedbacks[existingIndex];
      if (input.previouslyKnown !== undefined) existing.previouslyKnown = input.previouslyKnown;
      if (input.agreement !== undefined) existing.agreement = input.agreement;
      if (input.comment !== undefined) existing.comment = input.comment;
      if (input.knowsAuthor !== undefined) existing.knowsAuthor = input.knowsAuthor;
      existing.updatedAt = now;
      feedbacks[existingIndex] = existing;
    } else {
      feedbacks.push({
        _id: new mongoose.Types.ObjectId(),
        userId: new mongoose.Types.ObjectId(userId),
        previouslyKnown: input.previouslyKnown ?? null,
        agreement: input.agreement ?? null,
        comment: input.comment ?? null,
        knowsAuthor: input.knowsAuthor ?? null,
        createdAt: now,
        updatedAt: now,
      } as any);
    }

    await this.claimRepo.update(claimId, { communityFeedbacks: feedbacks });

    return {
      message: 'Feedback submitted successfully',
      claimId,
      feedback: feedbacks.find((f: any) => f.userId.toString() === userId),
    };
  }
}

export const claimService = new ClaimService();
