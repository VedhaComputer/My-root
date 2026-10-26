import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { createApp } from '../../src/app';
import { placeRepository } from '../../src/modules/places/repository';
import { placeAttributeRepository } from '../../src/modules/places/placeAttribute.repository';
import { PlaceAttributeModel } from '../../src/modules/places/placeAttribute.model';
import { env } from '../../src/config/env';
import { USER_ROLES, PLACE_LEVELS, UserRole } from '../../src/shared/constants';

const app = createApp();

function generateTestToken(role: UserRole, userId = '507f1f77bcf86cd799439011', tokenVersion = 1): string {
  return jwt.sign(
    {
      userId,
      email: 'testuser@example.com',
      role,
      displayName: 'Test User',
      tokenVersion,
    },
    env.JWT_ACCESS_SECRET,
    {
      algorithm: 'HS256',
      issuer: env.JWT_ISSUER,
      audience: env.JWT_AUDIENCE,
      expiresIn: '15m',
    }
  );
}

describe('Places Routes (Integration Tests)', () => {
  let originalFallback: string | undefined;

  beforeAll(() => {
    originalFallback = process.env.JWT_ALLOW_HS256_FALLBACK;
    process.env.JWT_ALLOW_HS256_FALLBACK = 'true';
  });

  afterAll(() => {
    if (originalFallback === undefined) {
      delete process.env.JWT_ALLOW_HS256_FALLBACK;
    } else {
      process.env.JWT_ALLOW_HS256_FALLBACK = originalFallback;
    }
  });

  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(placeRepository, 'withTransaction').mockImplementation(async (cb) => cb({} as any));
    jest.spyOn(placeRepository, 'touch').mockImplementation(async (id, s) => placeRepository.findById(id, s));
  });

  describe('GET /api/v1/places', () => {
    it('returns 401 when request is not authenticated', async () => {
      const res = await request(app).get('/api/v1/places');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 200 with places list and pagination when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(placeRepository, 'list').mockResolvedValue({
        places: [
          {
            id: 'c-1',
            level: PLACE_LEVELS.COUNTRY,
            canonicalName: 'India',
            names: [{ language: 'en', name: 'India' }],
            parentId: null,
          } as any,
        ],
        total: 1,
      });

      const res = await request(app)
        .get('/api/v1/places?page=1&limit=20')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeInstanceOf(Array);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.pagination).toBeDefined();
      expect(res.body.pagination.total).toBe(1);
    });

    it('validates query parameters and returns 400 on invalid place level when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      const res = await request(app)
        .get('/api/v1/places?level=INVALID_LEVEL')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects invalid page query parameter (decimals, negative, zero, non-numeric, unsafe) with 400', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);

      const invalidPages = ['0', '-1', '1.5', 'abc', '99999999999999999999'];
      for (const page of invalidPages) {
        const res = await request(app)
          .get(`/api/v1/places?page=${page}`)
          .set('Authorization', `Bearer ${token}`);
        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_ERROR');
      }
    });

    it('rejects invalid limit query parameter (decimals, negative, zero, non-numeric, >100) with 400', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);

      const invalidLimits = ['0', '-5', '10.5', 'xyz', '101'];
      for (const limit of invalidLimits) {
        const res = await request(app)
          .get(`/api/v1/places?limit=${limit}`)
          .set('Authorization', `Bearer ${token}`);
        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_ERROR');
      }
    });

    it('rejects malformed parentId query parameter (too short, traversal, symbols) with 400', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);

      const invalidParents = ['a', '../bad', 'inv?id=1', 'invalid/path'];
      for (const parentId of invalidParents) {
        const res = await request(app)
          .get(`/api/v1/places?parentId=${encodeURIComponent(parentId)}`)
          .set('Authorization', `Bearer ${token}`);
        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_ERROR');
      }
    });

    it('accepts valid page, limit, and parentId query parameters and returns 200', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(placeRepository, 'list').mockResolvedValue({
        places: [],
        total: 0,
      });

      const res = await request(app)
        .get('/api/v1/places?page=2&limit=50&parentId=plc_rj_01')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toBeInstanceOf(Array);
    });

    it('accepts valid search query parameter and passes it to repository', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      const listSpy = jest.spyOn(placeRepository, 'list').mockResolvedValue({
        places: [
          {
            id: 'c-1',
            level: PLACE_LEVELS.CITY_TOWN,
            canonicalName: 'Narwana',
            names: [{ language: 'en', name: 'Narwana' }],
            parentId: 'teh-1',
          } as any,
        ],
        total: 1,
      });

      const res = await request(app)
        .get('/api/v1/places?search=Narwana')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(listSpy).toHaveBeenCalledWith(
        expect.objectContaining({ search: 'Narwana' }),
        expect.anything()
      );
    });

    it('rejects search query parameter exceeding 100 characters with 400', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      const longSearch = 'a'.repeat(101);

      const res = await request(app)
        .get(`/api/v1/places?search=${longSearch}`)
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('GET /api/v1/places/:id', () => {
    it('returns 401 when request is not authenticated', async () => {
      const res = await request(app).get('/api/v1/places/dist-1');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 200 with place details and parentPath when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: 'dist-1',
        id: 'dist-1',
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: 'Jodhpur',
        names: [{ language: 'en', name: 'Jodhpur' }],
        parentId: 'state-1',
        createdAt: new Date('2026-01-01'),
        updatedAt: new Date('2026-01-01'),
      } as any);

      jest.spyOn(placeRepository, 'getAncestors').mockResolvedValue([
        { id: 'c-1', level: PLACE_LEVELS.COUNTRY, canonicalName: 'India' },
        { id: 'state-1', level: PLACE_LEVELS.STATE, canonicalName: 'Rajasthan' },
      ]);

      const res = await request(app)
        .get('/api/v1/places/dist-1')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.id).toBe('dist-1');
      expect(res.body.canonicalName).toBe('Jodhpur');
      expect(res.body.parentPath).toHaveLength(2);
      expect(res.body.parentPath[0].canonicalName).toBe('India');
    });

    it('returns 404 when place is not found when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(placeRepository, 'findById').mockResolvedValue(null);

      const res = await request(app)
        .get('/api/v1/places/nonexistent-id')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });
  });

  describe('GET /api/v1/places/:id/children', () => {
    it('returns 401 when request is not authenticated', async () => {
      const res = await request(app).get('/api/v1/places/state-1/children');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 200 with children places when authenticated', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: 'state-1',
        id: 'state-1',
        level: PLACE_LEVELS.STATE,
      } as any);

      jest.spyOn(placeRepository, 'findChildren').mockResolvedValue([
        {
          _id: 'dist-1',
          id: 'dist-1',
          level: PLACE_LEVELS.DISTRICT,
          canonicalName: 'Jodhpur',
        } as any,
      ]);

      const res = await request(app)
        .get('/api/v1/places/state-1/children')
        .set('Authorization', `Bearer ${token}`);
      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].canonicalName).toBe('Jodhpur');
    });
  });

  describe('POST /api/v1/places (Authorization & Creation)', () => {
    it('returns 401 when request is not authenticated', async () => {
      const res = await request(app).post('/api/v1/places').send({
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
        names: [{ language: 'en', name: 'India' }],
      });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('returns 403 when user has CONTRIBUTOR role (requires ADMIN)', async () => {
      const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR);

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          level: PLACE_LEVELS.COUNTRY,
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('returns 403 when user has MODERATOR role (requires ADMIN)', async () => {
      const moderatorToken = generateTestToken(USER_ROLES.MODERATOR);

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${moderatorToken}`)
        .send({
          level: PLACE_LEVELS.COUNTRY,
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('returns 400 when validation fails on body', async () => {
      const adminToken = generateTestToken(USER_ROLES.ADMIN);

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          level: 'INVALID',
          canonicalName: 'X',
          names: [],
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('returns 201 when ADMIN creates a valid place', async () => {
      const adminToken = generateTestToken(USER_ROLES.ADMIN);

      jest.spyOn(placeRepository, 'findDuplicate').mockResolvedValue(null);
      jest.spyOn(placeRepository, 'create').mockResolvedValue({
        _id: 'c-1',
        id: 'c-1',
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
        names: [{ language: 'en', name: 'India' }],
        parentId: null,
      } as any);
      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: 'c-1',
        id: 'c-1',
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
        names: [{ language: 'en', name: 'India' }],
        parentId: null,
      } as any);
      jest.spyOn(placeRepository, 'getAncestors').mockResolvedValue([]);

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          level: PLACE_LEVELS.COUNTRY,
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBe('c-1');
      expect(res.body.data.canonicalName).toBe('India');
    });

    it('maps MongoDB duplicate-key error E11000 to safe 409 CONFLICT without leaking database internals', async () => {
      const adminToken = generateTestToken(USER_ROLES.ADMIN);

      // Pre-check passes (simulating concurrent race condition)
      jest.spyOn(placeRepository, 'findDuplicate').mockResolvedValue(null);

      // Persistence layer rejects with MongoDB E11000 duplicate key error
      const mongoDupError = Object.assign(
        new Error(
          'E11000 duplicate key error collection: myroot.places index: parentId_1_level_1_canonicalNameLower_1 dup key: { parentId: null, level: "COUNTRY", canonicalNameLower: "india" }'
        ),
        { code: 11000, name: 'MongoServerError' }
      );
      jest.spyOn(placeRepository, 'create').mockRejectedValue(mongoDupError);

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          level: PLACE_LEVELS.COUNTRY,
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('CONFLICT');
      expect(res.body.error.message).toBe(
        'A resource with the specified unique attributes already exists'
      );
      // Ensure zero sensitive details, database names, or index names leaked
      expect(JSON.stringify(res.body)).not.toContain('myroot');
      expect(JSON.stringify(res.body)).not.toContain('places');
      expect(JSON.stringify(res.body)).not.toContain('parentId_1_level_1_canonicalNameLower_1');
      expect(JSON.stringify(res.body)).not.toContain('E11000');
    });

    it('preserves generic 500 handling for unrelated database errors without leaking details', async () => {
      const adminToken = generateTestToken(USER_ROLES.ADMIN);

      jest.spyOn(placeRepository, 'findDuplicate').mockResolvedValue(null);
      const genericDbError = Object.assign(
        new Error('MongoNetworkTimeoutException: connection timed out while querying shard rs0'),
        { name: 'MongoNetworkError' }
      );
      jest.spyOn(placeRepository, 'create').mockRejectedValue(genericDbError);

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          level: PLACE_LEVELS.COUNTRY,
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(500);
      expect(res.body.error.code).toBe('INTERNAL_ERROR');
      expect(JSON.stringify(res.body)).not.toContain('shard rs0');
    });
  });

  describe('PUT /api/v1/places/:id', () => {
    it('returns 403 when CONTRIBUTOR attempts to update place', async () => {
      const token = generateTestToken(USER_ROLES.CONTRIBUTOR);
      const res = await request(app)
        .put('/api/v1/places/c-1')
        .set('Authorization', `Bearer ${token}`)
        .send({ canonicalName: 'Updated India' });

      expect(res.status).toBe(403);
    });

    it('returns 200 when MODERATOR updates place', async () => {
      const token = generateTestToken(USER_ROLES.MODERATOR);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: 'c-1',
        id: 'c-1',
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: 'India',
        names: [{ language: 'en', name: 'India' }],
        parentId: null,
      } as any);
      jest.spyOn(placeRepository, 'findDuplicate').mockResolvedValue(null);
      jest.spyOn(placeRepository, 'update').mockResolvedValue({} as any);
      jest.spyOn(placeRepository, 'getAncestors').mockResolvedValue([]);

      const res = await request(app)
        .put('/api/v1/places/c-1')
        .set('Authorization', `Bearer ${token}`)
        .send({ canonicalName: 'Republic of India' });

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe('c-1');
    });
  });

  describe('DELETE /api/v1/places/:id (Admin only)', () => {
    it('returns 403 when MODERATOR tries to delete a place (requires ADMIN)', async () => {
      const token = generateTestToken(USER_ROLES.MODERATOR);
      const res = await request(app)
        .delete('/api/v1/places/c-1')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('returns 200 when ADMIN deletes a leaf place', async () => {
      const token = generateTestToken(USER_ROLES.ADMIN);

      jest.spyOn(placeRepository, 'findById').mockResolvedValue({
        _id: 'vil-1',
        id: 'vil-1',
        level: PLACE_LEVELS.VILLAGE,
      } as any);
      jest.spyOn(placeRepository, 'countChildren').mockResolvedValue(0);
      jest.spyOn(placeRepository, 'delete').mockResolvedValue(true);

      const res = await request(app)
        .delete('/api/v1/places/vil-1')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Place deleted successfully');
    });
  });

  describe('GET /api/v1/places/:id/attributes NoSQL operator injection defense', () => {
    const token = generateTestToken(USER_ROLES.CONTRIBUTOR);

    it('rejects nested MongoDB operator ?category[$ne]=x with 400 VALIDATION_ERROR', async () => {
      const res = await request(app)
        .get('/api/v1/places/vil-1/attributes?category[$ne]=facility')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects nested MongoDB operator ?category[$gt]= with 400 VALIDATION_ERROR', async () => {
      const res = await request(app)
        .get('/api/v1/places/vil-1/attributes?category[$gt]=')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('rejects nested MongoDB regex operator ?category[$regex]=.* with 400 VALIDATION_ERROR', async () => {
      const res = await request(app)
        .get('/api/v1/places/vil-1/attributes?category[$regex]=.*')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    });

    it('accepts valid category string and forwards sanitized string to repository', async () => {
      const findSpy = jest.spyOn(placeAttributeRepository, 'findByPlaceId').mockResolvedValue([]);

      const res = await request(app)
        .get('/api/v1/places/vil-1/attributes?category=facility')
        .set('Authorization', `Bearer ${token}`);

      expect(res.status).toBe(200);
      expect(findSpy).toHaveBeenCalledWith('vil-1', 'facility', expect.anything());
      findSpy.mockRestore();
    });
  });

  describe('PlaceAttributeRepository.findByPlaceId status filtering & missing-status protection', () => {
    const validPlaceId = '507f1f77bcf86cd799439011';
    const testUserId = '507f1f77bcf86cd799439022';

    it('requires explicit verified status for public caller and strictly excludes missing-status records', async () => {
      const execMock = jest.fn().mockResolvedValue([]);
      const sortMock = jest.fn().mockReturnValue({ exec: execMock });
      const findMock = jest.spyOn(PlaceAttributeModel, 'find').mockReturnValue({ sort: sortMock } as any);

      await placeAttributeRepository.findByPlaceId(validPlaceId, undefined, null);

      expect(findMock).toHaveBeenCalledWith(
        expect.objectContaining({
          placeId: new mongoose.Types.ObjectId(validPlaceId),
          status: 'verified',
        })
      );
      const queryArg = (findMock.mock.calls as any)[0][0];
      expect(queryArg.$or).toBeUndefined();
      findMock.mockRestore();
    });

    it('restricts non-privileged contributor to verified or self-submitted attributes and strictly excludes missing-status records', async () => {
      const execMock = jest.fn().mockResolvedValue([]);
      const sortMock = jest.fn().mockReturnValue({ exec: execMock });
      const findMock = jest.spyOn(PlaceAttributeModel, 'find').mockReturnValue({ sort: sortMock } as any);

      const contributorUser = {
        userId: testUserId,
        email: 'user@example.com',
        role: USER_ROLES.CONTRIBUTOR,
        displayName: 'Contributor',
      };

      await placeAttributeRepository.findByPlaceId(validPlaceId, undefined, contributorUser);

      const queryArg = (findMock.mock.calls as any)[0][0];
      expect(queryArg.$or).toEqual([
        { status: 'verified' },
        { submittedBy: new mongoose.Types.ObjectId(testUserId) },
      ]);
      expect(JSON.stringify(queryArg)).not.toContain('$exists');
      findMock.mockRestore();
    });

    it('permits privileged reviewer to access all attributes without status restriction', async () => {
      const execMock = jest.fn().mockResolvedValue([]);
      const sortMock = jest.fn().mockReturnValue({ exec: execMock });
      const findMock = jest.spyOn(PlaceAttributeModel, 'find').mockReturnValue({ sort: sortMock } as any);

      const reviewerUser = {
        userId: testUserId,
        email: 'reviewer@example.com',
        role: USER_ROLES.REVIEWER,
        displayName: 'Reviewer',
      };

      await placeAttributeRepository.findByPlaceId(validPlaceId, undefined, reviewerUser);

      const queryArg = (findMock.mock.calls as any)[0][0];
      expect(queryArg.status).toBeUndefined();
      expect(queryArg.$or).toBeUndefined();
      findMock.mockRestore();
    });
  });
});
