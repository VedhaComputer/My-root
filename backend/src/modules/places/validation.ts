import { z } from 'zod';
import { PLACE_LEVELS } from '../../shared/constants';

const placeLevelValues = [
  PLACE_LEVELS.COUNTRY,
  PLACE_LEVELS.STATE,
  PLACE_LEVELS.DISTRICT,
  PLACE_LEVELS.TEHSIL,
  PLACE_LEVELS.CITY_TOWN,
  PLACE_LEVELS.VILLAGE,
] as const;

export const localizedNameSchema = z.object({
  language: z
    .string({ required_error: 'Language code is required' })
    .trim()
    .min(2, 'Language code must be at least 2 characters')
    .max(10, 'Language code cannot exceed 10 characters'),
  name: z
    .string({ required_error: 'Localized name is required' })
    .trim()
    .min(1, 'Localized name cannot be empty')
    .max(120, 'Localized name cannot exceed 120 characters'),
});

export const geoCoordinatesSchema = z.object({
  lat: z.number().min(-90).max(90),
  lng: z.number().min(-180).max(180),
});

export const createPlaceSchema = z.object({
  level: z.enum(placeLevelValues, {
    errorMap: () => ({
      message: `Level must be one of: ${placeLevelValues.join(', ')}`,
    }),
  }),
  canonicalName: z
    .string({ required_error: 'Canonical name is required' })
    .trim()
    .min(2, 'Canonical name must be at least 2 characters')
    .max(120, 'Canonical name cannot exceed 120 characters'),
  names: z
    .array(localizedNameSchema)
    .min(1, 'At least one localized name is required'),
  parentId: z
    .string()
    .trim()
    .min(1, 'Invalid parent ID format')
    .nullable()
    .optional(),
  geoCoordinates: geoCoordinatesSchema.optional(),
});

export type CreatePlaceInput = z.infer<typeof createPlaceSchema>;

export const updatePlaceSchema = z.object({
  level: z.enum(placeLevelValues).optional(),
  canonicalName: z
    .string()
    .trim()
    .min(2, 'Canonical name must be at least 2 characters')
    .max(120, 'Canonical name cannot exceed 120 characters')
    .optional(),
  names: z.array(localizedNameSchema).min(1).optional(),
  parentId: z
    .string()
    .trim()
    .min(1, 'Invalid parent ID format')
    .nullable()
    .optional(),
  geoCoordinates: geoCoordinatesSchema.optional(),
});

export type UpdatePlaceInput = z.infer<typeof updatePlaceSchema>;

export const queryPlacesSchema = z.object({
  level: z.enum(placeLevelValues).optional(),
  parentId: z
    .string()
    .trim()
    .regex(/^[a-zA-Z0-9_-]{2,100}$/, 'Invalid parent ID format')
    .optional(),
  search: z.string().trim().max(100).optional(),
  page: z
    .union([z.string(), z.number()])
    .optional()
    .refine(
      (val) => {
        if (val === undefined) return true;
        const s = typeof val === 'number' ? String(val) : val.trim();
        return /^[1-9]\d*$/.test(s) && Number.isSafeInteger(Number(s));
      },
      { message: 'page must be a strict positive integer' }
    )
    .transform((val) => {
      if (val === undefined) return 1;
      return typeof val === 'number' ? val : parseInt(val.trim(), 10);
    }),
  limit: z
    .union([z.string(), z.number()])
    .optional()
    .refine(
      (val) => {
        if (val === undefined) return true;
        const s = typeof val === 'number' ? String(val) : val.trim();
        if (!/^[1-9]\d*$/.test(s) || !Number.isSafeInteger(Number(s))) return false;
        const n = Number(s);
        return n >= 1 && n <= 100;
      },
      { message: 'limit must be a positive integer between 1 and 100' }
    )
    .transform((val) => {
      if (val === undefined) return 20;
      return typeof val === 'number' ? val : parseInt(val.trim(), 10);
    }),
});

export type QueryPlacesInput = z.input<typeof queryPlacesSchema>;
export type QueryPlacesOutput = z.output<typeof queryPlacesSchema>;

export const placeIdParamSchema = z.object({
  id: z
    .string({ required_error: 'Place ID is required' })
    .trim()
    .min(1, 'Place ID is required')
    .max(100, 'Place ID must not exceed 100 characters'),
});

export type PlaceIdParamInput = z.infer<typeof placeIdParamSchema>;

export const placeAttrParamsSchema = z.object({
  id: z
    .string({ required_error: 'Place ID is required' })
    .trim()
    .regex(/^[a-zA-Z0-9_-]{2,100}$/, 'Invalid place ID format'),
  attrId: z
    .string({ required_error: 'Attribute ID is required' })
    .trim()
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid attribute ID format'),
});

export type PlaceAttrParamsInput = z.infer<typeof placeAttrParamsSchema>;

export const createPlaceAttributeSchema = z.object({
  category: z.enum(['population', 'leadership', 'facility', 'development', 'issue', 'identity']),
  key: z.string().trim().min(1, 'Key is required').max(100),
  value: z.string().trim().min(1, 'Value is required').max(1000),
  sourceDescription: z.string().trim().min(1, 'Source description is required').max(500),
  reportedPeriod: z.string().trim().nullable().optional(),
  reportedDate: z.string().trim().nullable().optional(),
  uncertainty: z.string().trim().nullable().optional(),
});

export type CreatePlaceAttributeInput = z.infer<typeof createPlaceAttributeSchema>;

export const correctPlaceAttributeSchema = z.object({
  value: z.string().trim().min(1, 'Value is required').max(1000),
  sourceDescription: z.string().trim().min(1, 'Source description is required').max(500),
  reportedPeriod: z.string().trim().nullable().optional(),
  reportedDate: z.string().trim().nullable().optional(),
  uncertainty: z.string().trim().nullable().optional(),
  correctionReason: z.string().trim().max(500).optional(),
});

export type CorrectPlaceAttributeInput = z.infer<typeof correctPlaceAttributeSchema>;

export const getPlaceAttributesQuerySchema = z.object({
  category: z
    .enum(['population', 'leadership', 'facility', 'development', 'issue', 'identity'], {
      errorMap: () => ({
        message: 'category must be one of: population, leadership, facility, development, issue, identity',
      }),
    })
    .optional(),
});

export type GetPlaceAttributesQueryInput = z.infer<typeof getPlaceAttributesQuerySchema>;

export const reviewPlaceAttributeSchema = z.object({
  decision: z.enum(['verified', 'rejected'], {
    errorMap: () => ({ message: 'Decision must be one of: verified, rejected' }),
  }),
  reviewNotes: z.string().trim().max(1000).optional(),
});

export type ReviewPlaceAttributeInput = z.infer<typeof reviewPlaceAttributeSchema>;



