import { USER_ROLES, UserRole, CLAIM_STATUSES, hasMinimumRole } from '../../shared/constants';
import { AuthenticatedUser } from '../../shared/types';
import { AuthorizationError } from '../../shared/errors/AppError';

export interface ClaimAuthSubject {
  id?: string;
  _id?: any;
  status: string;
  submittedBy: any;
  isPublic?: boolean;
  communityTopic?: string | null;
  category?: string;
  consentState?: 'not_applicable' | 'pending_verification' | 'consent_verified' | 'consent_revoked' | string | null;
}

/**
 * Single, central, typed authorization policy function for determining whether
 * a user is permitted to read a given claim and its associated artifacts (evidence, reviews, corrections).
 *
 * Rules:
 * 1. Draft claims are private and accessible ONLY to the claim owner or authorized reviewers/moderators/admins.
 * 2. Living person biographies / personal experiences with unverified or revoked consent are confidential
 *    and accessible ONLY to the claim owner or authorized reviewers/moderators/admins.
 * 3. Soft-archived claims or non-public claims are restricted to owner or reviewers/moderators/admins.
 * 4. Published, verified/consented, public claims are readable by any authenticated user.
 */
export function canReadClaim(
  user?: AuthenticatedUser | { userId?: string; role?: UserRole } | null,
  claim?: ClaimAuthSubject | null
): boolean {
  if (!claim) {
    return false;
  }

  const userId = user?.userId;
  const userRole = user?.role;

  // Determine owner match safely comparing string representations
  const claimOwnerId = claim.submittedBy ? claim.submittedBy.toString() : '';
  const isOwner = Boolean(userId && claimOwnerId && userId === claimOwnerId);

  // Reviewers, Moderators, Admins have privileged read access
  const isReviewerOrAdmin = Boolean(
    userRole && hasMinimumRole(userRole, USER_ROLES.REVIEWER)
  );

  // 1. Private draft claims
  if (claim.status === CLAIM_STATUSES.DRAFT) {
    return isOwner || isReviewerOrAdmin;
  }

  // 2. Confidential living-person biographies / personal experiences pending or revoked consent
  const isRestrictedBiography =
    (claim.communityTopic === 'biography' || claim.category === 'PERSONAL_EXPERIENCE') &&
    claim.consentState !== 'consent_verified';

  if (isRestrictedBiography) {
    return isOwner || isReviewerOrAdmin;
  }

  // 3. Private / Non-public claims
  if (claim.isPublic === false) {
    return isOwner || isReviewerOrAdmin;
  }

  // Public active claims are readable
  return true;
}

/**
 * Asserts that the user can read the claim; throws AuthorizationError if not permitted.
 */
export function assertCanReadClaim(
  user?: AuthenticatedUser | { userId?: string; role?: UserRole } | null,
  claim?: ClaimAuthSubject | null,
  customMessage?: string
): void {
  if (!claim) {
    throw new AuthorizationError(customMessage || 'Claim access denied');
  }

  if (!canReadClaim(user, claim)) {
    if (claim.status === CLAIM_STATUSES.DRAFT) {
      throw new AuthorizationError(
        customMessage || 'Private drafts are only accessible by the owner or authorized reviewers'
      );
    }
    const isRestrictedBiography =
      (claim.communityTopic === 'biography' || claim.category === 'PERSONAL_EXPERIENCE') &&
      claim.consentState !== 'consent_verified';

    if (isRestrictedBiography) {
      throw new AuthorizationError(
        customMessage || 'This living-person biography is confidential and pending independent consent verification.'
      );
    }

    throw new AuthorizationError(customMessage || 'Insufficient permissions to view this claim');
  }
}
