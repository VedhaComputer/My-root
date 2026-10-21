import { ClientSession } from 'mongoose';
import { ReviewRepository, reviewRepository } from './repository';
import { ClaimRepository, claimRepository } from '../claims/repository';
import { AuditService, auditService } from '../audit/audit.service';
import { SubmitReviewInput } from './validation';
import { NotFoundError, SelfReviewError, BusinessRuleError } from '../../shared/errors/AppError';
import { CLAIM_STATUSES } from '../../shared/constants';
import { IReview } from './review.model';
import { assertCanReadClaim } from '../claims/authorization';
import { AuthenticatedUser } from '../../shared/types';

export class VerificationService {
  constructor(
    private reviewRepo: ReviewRepository = reviewRepository,
    private claimRepo: ClaimRepository = claimRepository,
    private auditServ: AuditService = auditService
  ) {}

  async submitReview(
    input: SubmitReviewInput,
    reviewerId: string,
    ipAddress?: string | null
  ): Promise<IReview> {
    return await this.claimRepo.withTransaction(async (session: ClientSession) => {
      const claim = await this.claimRepo.touch(input.claimId, session);
      if (!claim) {
        throw new NotFoundError('Claim');
      }

      // STRICT RULE: Self-review prohibited
      if (claim.submittedBy.toString() === reviewerId) {
        throw new SelfReviewError();
      }

      // Only submitted or under_review claims can be reviewed
      if (claim.status === CLAIM_STATUSES.DRAFT) {
        throw new BusinessRuleError('Draft claims cannot be reviewed until submitted');
      }

      // RULE 2: Enforce the Four Information Classes correctly:
      // - Folklore / Oral History must NEVER be marked as verified historical fact
      // - Opinions must NEVER enter verified fact status
      if (input.decisionStatus === CLAIM_STATUSES.VERIFIED) {
        if (claim.category === 'FOLKLORE') {
          throw new BusinessRuleError(
            'Folklore and oral traditions cannot be marked as verified historical facts. They represent cultural heritage, not independently verified fact.'
          );
        }
        if (claim.category === 'PUBLIC_OPINION') {
          throw new BusinessRuleError(
            'Public opinions and perspectives cannot be marked as verified facts.'
          );
        }
        // Living person biographies CANNOT be published as verified facts while consent is pending or revoked
        if (
          (claim.communityTopic === 'biography' || claim.category === 'PERSONAL_EXPERIENCE') &&
          claim.consentState !== 'consent_verified' &&
          claim.consentState !== 'not_applicable'
        ) {
          throw new BusinessRuleError(
            'Cannot verify a living-person biography while consent remains pending verification or revoked.'
          );
        }
      }

      const previousStatus = claim.status;
      const newStatus = input.decisionStatus; // e.g. verified, disputed, unverified, etc.

      const review = await this.reviewRepo.create(
        {
          ...input,
          reviewerId,
          previousStatus,
        },
        session
      );

      // Transition claim status to reviewer's decision
      await this.claimRepo.update(
        input.claimId,
        {
          status: newStatus,
        },
        session
      );

      await this.auditServ.writeAuditLog(
        {
          entityType: 'review',
          entityId: review._id,
          actorId: reviewerId,
          action: 'claim.reviewed',
          before: { status: previousStatus },
          after: { status: newStatus, decisionStatus: input.decisionStatus },
          ipAddress: ipAddress ?? null,
        },
        session
      );

      return review;
    });
  }

  async getReviewsForClaim(
    claimId: string,
    user?: AuthenticatedUser | null
  ): Promise<IReview[]> {
    const claim = await this.claimRepo.findById(claimId);
    if (!claim) {
      throw new NotFoundError('Claim');
    }
    assertCanReadClaim(user, claim);
    return await this.reviewRepo.findByClaimId(claimId);
  }
}

export const verificationService = new VerificationService();
