import { canReadClaim, assertCanReadClaim, ClaimAuthSubject } from '../../../../src/modules/claims/authorization';
import { USER_ROLES, CLAIM_STATUSES } from '../../../../src/shared/constants';
import { AuthorizationError } from '../../../../src/shared/errors/AppError';

describe('Central Claim Authorization Policy (canReadClaim & assertCanReadClaim)', () => {
  const ownerUser = {
    userId: 'user-owner-101',
    role: USER_ROLES.CONTRIBUTOR,
  };

  const otherContributor = {
    userId: 'user-stranger-202',
    role: USER_ROLES.CONTRIBUTOR,
  };

  const reviewerUser = {
    userId: 'user-reviewer-303',
    role: USER_ROLES.REVIEWER,
  };

  const adminUser = {
    userId: 'user-admin-404',
    role: USER_ROLES.ADMIN,
  };

  const guestUser = {
    userId: 'user-guest-505',
    role: USER_ROLES.GUEST,
  };

  describe('Null or undefined subjects', () => {
    it('returns false when claim is null or undefined', () => {
      expect(canReadClaim(ownerUser, null)).toBe(false);
      expect(canReadClaim(ownerUser, undefined)).toBe(false);
    });

    it('throws AuthorizationError when asserting access on null claim', () => {
      expect(() => assertCanReadClaim(ownerUser, null)).toThrow(AuthorizationError);
    });
  });

  describe('Draft Claims', () => {
    const draftClaim: ClaimAuthSubject = {
      id: 'claim-draft-1',
      status: CLAIM_STATUSES.DRAFT,
      submittedBy: 'user-owner-101',
      isPublic: true,
    };

    it('allows the owner to read their own draft claim', () => {
      expect(canReadClaim(ownerUser, draftClaim)).toBe(true);
      expect(() => assertCanReadClaim(ownerUser, draftClaim)).not.toThrow();
    });

    it('prohibits another contributor from reading cross-user drafts', () => {
      expect(canReadClaim(otherContributor, draftClaim)).toBe(false);
      expect(() => assertCanReadClaim(otherContributor, draftClaim)).toThrow(AuthorizationError);
      expect(() => assertCanReadClaim(otherContributor, draftClaim)).toThrow(
        'Private drafts are only accessible by the owner or authorized reviewers'
      );
    });

    it('allows reviewers and admins to read drafts for review queue / moderation', () => {
      expect(canReadClaim(reviewerUser, draftClaim)).toBe(true);
      expect(canReadClaim(adminUser, draftClaim)).toBe(true);
      expect(() => assertCanReadClaim(reviewerUser, draftClaim)).not.toThrow();
      expect(() => assertCanReadClaim(adminUser, draftClaim)).not.toThrow();
    });

    it('denies unauthenticated or guest callers', () => {
      expect(canReadClaim(null, draftClaim)).toBe(false);
      expect(canReadClaim(guestUser, draftClaim)).toBe(false);
      expect(() => assertCanReadClaim(null, draftClaim)).toThrow(AuthorizationError);
    });
  });

  describe('Confidential Living-Person Biographies (Pending/Revoked Consent)', () => {
    const pendingBioClaim: ClaimAuthSubject = {
      id: 'claim-bio-1',
      status: CLAIM_STATUSES.SUBMITTED,
      submittedBy: 'user-owner-101',
      category: 'PERSONAL_EXPERIENCE',
      communityTopic: 'biography',
      consentState: 'pending_verification',
      isPublic: true,
    };

    const revokedBioClaim: ClaimAuthSubject = {
      id: 'claim-bio-2',
      status: CLAIM_STATUSES.DISPUTED,
      submittedBy: 'user-owner-101',
      category: 'PERSONAL_EXPERIENCE',
      communityTopic: 'biography',
      consentState: 'consent_revoked',
      isPublic: false,
    };

    it('allows owner to read pending living-person biography', () => {
      expect(canReadClaim(ownerUser, pendingBioClaim)).toBe(true);
      expect(() => assertCanReadClaim(ownerUser, pendingBioClaim)).not.toThrow();
    });

    it('allows reviewer and admin to read pending biography to inspect consent documentation', () => {
      expect(canReadClaim(reviewerUser, pendingBioClaim)).toBe(true);
      expect(canReadClaim(adminUser, pendingBioClaim)).toBe(true);
    });

    it('prohibits third-party contributor from viewing unconsented biography', () => {
      expect(canReadClaim(otherContributor, pendingBioClaim)).toBe(false);
      expect(() => assertCanReadClaim(otherContributor, pendingBioClaim)).toThrow(AuthorizationError);
      expect(() => assertCanReadClaim(otherContributor, pendingBioClaim)).toThrow(
        'This living-person biography is confidential and pending independent consent verification.'
      );
    });

    it('prohibits third-party contributor from viewing revoked consent biography', () => {
      expect(canReadClaim(otherContributor, revokedBioClaim)).toBe(false);
      expect(() => assertCanReadClaim(otherContributor, revokedBioClaim)).toThrow(AuthorizationError);
    });

    it('allows public read once consent is verified', () => {
      const verifiedBioClaim: ClaimAuthSubject = {
        ...pendingBioClaim,
        consentState: 'consent_verified',
      };
      expect(canReadClaim(otherContributor, verifiedBioClaim)).toBe(true);
      expect(() => assertCanReadClaim(otherContributor, verifiedBioClaim)).not.toThrow();
    });
  });

  describe('Private / Non-Public Claims', () => {
    const nonPublicClaim: ClaimAuthSubject = {
      id: 'claim-private-1',
      status: CLAIM_STATUSES.SUBMITTED,
      submittedBy: 'user-owner-101',
      isPublic: false,
    };

    it('allows owner to access their private non-public claim', () => {
      expect(canReadClaim(ownerUser, nonPublicClaim)).toBe(true);
    });

    it('allows reviewer and admin to access private claim for audit/moderation', () => {
      expect(canReadClaim(reviewerUser, nonPublicClaim)).toBe(true);
      expect(canReadClaim(adminUser, nonPublicClaim)).toBe(true);
    });

    it('blocks general contributors from reading non-public claims', () => {
      expect(canReadClaim(otherContributor, nonPublicClaim)).toBe(false);
      expect(() => assertCanReadClaim(otherContributor, nonPublicClaim)).toThrow(AuthorizationError);
    });
  });

  describe('Public Verified Claims', () => {
    const publicVerifiedClaim: ClaimAuthSubject = {
      id: 'claim-pub-1',
      status: CLAIM_STATUSES.VERIFIED,
      submittedBy: 'user-owner-101',
      category: 'HISTORICAL_RECORD',
      isPublic: true,
    };

    it('is readable by owner, other contributors, reviewers, and admins', () => {
      expect(canReadClaim(ownerUser, publicVerifiedClaim)).toBe(true);
      expect(canReadClaim(otherContributor, publicVerifiedClaim)).toBe(true);
      expect(canReadClaim(reviewerUser, publicVerifiedClaim)).toBe(true);
      expect(canReadClaim(adminUser, publicVerifiedClaim)).toBe(true);
    });
  });
});
