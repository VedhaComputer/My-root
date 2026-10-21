import {
  createClaimSchema,
  updateClaimSchema,
  queryClaimsSchema,
} from '../../../../src/modules/claims/validation';
import { CLAIM_CATEGORIES } from '../../../../src/shared/constants';

describe('Claims Validation Schemas', () => {
  const validLocationId = '507f1f77bcf86cd799439011';

  describe('createClaimSchema', () => {
    it('accepts valid claim input', () => {
      const valid = {
        title: { original: 'Ancient Temple of Mandore', language: 'en' },
        body: {
          original: 'Detailed historical documentation about the ancient temple in Mandore.',
          language: 'en',
        },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        locationId: validLocationId,
        tags: ['temple', 'mandore', 'history'],
      };

      const result = createClaimSchema.safeParse(valid);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.category).toBe(CLAIM_CATEGORIES.HISTORICAL_RECORD);
        expect(result.data.tags).toHaveLength(3);
      }
    });

    it('accepts Hindi language code', () => {
      const validHindi = {
        title: { original: 'मंडोर का प्राचीन मंदिर', language: 'hi' },
        body: {
          original: 'मंडोर के प्राचीन मंदिर का विस्तृत ऐतिहासिक और सांस्कृतिक विवरण।',
          language: 'hi',
        },
        category: CLAIM_CATEGORIES.FOLKLORE,
        locationId: validLocationId,
      };

      const result = createClaimSchema.safeParse(validHindi);
      expect(result.success).toBe(true);
    });

    it('rejects unsupported language code', () => {
      const invalid = {
        title: { original: 'French Title', language: 'fr' },
        body: { original: 'French body content that is long enough.', language: 'fr' },
        category: CLAIM_CATEGORIES.CURRENT_FACT,
        locationId: validLocationId,
      };

      const result = createClaimSchema.safeParse(invalid);
      expect(result.success).toBe(false);
    });

    it('rejects title shorter than 3 characters', () => {
      const invalid = {
        title: { original: 'Ab', language: 'en' },
        body: { original: 'Valid body text with enough length.', language: 'en' },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        locationId: validLocationId,
      };

      const result = createClaimSchema.safeParse(invalid);
      expect(result.success).toBe(false);
    });

    it('rejects body shorter than 10 characters', () => {
      const invalid = {
        title: { original: 'Valid Title', language: 'en' },
        body: { original: 'Too short', language: 'en' },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        locationId: validLocationId,
      };

      const result = createClaimSchema.safeParse(invalid);
      expect(result.success).toBe(false);
    });

    it('rejects invalid category', () => {
      const invalid = {
        title: { original: 'Valid Title', language: 'en' },
        body: { original: 'Valid body text with enough length.', language: 'en' },
        category: 'NON_EXISTENT_CATEGORY',
        locationId: validLocationId,
      };

      const result = createClaimSchema.safeParse(invalid);
      expect(result.success).toBe(false);
    });

    it('accepts external census Place ID format like PL_VIL_06_077_00382_060008', () => {
      const validExternal = {
        title: { original: 'Village Chronicle', language: 'en' },
        body: { original: 'Historical chronicle of the village community.', language: 'en' },
        category: CLAIM_CATEGORIES.HISTORICAL_RECORD,
        locationId: 'PL_VIL_06_077_00382_060008',
      };

      const result = createClaimSchema.safeParse(validExternal);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.locationId).toBe('PL_VIL_06_077_00382_060008');
      }
    });

    it('rejects malformed locationId with invalid characters or format', () => {
      const invalidChars = {
        title: { original: 'Valid Title', language: 'en' },
        body: { original: 'Valid body text with enough length.', language: 'en' },
        category: CLAIM_CATEGORIES.CURRENT_FACT,
        locationId: 'invalid id with spaces',
      };
      expect(createClaimSchema.safeParse(invalidChars).success).toBe(false);

      const invalidSymbols = {
        ...invalidChars,
        locationId: 'invalid@#$*!',
      };
      expect(createClaimSchema.safeParse(invalidSymbols).success).toBe(false);

      const tooShort = {
        ...invalidChars,
        locationId: 'a',
      };
      expect(createClaimSchema.safeParse(tooShort).success).toBe(false);
    });
  });

  describe('updateClaimSchema', () => {
    it('accepts partial update of title', () => {
      const valid = {
        title: { original: 'Updated Title', language: 'en' },
      };
      const result = updateClaimSchema.safeParse(valid);
      expect(result.success).toBe(true);
    });

    it('accepts update of tags', () => {
      const valid = {
        tags: ['new-tag-1', 'new-tag-2'],
      };
      const result = updateClaimSchema.safeParse(valid);
      expect(result.success).toBe(true);
    });

    it('rejects empty object when updating', () => {
      const result = updateClaimSchema.safeParse({});
      expect(result.success).toBe(false);
    });
  });

  describe('queryClaimsSchema', () => {
    it('parses valid query parameters with defaults', () => {
      const result = queryClaimsSchema.safeParse({});
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(1);
        expect(result.data.limit).toBe(20);
      }
    });

    it('transforms page and limit to numbers', () => {
      const result = queryClaimsSchema.safeParse({ page: '3', limit: '15' });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.page).toBe(3);
        expect(result.data.limit).toBe(15);
      }
    });

    it('accepts external Place ID in query parameter', () => {
      const result = queryClaimsSchema.safeParse({ locationId: 'PL_VIL_06_077_00382_060008' });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.locationId).toBe('PL_VIL_06_077_00382_060008');
      }
    });

    it('accepts MongoDB ObjectId in query parameter', () => {
      const result = queryClaimsSchema.safeParse({ locationId: validLocationId });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.locationId).toBe(validLocationId);
      }
    });

    it('rejects malformed locationId in query parameter', () => {
      const result = queryClaimsSchema.safeParse({ locationId: 'invalid location with spaces' });
      expect(result.success).toBe(false);
    });
  });
});
