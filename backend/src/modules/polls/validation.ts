import { z } from 'zod';

const photoUrlSchema = z
  .string()
  .trim()
  .refine(
    (val) => {
      if (!val || val === '') return true;
      if (val.startsWith('/uploads/')) return true;
      try {
        const parsed = new URL(val);
        return parsed.protocol === 'http:' || parsed.protocol === 'https:';
      } catch {
        return false;
      }
    },
    { message: 'Photo URL must be a valid HTTP/HTTPS URL or uploaded path' }
  )
  .optional()
  .nullable();

const personItemSchema = z.object({
  name: z
    .string({ required_error: 'Person name is required' })
    .trim()
    .min(2, 'Person name must be at least 2 characters')
    .max(120, 'Person name cannot exceed 120 characters'),
  role: z.string().trim().max(100).optional().nullable(),
  designation: z.string().trim().max(100).optional().nullable(),
  officeContext: z.string().trim().max(150).optional().nullable(),
  placeId: z.string().trim().optional().nullable(),
  placeName: z.string().trim().max(150).optional().nullable(),
  targetEntityId: z.string().trim().max(100).optional().nullable(),
  photoUrl: photoUrlSchema,
  workBackground: z.string().trim().max(1000).optional().nullable(),
  publicServiceHistory: z.string().trim().max(2000).optional().nullable(),
  education: z.string().trim().max(300).optional().nullable(),
  achievements: z.string().trim().max(2000).optional().nullable(),
  casteCommunity: z.string().trim().max(100).optional().nullable(),
  religion: z.string().trim().max(100).optional().nullable(),
  bio: z.string().trim().max(2000).optional().nullable(),
  sourceReference: z.string().trim().max(500).optional().nullable(),
  verificationStatus: z
    .enum(['UNVERIFIED', 'SELF_CLAIMED', 'DOCUMENTED', 'VERIFIED'])
    .optional()
    .nullable()
    .default('UNVERIFIED'),
});

const questionItemSchema = z.object({
  text: z
    .string({ required_error: 'Question text is required' })
    .trim()
    .min(5, 'Question text must be at least 5 characters')
    .max(300, 'Question text cannot exceed 300 characters'),
  personId: z.string().trim().max(100).optional().nullable(),
  questionType: z.enum(['LIKE_DISLIKE', 'CHOICE']).default('LIKE_DISLIKE').optional(),
  options: z
    .array(
      z.object({
        key: z.string().trim().min(1).max(60),
        labelEn: z.string().trim().min(1).max(100),
        labelHi: z.string().trim().min(1).max(100),
      })
    )
    .optional(),
});

export const createPollSchema = z
  .object({
    purpose: z.string().trim().max(150, 'Purpose cannot exceed 150 characters').optional().nullable(),
    category: z.string().trim().max(80, 'Category cannot exceed 80 characters').optional().nullable(),
    people: z.array(personItemSchema).min(1).optional(),
    questions: z.array(questionItemSchema).min(1).optional(),

    // Legacy fields
    personName: z
      .string()
      .trim()
      .min(2, 'Person name must be at least 2 characters')
      .max(120, 'Person name cannot exceed 120 characters')
      .optional(),
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
      .string()
      .trim()
      .min(5, 'Question must be at least 5 characters')
      .max(300, 'Question cannot exceed 300 characters')
      .optional(),
    description: z
      .string()
      .trim()
      .max(1000, 'Description cannot exceed 1000 characters')
      .optional()
      .nullable(),
    photoUrl: photoUrlSchema,
    workBackground: z.string().trim().max(1000).optional().nullable(),
    publicServiceHistory: z.string().trim().max(2000).optional().nullable(),
    education: z.string().trim().max(300).optional().nullable(),
    achievements: z.string().trim().max(2000).optional().nullable(),
    casteCommunity: z.string().trim().max(100).optional().nullable(),
    religion: z.string().trim().max(100).optional().nullable(),
    bio: z.string().trim().max(2000).optional().nullable(),
    sourceReference: z.string().trim().max(500).optional().nullable(),
    verificationStatus: z
      .enum(['UNVERIFIED', 'SELF_CLAIMED', 'DOCUMENTED', 'VERIFIED'])
      .optional()
      .nullable()
      .default('UNVERIFIED'),
    startTime: z
      .string()
      .datetime({ offset: true })
      .or(z.string().datetime())
      .optional()
      .nullable(),
    endTime: z
      .string()
      .datetime({ offset: true })
      .or(z.string().datetime())
      .optional()
      .nullable(),
    durationDays: z
      .number()
      .int('Duration must be an integer')
      .min(1, 'Duration must be at least 1 day')
      .optional()
      .nullable(),
  })
  .refine(
    (data) => (data.people && data.people.length > 0) || (data.personName && data.personName.trim().length >= 2),
    {
      message: 'Either personName or at least one person in people list is required',
      path: ['personName'],
    }
  )
  .refine(
    (data) => (data.questions && data.questions.length > 0) || (data.question && data.question.trim().length >= 5),
    {
      message: 'Either question or at least one question in questions list is required',
      path: ['question'],
    }
  )
  .refine(
    (data) => {
      if (data.startTime && data.endTime) {
        return new Date(data.endTime).getTime() > new Date(data.startTime).getTime();
      }
      return true;
    },
    {
      message: 'End time must be after start time',
      path: ['endTime'],
    }
  );

export const votePollSchema = z.object({
  questionId: z.string().trim().max(100).optional().nullable(),
  personId: z.string().trim().max(100).optional().nullable(),
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
  action: z.enum(['REMOVE', 'CLOSE', 'DISMISS_REPORTS', 'UPDATE_VERIFICATION'], {
    required_error: 'Moderation action (REMOVE, CLOSE, DISMISS_REPORTS, or UPDATE_VERIFICATION) is required',
  }),
  personId: z.string().trim().optional(),
  verificationStatus: z.enum(['UNVERIFIED', 'SELF_CLAIMED', 'DOCUMENTED', 'VERIFIED']).optional(),
});

export const pollIdParamSchema = z.object({
  id: z
    .string({ required_error: 'Poll ID is required' })
    .trim()
    .refine((val) => /^[0-9a-fA-F]{24}$/.test(val) || val.length >= 3, {
      message: 'Invalid Poll ID format',
    }),
});
