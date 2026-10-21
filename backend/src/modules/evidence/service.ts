import mongoose, { ClientSession } from 'mongoose';
import { EvidenceRepository, evidenceRepository } from './repository';
import { ClaimRepository, claimRepository } from '../claims/repository';
import { AuditService, auditService } from '../audit/audit.service';
import { CreateEvidenceInput, ReviewEvidenceInput } from './validation';
import { NotFoundError, AuthorizationError, SelfReviewError, BusinessRuleError } from '../../shared/errors/AppError';
import { USER_ROLES, UserRole, hasMinimumRole } from '../../shared/constants';
import { IEvidence } from './evidence.model';
import { assertCanReadClaim } from '../claims/authorization';
import { AuthenticatedUser } from '../../shared/types';

export class EvidenceService {
  constructor(
    private evidenceRepo: EvidenceRepository = evidenceRepository,
    private claimRepo: ClaimRepository = claimRepository,
    private auditServ: AuditService = auditService
  ) {}

  async submitEvidence(
    input: CreateEvidenceInput,
    userId: string,
    ipAddress?: string | null
  ): Promise<IEvidence> {
    // ── Pre-check (read-only, outside the transaction) ────────────────────────
    // Validate claim eligibility BEFORE acquiring a write lock via touch().
    // This prevents a spurious __v increment on ineligible claims: touch() uses
    // findByIdAndUpdate($inc: __v), which is a real write even if the subsequent
    // precondition check would abort the transaction.  By reading the claim
    // state first, touch() is only called when the claim is confirmed eligible.
    const preClaim = await this.claimRepo.findById(input.claimId);
    if (!preClaim) {
      throw new NotFoundError('Claim');
    }

    // INTEGRITY RULE: Evidence may only be attached to claims that are open
    // for contribution. Rejected and archived claims are closed records whose
    // evidence set must remain immutable to preserve traceability.
    // A draft claim can only receive evidence from its own owner —
    // other contributors cannot discover or attach evidence to another user's
    // unsubmitted draft.
    const closedStatuses = [
      'rejected',
      'archived',
    ] as const;

    if ((closedStatuses as readonly string[]).includes(preClaim.status)) {
      throw new BusinessRuleError(
        `Evidence cannot be submitted against a claim with status '${preClaim.status}'. ` +
        `Only active claims (submitted, under_review, verified, disputed, etc.) accept new evidence.`
      );
    }

    if (preClaim.status === 'draft' && preClaim.submittedBy.toString() !== userId) {
      throw new AuthorizationError(
        'Evidence cannot be attached to another contributor\'s unsubmitted draft claim.'
      );
    }

    // ── Transactional write (only reached when preconditions pass) ────────────
    return await this.claimRepo.withTransaction(async (session: ClientSession) => {
      // touch() acquires the exclusive WiredTiger write lock by incrementing
      // __v within the session. A second null check guards the window between
      // the pre-check read and transaction write where the claim might have been
      // deleted.
      const claim = await this.claimRepo.touch(input.claimId, session);
      if (!claim) {
        throw new NotFoundError('Claim');
      }

      // ── Concurrency Gate (Transaction-Safe State Re-Validation) ─────────────
      // Once touch() acquires the exclusive write lock in WiredTiger, re-validate
      // the authoritative status and ownership on the locked document.
      // This closes the TOCTOU race condition: if a concurrent review or moderator
      // action transitioned the claim to 'rejected' or 'archived' between the
      // initial findById() and touch(), this check aborts the transaction immediately,
      // preventing any evidence creation or reference update on a closed claim.
      if ((closedStatuses as readonly string[]).includes(claim.status)) {
        throw new BusinessRuleError(
          `Evidence cannot be submitted against a claim with status '${claim.status}'. ` +
          `Only active claims (submitted, under_review, verified, disputed, etc.) accept new evidence.`
        );
      }

      if (claim.status === 'draft' && claim.submittedBy.toString() !== userId) {
        throw new AuthorizationError(
          'Evidence cannot be attached to another contributor\'s unsubmitted draft claim.'
        );
      }

      const evidence = await this.evidenceRepo.create(
        { ...input, uploadedBy: userId },
        session
      );

      // Append evidenceId to claim
      await this.claimRepo.update(
        input.claimId,
        {
          $push: { evidenceIds: evidence._id },
        },
        session
      );

      await this.auditServ.writeAuditLog(
        {
          entityType: 'evidence',
          entityId: evidence._id,
          actorId: userId,
          action: 'evidence.created',
          before: null,
          after: { claimId: input.claimId, sourceType: input.sourceType, title: input.title },
          ipAddress: ipAddress ?? null,
        },
        session
      );

      return evidence;
    });
  }


  async getEvidenceForClaim(
    claimId: string,
    user?: AuthenticatedUser | null
  ): Promise<IEvidence[]> {
    const claim = await this.claimRepo.findById(claimId);
    if (!claim) {
      throw new NotFoundError('Claim');
    }
    assertCanReadClaim(user, claim);
    return await this.evidenceRepo.findByClaimId(claimId);
  }

  async getEvidenceById(
    id: string,
    user?: AuthenticatedUser | null
  ): Promise<IEvidence> {
    const evidence = await this.evidenceRepo.findById(id);
    if (!evidence) {
      throw new NotFoundError('Evidence');
    }
    const claim = await this.claimRepo.findById(evidence.claimId.toString());
    if (!claim) {
      throw new NotFoundError('Claim');
    }
    assertCanReadClaim(user, claim);
    return evidence;
  }

  /**
   * Reviews submitted evidence (reviewer-controlled).
   * - Requires REVIEWER or higher.
   * - Self-review prohibited.
   * - Does NOT automatically mark parent claim verified.
   */
  async reviewEvidence(
    id: string,
    input: ReviewEvidenceInput,
    reviewerId: string,
    reviewerRole: UserRole,
    ipAddress?: string | null
  ): Promise<IEvidence> {
    if (!hasMinimumRole(reviewerRole, USER_ROLES.REVIEWER)) {
      throw new AuthorizationError('Requires REVIEWER role or higher to review evidence');
    }

    return await this.claimRepo.withTransaction(async (session: ClientSession) => {
      const evidence = await this.evidenceRepo.findById(id, session);
      if (!evidence) {
        throw new NotFoundError('Evidence');
      }

      // STRICT RULE: Self-review prohibited - uploader cannot review their own evidence
      if (evidence.uploadedBy.toString() === reviewerId) {
        throw new SelfReviewError();
      }

      const previousStatus = evidence.status;
      const updated = await this.evidenceRepo.update(
        id,
        {
          status: input.decision,
          reviewedBy: new mongoose.Types.ObjectId(reviewerId),
          reviewedAt: new Date(),
          reviewNotes: input.reviewNotes.trim(),
        },
        session
      );

      await this.auditServ.writeAuditLog(
        {
          entityType: 'evidence',
          entityId: evidence._id,
          actorId: reviewerId,
          action: 'evidence.reviewed',
          before: { status: previousStatus },
          after: { status: input.decision, reviewNotes: input.reviewNotes.trim() },
          ipAddress: ipAddress ?? null,
        },
        session
      );

      return updated!;
    });
  }
}

export const evidenceService = new EvidenceService();
