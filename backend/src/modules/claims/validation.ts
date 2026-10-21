import { z } from 'zod';
import {
  CLAIM_CATEGORIES,
  CLAIM_STATUSES,
  REVIEW_DECISIONS,
  ClaimCategory,
  ClaimStatus,
  ReviewDecision,
} from '../../shared/constants';

const categoryValues = Object.values(CLAIM_CATEGORIES) as [ClaimCategory, ...ClaimCategory[]];
const statusValues = Object.values(CLAIM_STATUSES) as [ClaimStatus, ...ClaimStatus[]];

export const localizedContentSchema = z.object({
  original: z
    .string({ required_error: 'Original text is required' })
    .trim()
    .min(3, 'Content must be at least 3 characters')
    .max(10000, 'Content cannot exceed 10000 characters'),
  language: z
    .string({ required_error: 'Language code is required' })
    .trim()
    .toLowerCase()
    .refine((lang) => ['en', 'hi'].includes(lang), {
      message: 'Supported languages are en or hi',
    }),
});

export const createClaimSchema = z.object({
  title: z.object({
    original: z
      .string({ required_error: 'Title original text is required' })
      .trim()
      .min(3, 'Title must be at least 3 characters')
      .max(300, 'Title cannot exceed 300 characters'),
    language: z
      .string({ required_error: 'Title language code is required' })
      .trim()
      .toLowerCase()
      .refine((lang) => ['en', 'hi'].includes(lang), {
        message: 'Supported languages are en or hi',
      }),
  }),
  body: z.object({
    original: z
      .string({ required_error: 'Body original text is required' })
      .trim()
      .min(10, 'Body must be at least 10 characters')
      .max(10000, 'Body cannot exceed 10000 characters'),
    language: z
      .string({ required_error: 'Body language code is required' })
      .trim()
      .toLowerCase()
      .refine((lang) => ['en', 'hi'].includes(lang), {
        message: 'Supported languages are en or hi',
      }),
  }),
  category: z.enum(categoryValues, {
    errorMap: () => ({
      message: `Category must be one of: ${categoryValues.join(', ')}`,
    }),
  }),
  locationId: z
    .string({ required_error: 'Location ID is required' })
    .trim()
    .regex(/^[a-zA-Z0-9_-]{2,100}$/, 'Invalid location ID format'),
  tags: z
    .array(z.string().trim().min(1).max(50))
    .max(20, 'Maximum 20 tags allowed')
    .optional()
    .default([]),
  communityTopic: z.string().trim().max(100).optional(),
  sourceAttribution: z.string().trim().max(500).optional(),
  timePeriod: z.string().trim().max(100).optional(),
  consentObtained: z.boolean().optional(),
  consentDetails: z.string().trim().max(1000).optional(),
  consentState: z.enum(['not_applicable', 'pending_verification', 'consent_verified', 'consent_revoked']).optional(),
  userAgreementStatus: z.enum(['agreed', 'correction', 'different_account', 'dont_know']).optional(),
});

export type CreateClaimInput = z.infer<typeof createClaimSchema>;

export const updateClaimSchema = z
  .object({
    title: z
      .object({
        original: z.string().trim().min(3).max(300),
        language: z.string().trim().toLowerCase().refine((lang) => ['en', 'hi'].includes(lang)),
      })
      .optional(),
    body: z
      .object({
        original: z.string().trim().min(10).max(10000),
        language: z.string().trim().toLowerCase().refine((lang) => ['en', 'hi'].includes(lang)),
      })
      .optional(),
    tags: z
      .array(z.string().trim().min(1).max(50))
      .max(20)
      .optional(),
    communityTopic: z.string().trim().max(100).optional(),
    sourceAttribution: z.string().trim().max(500).optional(),
    timePeriod: z.string().trim().max(100).optional(),
    consentObtained: z.boolean().optional(),
    consentDetails: z.string().trim().max(1000).optional(),
    consentState: z.enum(['not_applicable', 'pending_verification', 'consent_verified', 'consent_revoked']).optional(),
    userAgreementStatus: z.enum(['agreed', 'correction', 'different_account', 'dont_know']).optional(),
  })
  .refine((data) => Object.keys(data).length > 0, {
    message: 'At least one field must be provided for update',
  });

export type UpdateClaimInput = z.infer<typeof updateClaimSchema>;

export const queryClaimsSchema = z.object({
  status: z.enum(statusValues).optional(),
  category: z.enum(categoryValues).optional(),
  communityTopic: z.string().trim().max(100).optional(),
  submittedBy: z
    .string()
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid user ID format')
    .optional(),
  locationId: z
    .string()
    .trim()
    .regex(/^[a-zA-Z0-9_-]{2,100}$/, 'Invalid location ID format')
    .optional(),
  page: z
    .string()
    .optional()
    .transform((val) => (val ? Math.max(1, parseInt(val, 10) || 1) : 1)),
  limit: z
    .string()
    .optional()
    .transform((val) => (val ? Math.min(100, Math.max(1, parseInt(val, 10) || 20)) : 20)),
});

export type QueryClaimsInput = z.infer<typeof queryClaimsSchema>;

export const claimIdParamSchema = z.object({
  id: z
    .string({ required_error: 'Claim ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid claim ID format'),
});

export type ClaimIdParamInput = z.infer<typeof claimIdParamSchema>;

export const claimCorrectionParamsSchema = z.object({
  id: z
    .string({ required_error: 'Claim ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid claim ID format'),
  correctionId: z
    .string({ required_error: 'Correction ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid correction ID format'),
});

export type ClaimCorrectionParamsInput = z.infer<typeof claimCorrectionParamsSchema>;

export const requestCorrectionSchema = z.object({
  reason: z
    .string({ required_error: 'Reason for correction request is required' })
    .trim()
    .min(10, 'Reason must be at least 10 characters')
    .max(2000, 'Reason cannot exceed 2000 characters'),
  proposedChanges: z
    .object({
      title: z.string().trim().min(3).max(300).optional(),
      body: z.string().trim().min(10).max(10000).optional(),
      sourceAttribution: z.string().trim().max(500).optional(),
      timePeriod: z.string().trim().max(100).optional(),
    })
    .optional(),
});

export type RequestCorrectionInput = z.infer<typeof requestCorrectionSchema>;

export const verifyConsentSchema = z.object({
  consentState: z.enum(['consent_verified', 'consent_revoked'], {
    errorMap: () => ({ message: 'consentState must be consent_verified or consent_revoked' }),
  }),
  notes: z.string().trim().max(1000).optional(),
});

export type VerifyConsentInput = z.infer<typeof verifyConsentSchema>;

export const reviewCorrectionSchema = z.object({
  decision: z.enum(['accepted', 'rejected'], {
    errorMap: () => ({ message: 'decision must be accepted or rejected' }),
  }),
  reviewNotes: z
    .string({ required_error: 'Review notes are required' })
    .trim()
    .min(5, 'Review notes must be at least 5 characters')
    .max(2000, 'Review notes cannot exceed 2000 characters'),
});

export type ReviewCorrectionInput = z.infer<typeof reviewCorrectionSchema>;

const decisionValues = REVIEW_DECISIONS as unknown as [ReviewDecision, ...ReviewDecision[]];

export const reviewClaimSchema = z.object({
  decisionStatus: z.enum(decisionValues, {
    errorMap: () => ({
      message: `Decision must be one of: ${decisionValues.join(', ')}`,
    }),
  }),
  reason: z
    .string({ required_error: 'Reason is required' })
    .trim()
    .min(20, 'Reason must be at least 20 characters explaining the review decision')
    .max(5000, 'Reason cannot exceed 5000 characters'),
  sourcesConsidered: z
    .array(z.string().trim().regex(/^[0-9a-fA-F]{24}$/, 'Invalid evidence ID format'))
    .optional()
    .default([]),
  reviewerNote: z.string().trim().max(1000).optional(),
});

export type ReviewClaimInput = z.infer<typeof reviewClaimSchema>;

export const submitHistoryFeedbackSchema = z.object({
  previouslyKnown: z.enum(['yes', 'no', 'partial']).nullable().optional(),
  agreement: z.enum(['agree', 'disagree', 'need_evidence', 'not_sure']).nullable().optional(),
  comment: z.string().trim().max(2000).nullable().optional(),
  knowsAuthor: z.enum(['personally', 'by_name', 'not_known']).nullable().optional(),
}).refine(
  (data) =>
    data.previouslyKnown !== undefined ||
    data.agreement !== undefined ||
    data.comment !== undefined ||
    data.knowsAuthor !== undefined,
  { message: 'At least one feedback response field must be provided' }
);

export type SubmitHistoryFeedbackInput = z.infer<typeof submitHistoryFeedbackSchema>;

