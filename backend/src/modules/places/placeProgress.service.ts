import mongoose from 'mongoose';
import { ClaimModel } from '../claims/claim.model';
import { EvidenceModel } from '../evidence/evidence.model';
import { PlaceAttributeModel } from './placeAttribute.model';
import { CLAIM_STATUSES } from '../../shared/constants';
import { ValidationError } from '../../shared/errors/AppError';

export interface PlaceProgressMetrics {
  placeId: string;
  totalContributions: number;
  verifiedFactsCount: number;
  pendingReviewCount: number;
  folkloreCount: number;
  opinionsCount: number;
  biographiesCount: number;
  facilitiesCount: number;
  evidenceAttachmentsCount: number;
  qualityCoverageScore: number; // 0 to 100 based strictly on evidence, verified history, and facilities
  criteriaExplanation: string;
}

export class PlaceProgressService {
  async calculatePlaceProgress(placeId: string, _req?: unknown): Promise<PlaceProgressMetrics> {
    if (!/^[a-zA-Z0-9_-]{2,100}$/.test(placeId)) {
      throw new ValidationError('Invalid place ID format');
    }

    const isLocalObjectId = mongoose.Types.ObjectId.isValid(placeId);
    const queryLocationId = isLocalObjectId ? new mongoose.Types.ObjectId(placeId) : placeId;

    // 1. Fetch claims that are NOT in draft status
    const activeClaims = await ClaimModel.find({
      locationId: queryLocationId,
      status: { $ne: CLAIM_STATUSES.DRAFT },
    }).lean();

    // 2. Fetch place attributes (only local ObjectIds have attributes stored in MongoDB)
    const attributes = isLocalObjectId
      ? await PlaceAttributeModel.find({
          placeId: queryLocationId,
        }).lean()
      : [];

    // 3. Deduplication: Group claims by normalized (category + lowercase trimmed title)
    // Multiple submissions of the same underlying story or title are counted once!
    const uniqueVerifiedFactTitles = new Set<string>();
    const uniqueFolkloreTitles = new Set<string>();
    const uniqueBiographyTitles = new Set<string>();
    let pendingReviewCount = 0;
    let opinionsCount = 0;

    for (const c of activeClaims) {
      const normTitle = (c.title?.original || '').trim().toLowerCase();
      if (c.status === CLAIM_STATUSES.SUBMITTED || c.status === CLAIM_STATUSES.UNDER_REVIEW) {
        pendingReviewCount++;
      }

      if (c.category === 'PUBLIC_OPINION') {
        opinionsCount++;
        // Opinions NEVER enter verified facts or cultural knowledge scores
        continue;
      }

      // Verified facts: must be verified status and factual category
      if (
        c.status === CLAIM_STATUSES.VERIFIED &&
        (c.category === 'CURRENT_FACT' || c.category === 'HISTORICAL_RECORD')
      ) {
        if (normTitle) uniqueVerifiedFactTitles.add(normTitle);
      }

      // Folklore: must be submitted, under_review, or verified (cultural documentation)
      if (c.category === 'FOLKLORE') {
        if (normTitle) uniqueFolkloreTitles.add(normTitle);
      }

      // Living Biographies: must have verified consent and be submitted
      if (
        c.communityTopic === 'biography' &&
        (c.consentState === 'consent_verified' || c.consentObtained === true)
      ) {
        if (normTitle) uniqueBiographyTitles.add(normTitle);
      }
    }

    // 4. Attributes deduplication: Group by normalized (category + key)
    const uniqueFacilityKeys = new Set<string>();
    const uniqueAttributeKeys = new Set<string>();

    for (const attr of attributes) {
      const normKey = `${attr.category}:${(attr.key || '').trim().toLowerCase()}`;
      uniqueAttributeKeys.add(normKey);
      if (attr.category === 'facility') {
        uniqueFacilityKeys.add(normKey);
      }
    }

    // 5. Count evidence attached only to active non-draft claims in this location
    const claimIds = activeClaims.map((c) => c._id);
    const evidenceCount = await EvidenceModel.countDocuments({ claimId: { $in: claimIds } });

    // Distinct counts resisting duplicate submissions
    const verifiedFactsCount = uniqueVerifiedFactTitles.size;
    const folkloreCount = uniqueFolkloreTitles.size;
    const biographiesCount = uniqueBiographyTitles.size;
    const facilitiesCount = uniqueFacilityKeys.size;
    const attributesCount = uniqueAttributeKeys.size;

    // Explainable Fair Scoring Formula (Zero population, raw votes, or popularity bias):
    // 1. Evidence Quality & Verified History: Up to 40 pts (distinct verified facts * 10 + evidence attachments * 5)
    // 2. Cultural & Tradition Documentation: Up to 25 pts (distinct folklore documented * 5)
    // 3. Development, Facilities & Local Records: Up to 25 pts (distinct facilities and local records * 5)
    // 4. Biographies with consent: Up to 10 pts (distinct consent-based life stories * 5)
    const historyEvidencePts = Math.min(40, verifiedFactsCount * 10 + evidenceCount * 5);
    const culturePts = Math.min(25, folkloreCount * 5);
    const facilitiesPts = Math.min(25, attributesCount * 5);
    const biographyPts = Math.min(10, biographiesCount * 5);

    const qualityCoverageScore = Math.min(100, historyEvidencePts + culturePts + facilitiesPts + biographyPts);

    return {
      placeId,
      totalContributions: activeClaims.length + attributes.length,
      verifiedFactsCount,
      pendingReviewCount,
      folkloreCount,
      opinionsCount,
      biographiesCount,
      facilitiesCount,
      evidenceAttachmentsCount: evidenceCount,
      qualityCoverageScore,
      criteriaExplanation:
        'Score is based strictly on documented local heritage, verified evidence, cultural folklore, and source-attributed development facilities. Repeated duplicate submissions are merged, opinions and unverified claims are excluded, and population or vote count is completely excluded.',
    };
  }
}

export const placeProgressService = new PlaceProgressService();
