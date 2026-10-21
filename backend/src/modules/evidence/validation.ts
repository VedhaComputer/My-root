import { z } from 'zod';
import { EVIDENCE_SOURCE_TYPES, EvidenceSourceType } from '../../shared/constants';

const evidenceSourceValues = EVIDENCE_SOURCE_TYPES as unknown as [EvidenceSourceType, ...EvidenceSourceType[]];

export const safeEvidenceUrlSchema = z
  .string()
  .trim()
  .max(2048, 'URL cannot exceed 2048 characters')
  .refine(
    (val) => {
      if (!val) return true;
      try {
        let decoded = val;
        try {
          decoded = decodeURI(val);
        } catch {
          return false;
        }

        const parsed = new URL(val);
        if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') {
          return false;
        }

        if (!parsed.hostname || parsed.hostname.trim() === '') {
          return false;
        }

        const lowerDecoded = decoded.toLowerCase().trim();
        if (
          lowerDecoded.startsWith('javascript:') ||
          lowerDecoded.startsWith('data:') ||
          lowerDecoded.startsWith('file:') ||
          lowerDecoded.startsWith('vbscript:')
        ) {
          return false;
        }

        return true;
      } catch {
        return false;
      }
    },
    {
      message: 'Evidence URL must be a valid http or https URL and cannot use dangerous schemes (javascript, data, file)',
    }
  );

export const createEvidenceSchema = z.object({
  claimId: z
    .string({ required_error: 'Claim ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid claim ID format'),
  sourceType: z.enum(evidenceSourceValues, {
    errorMap: () => ({
      message: `Source type must be one of: ${evidenceSourceValues.join(', ')}`,
    }),
  }),
  title: z
    .string({ required_error: 'Evidence title is required' })
    .trim()
    .min(3, 'Title must be at least 3 characters')
    .max(300, 'Title cannot exceed 300 characters'),
  description: z
    .string({ required_error: 'Evidence description is required' })
    .trim()
    .min(10, 'Description must be at least 10 characters')
    .max(5000, 'Description cannot exceed 5000 characters'),
  url: safeEvidenceUrlSchema.optional().nullable(),
  documentRef: z.string().trim().max(500).optional().nullable(),
  dateOfEvidence: z
    .string()
    .datetime({ message: 'Must be an ISO date string' })
    .optional()
    .nullable(),
  languageOfEvidence: z
    .string()
    .trim()
    .toLowerCase()
    .default('en'),
});

export type CreateEvidenceInput = z.infer<typeof createEvidenceSchema>;

export const reviewEvidenceSchema = z.object({
  decision: z.enum(['verified', 'rejected', 'disputed'], {
    errorMap: () => ({ message: 'Decision must be one of: verified, rejected, disputed' }),
  }),
  reviewNotes: z
    .string({ required_error: 'Review notes are required' })
    .trim()
    .min(10, 'Review notes must be at least 10 characters')
    .max(2000, 'Review notes cannot exceed 2000 characters'),
});

export type ReviewEvidenceInput = z.infer<typeof reviewEvidenceSchema>;

export const evidenceIdParamSchema = z.object({
  id: z
    .string({ required_error: 'Evidence ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid evidence ID format'),
});

export type EvidenceIdParamInput = z.infer<typeof evidenceIdParamSchema>;

export const evidenceClaimIdParamSchema = z.object({
  claimId: z
    .string({ required_error: 'Claim ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid claim ID format'),
});

export type EvidenceClaimIdParamInput = z.infer<typeof evidenceClaimIdParamSchema>;
