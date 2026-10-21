export const USER_ROLES = {
  GUEST: 'GUEST',
  CONTRIBUTOR: 'CONTRIBUTOR',
  LOCAL_CONTRIBUTOR: 'LOCAL_CONTRIBUTOR',
  REVIEWER: 'REVIEWER',
  MODERATOR: 'MODERATOR',
  ADMIN: 'ADMIN',
} as const;

export type UserRole = (typeof USER_ROLES)[keyof typeof USER_ROLES];

export const CLAIM_STATUSES = {
  DRAFT: 'draft',
  SUBMITTED: 'submitted',
  UNDER_REVIEW: 'under_review',
  VERIFIED: 'verified',
  PARTIALLY_VERIFIED: 'partially_verified',
  UNVERIFIED: 'unverified',
  DISPUTED: 'disputed',
  INSUFFICIENT_EVIDENCE: 'insufficient_evidence',
  REJECTED: 'rejected',
  ARCHIVED: 'archived',
} as const;

export type ClaimStatus = (typeof CLAIM_STATUSES)[keyof typeof CLAIM_STATUSES];

export const CLAIM_CATEGORIES = {
  HISTORICAL_RECORD: 'HISTORICAL_RECORD',
  CURRENT_FACT: 'CURRENT_FACT',
  FOLKLORE: 'FOLKLORE',
  PERSONAL_EXPERIENCE: 'PERSONAL_EXPERIENCE',
  PUBLIC_OPINION: 'PUBLIC_OPINION',
  SURVEY_DATA: 'SURVEY_DATA',
  DISPUTED_CLAIM: 'DISPUTED_CLAIM',
} as const;

export type ClaimCategory = (typeof CLAIM_CATEGORIES)[keyof typeof CLAIM_CATEGORIES];

export const PLACE_LEVELS = {
  COUNTRY: 'COUNTRY',
  STATE: 'STATE',
  DISTRICT: 'DISTRICT',
  TEHSIL: 'TEHSIL',
  CITY_TOWN: 'CITY_TOWN',
  VILLAGE: 'VILLAGE',
} as const;

export type PlaceLevel = (typeof PLACE_LEVELS)[keyof typeof PLACE_LEVELS];

export const REVIEW_DECISIONS = [
  'verified',
  'partially_verified',
  'unverified',
  'disputed',
  'insufficient_evidence',
  'rejected',
] as const;

export type ReviewDecision = (typeof REVIEW_DECISIONS)[number];

export const EVIDENCE_SOURCE_TYPES = [
  'DOCUMENT',
  'URL',
  'PHOTOGRAPH',
  'ORAL_TESTIMONY',
  'GOVERNMENT_RECORD',
  'ACADEMIC_PAPER',
  'NEWS_ARTICLE',
  'OTHER',
] as const;

export type EvidenceSourceType = (typeof EVIDENCE_SOURCE_TYPES)[number];

export const ROLE_HIERARCHY: Record<UserRole, number> = {
  GUEST: 0,
  CONTRIBUTOR: 1,
  LOCAL_CONTRIBUTOR: 2,
  REVIEWER: 3,
  MODERATOR: 4,
  ADMIN: 5,
};

export function hasMinimumRole(userRole: UserRole, minimumRole: UserRole): boolean {
  return ROLE_HIERARCHY[userRole] >= ROLE_HIERARCHY[minimumRole];
}
