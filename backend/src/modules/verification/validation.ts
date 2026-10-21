import { z } from 'zod';
import { REVIEW_DECISIONS, ReviewDecision } from '../../shared/constants';

const decisionValues = REVIEW_DECISIONS as unknown as [ReviewDecision, ...ReviewDecision[]];

export const submitReviewSchema = z.object({
  claimId: z
    .string({ required_error: 'Claim ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid claim ID format'),
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

export type SubmitReviewInput = z.infer<typeof submitReviewSchema>;

export const verificationClaimIdParamSchema = z.object({
  claimId: z
    .string({ required_error: 'Claim ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid claim ID format'),
});

export type VerificationClaimIdParamInput = z.infer<typeof verificationClaimIdParamSchema>;
