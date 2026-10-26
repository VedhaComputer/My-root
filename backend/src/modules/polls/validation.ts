import { z } from 'zod';

export const createPollSchema = z.object({
  personName: z
    .string({ required_error: 'Person name is required' })
    .trim()
    .min(2, 'Person name must be at least 2 characters')
    .max(120, 'Person name cannot exceed 120 characters'),
  personRole: z
    .string()
    .trim()
    .max(100, 'Role/designation cannot exceed 100 characters')
    .optional()
    .nullable(),
  placeId: z.string().trim().optional().nullable(),
  placeName: z.string().trim().max(150).optional().nullable(),
  targetEntityId: z.string().trim().max(100).optional().nullable(),
  question: z
    .string({ required_error: 'Poll question is required' })
    .trim()
    .min(5, 'Question must be at least 5 characters')
    .max(300, 'Question cannot exceed 300 characters'),
  description: z
    .string()
    .trim()
    .max(1000, 'Description cannot exceed 1000 characters')
    .optional()
    .nullable(),
  photoUrl: z
    .string()
    .trim()
    .url('Photo URL must be a valid URL')
    .optional()
    .nullable()
    .or(z.literal('')),
  durationDays: z
    .number()
    .int('Duration must be an integer')
    .min(1, 'Duration must be at least 1 day')
    .max(365, 'Duration cannot exceed 365 days')
    .optional()
    .nullable(),
});

export const votePollSchema = z.object({
  choice: z.enum(['LIKE', 'DISLIKE'], {
    required_error: 'Vote choice (LIKE or DISLIKE) is required',
  }),
  reasonKey: z
    .string({ required_error: 'Reason category is required' })
    .trim()
    .min(1, 'Reason category is required')
    .max(60, 'Reason key cannot exceed 60 characters'),
  explanation: z
    .string()
    .trim()
    .max(500, 'Explanation cannot exceed 500 characters')
    .optional()
    .nullable(),
});

export const queryPollsSchema = z.object({
  personName: z.string().trim().optional(),
  placeId: z.string().trim().optional(),
  targetEntityId: z.string().trim().optional(),
  status: z.enum(['ACTIVE', 'CLOSED', 'REPORTED', 'REMOVED']).optional(),
  search: z.string().trim().optional(),
  page: z
    .string()
    .optional()
    .transform((val) => (val ? Math.max(1, parseInt(val, 10) || 1) : 1)),
  limit: z
    .string()
    .optional()
    .transform((val) => (val ? Math.min(100, Math.max(1, parseInt(val, 10) || 20)) : 20)),
});

export const reportPollSchema = z.object({
  reason: z
    .string({ required_error: 'Report reason is required' })
    .trim()
    .min(3, 'Reason must be at least 3 characters')
    .max(100, 'Reason cannot exceed 100 characters'),
  details: z
    .string()
    .trim()
    .max(500, 'Details cannot exceed 500 characters')
    .optional()
    .nullable(),
});

export const moderatePollSchema = z.object({
  action: z.enum(['REMOVE', 'CLOSE', 'DISMISS_REPORTS'], {
    required_error: 'Moderation action (REMOVE, CLOSE, or DISMISS_REPORTS) is required',
  }),
});

export const pollIdParamSchema = z.object({
  id: z
    .string({ required_error: 'Poll ID is required' })
    .trim()
    .min(1, 'Poll ID cannot be empty'),
});
