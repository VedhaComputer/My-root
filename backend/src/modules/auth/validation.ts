import { z } from 'zod';

export const registerSchema = z.object({
  displayName: z
    .string({ required_error: 'Display name is required' })
    .trim()
    .min(2, 'Display name must be at least 2 characters')
    .max(100, 'Display name cannot exceed 100 characters'),
  email: z
    .string({ required_error: 'Email is required' })
    .trim()
    .email('Invalid email address')
    .toLowerCase(),
  password: z
    .string({ required_error: 'Password is required' })
    .min(8, 'Password must be at least 8 characters')
    .max(128, 'Password cannot exceed 128 characters'),
});

export type RegisterInput = z.infer<typeof registerSchema>;

export const loginSchema = z.object({
  email: z
    .string({ required_error: 'Email is required' })
    .trim()
    .email('Invalid email address')
    .toLowerCase(),
  password: z
    .string({ required_error: 'Password is required' })
    .min(1, 'Password is required'),
});

export type LoginInput = z.infer<typeof loginSchema>;

export const refreshSchema = z.object({
  refreshToken: z
    .string({ required_error: 'Refresh token is required' })
    .min(1, 'Refresh token is required'),
});

export type RefreshInput = z.infer<typeof refreshSchema>;

export const logoutSchema = z.object({
  refreshToken: z.string().optional(),
});

export type LogoutInput = z.infer<typeof logoutSchema>;

const placeIdPattern = /^[a-zA-Z0-9_-]{2,100}$/;

export const updateMeSchema = z
  .object({
    selectedPlaceId: z
      .string()
      .trim()
      .regex(placeIdPattern, 'Invalid place ID format')
      .nullable()
      .optional(),
    placeId: z
      .string()
      .trim()
      .regex(placeIdPattern, 'Invalid place ID format')
      .nullable()
      .optional(),
    matrbhoomiHistoryInterest: z
      .object({
        placeId: z.string().trim().regex(placeIdPattern, 'Invalid place ID format'),
        knowsHistory: z.boolean().nullable().optional(),
        wantsToLearn: z.boolean().nullable().optional(),
      })
      .optional(),
  })
  .refine(
    (data) =>
      data.selectedPlaceId !== undefined ||
      data.placeId !== undefined ||
      data.matrbhoomiHistoryInterest !== undefined,
    { message: 'At least one field must be provided for update' }
  );

export type UpdateMeInput = z.infer<typeof updateMeSchema>;

export const requestPasswordResetSchema = z.object({
  email: z
    .string({ required_error: 'Email is required' })
    .trim()
    .email('Invalid email address')
    .toLowerCase(),
});

export type RequestPasswordResetInput = z.infer<typeof requestPasswordResetSchema>;

export const resetPasswordSchema = z.object({
  token: z
    .string({ required_error: 'Reset token is required' })
    .trim()
    .min(1, 'Reset token is required'),
  newPassword: z
    .string({ required_error: 'New password is required' })
    .min(8, 'Password must be at least 8 characters')
    .max(128, 'Password cannot exceed 128 characters'),
});

export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;

export const verifyEmailSchema = z.object({
  token: z
    .string({ required_error: 'Verification token is required' })
    .trim()
    .min(1, 'Verification token is required'),
});

export type VerifyEmailInput = z.infer<typeof verifyEmailSchema>;

export const resendVerificationEmailSchema = z.object({
  email: z
    .string({ required_error: 'Email is required' })
    .trim()
    .email('Invalid email address')
    .toLowerCase(),
});

export type ResendVerificationEmailInput = z.infer<typeof resendVerificationEmailSchema>;
