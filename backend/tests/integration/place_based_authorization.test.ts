import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { createApp } from '../../src/app';
import { env } from '../../src/config/env';
import { UserModel } from '../../src/modules/auth/user.model';
import { authRepository } from '../../src/modules/auth/repository';
import { USER_ROLES } from '../../src/shared/constants';
import { placeRepository } from '../../src/modules/places/repository';
import { claimRepository } from '../../src/modules/claims/repository';
import { placeAttributeRepository } from '../../src/modules/places/placeAttribute.repository';

import { PlaceModel } from '../../src/modules/places/place.model';

const app = createApp();

function generateTestToken(role: string, userId: string, tokenVersion = 1): string {
  return jwt.sign(
    {
      userId,
      email: `${userId}@example.com`,
      role,
      displayName: `User ${userId}`,
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

function mockUserModel(user: any) {
  jest.spyOn(UserModel, 'findById').mockImplementation((id: any) => {
    const matches = user && (user._id?.toString() === id?.toString() || user.id?.toString() === id?.toString());
    const doc = matches ? user : null;
    const leanDoc = doc
      ? {
          _id: doc._id,
          isActive: true,
          role: doc.role,
          tokenVersion: 1,
          selectedPlaceId: doc.selectedPlaceId,
          placeRelationships: doc.placeRelationships || [],
        }
      : null;
    return {
      select: () => ({
        lean: () => ({
          exec: async () => leanDoc,
          then: (resolve: any) => Promise.resolve(leanDoc).then(resolve),
        }),
        exec: async () => doc,
        then: (resolve: any) => Promise.resolve(doc).then(resolve),
      }),
      exec: async () => doc,
      then: (resolve: any) => Promise.resolve(doc).then(resolve),
    } as any;
  });
}

describe('Place-Based Classification, Residence & Guest View-Only Authorization', () => {
  const placeA = new mongoose.Types.ObjectId().toString();
  const placeB = new mongoose.Types.ObjectId().toString();
  let activeUserId: string | null = null;

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
    jest.spyOn(PlaceModel, 'findById').mockImplementation((id: any) => ({
      exec: async () => ({ _id: id, id: id?.toString(), canonicalName: 'Place' }),
      then: (r: any) =>
        Promise.resolve({ _id: id, id: id?.toString(), canonicalName: 'Place' }).then(r),
    } as any));
    jest.spyOn(placeRepository, 'findById').mockImplementation(async (id: any) => ({
      _id: id,
      id: id?.toString(),
      level: id === 'c1' ? 'COUNTRY' : id === 's1' ? 'STATE' : 'VILLAGE',
      canonicalName: id === 'c1' ? 'India' : id === 's1' ? 'Rajasthan' : 'Mandore',
      names: [
        {
          language: 'en',
          name: id === 'c1' ? 'India' : id === 's1' ? 'Rajasthan' : 'Mandore',
        },
      ],
    } as any));
    jest.spyOn(placeRepository, 'getAncestors').mockResolvedValue([
      { id: 'c1', level: 'COUNTRY', canonicalName: 'India' },
      { id: 's1', level: 'STATE', canonicalName: 'Rajasthan' },
    ]);
    jest.spyOn(claimRepository, 'findById').mockImplementation(async (id: any) => ({
      _id: id,
      id: id?.toString(),
      status: 'draft',
      title: { original: 'Title', language: 'en' },
      body: { original: 'Body text', language: 'en' },
      category: 'HISTORICAL_RECORD',
      locationId: placeA,
      locationPath: [placeA],
      submittedBy: activeUserId
        ? new mongoose.Types.ObjectId(activeUserId)
        : new mongoose.Types.ObjectId(),
      submittedAt: new Date(),
      evidenceIds: [],
    } as any));
  });

  it('1. No selected place produces Guest / View-only behavior and blocks claim & attribute submissions', async () => {
    const guestUserId = new mongoose.Types.ObjectId().toString();
    const guestUser = {
      _id: new mongoose.Types.ObjectId(guestUserId),
      id: guestUserId,
      displayName: 'Guest Contributor',
      email: 'guestcontributor@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: null, // No location selected -> Guest / View-only
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    mockUserModel(guestUser);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(guestUser as any);

    const token = generateTestToken(guestUser.role, guestUserId);

    // Attempt to submit a claim without selecting a location
    const claimRes = await request(app)
      .post('/api/v1/claims')
      .set('Authorization', `Bearer ${token}`)
      .send({
        title: { original: 'Title', language: 'en' },
        body: { original: 'Detailed body of the claim story here.', language: 'en' },
        category: 'HISTORICAL_RECORD',
        locationId: placeA,
      });

    expect(claimRes.status).toBe(403);
    expect(claimRes.body.error.message).toContain('No place selected. Guest / View-only mode');

    // Attempt to contribute a place attribute without selecting a location
    const attrRes = await request(app)
      .post(`/api/v1/places/${placeA}/attributes`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        category: 'population',
        key: 'population_total',
        value: '5000',
        sourceDescription: 'Census publication',
      });

    expect(attrRes.status).toBe(403);
    expect(attrRes.body.error.message).toContain('No place selected. Guest / View-only mode');
  });

  it('2. Backend authorization blocks contributions scoped to a place different from selectedPlaceId', async () => {
    const userAId = new mongoose.Types.ObjectId().toString();
    const userA = {
      _id: new mongoose.Types.ObjectId(userAId),
      id: userAId,
      displayName: 'Place A Resident',
      email: 'residenta@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: placeA, // Selected place is Place A
      placeRelationships: [
        {
          placeId: placeA,
          residenceType: 'Permanent',
          indigenousClassification: 'Indigenous',
          createdAt: new Date(),
        },
      ],
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    mockUserModel(userA);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(userA as any);

    const token = generateTestToken(userA.role, userAId);

    // User attempts to contribute to Place B while Place A is selected
    const claimRes = await request(app)
      .post('/api/v1/claims')
      .set('Authorization', `Bearer ${token}`)
      .send({
        title: { original: 'Title B', language: 'en' },
        body: { original: 'Detailed story about place B content.', language: 'en' },
        category: 'HISTORICAL_RECORD',
        locationId: placeB,
      });

    expect(claimRes.status).toBe(403);
    expect(claimRes.body.error.message).toContain('scoped to the currently selected place ID');

    // Attempt attribute on place B
    const attrRes = await request(app)
      .post(`/api/v1/places/${placeB}/attributes`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        category: 'population',
        key: 'population_total',
        value: '3000',
        sourceDescription: 'Census report',
      });

    expect(attrRes.status).toBe(403);
    expect(attrRes.body.error.message).toContain('scoped to the currently selected place ID');
  });

  it('3. Establishes place relationship with residence type (Permanent/Temporary) and explicit classification', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const user: any = {
      _id: new mongoose.Types.ObjectId(userId),
      id: userId,
      displayName: 'Relationship User',
      email: 'reluser@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: null,
      placeRelationships: [],
      isEmailVerified: true,
      save: jest.fn().mockImplementation(async function (this: any) {
        return this;
      }),
    };

    mockUserModel(user);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(user);
    jest.spyOn(placeRepository, 'findById').mockResolvedValue({
      _id: new mongoose.Types.ObjectId(placeA),
      id: placeA,
      canonicalName: 'Mandore',
    } as any);

    const token = generateTestToken(user.role, userId);

    // Save place relationship with residenceType 'Permanent' and explicit 'Indigenous' classification
    const updateRes = await request(app)
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({
        selectedPlaceId: placeA,
        placeRelationship: {
          placeId: placeA,
          residenceType: 'Permanent',
          indigenousClassification: 'Indigenous',
        },
      });

    expect(updateRes.status).toBe(200);
    expect(updateRes.body.data.selectedPlaceId).toBe(placeA);
    expect(updateRes.body.data.indigenousClassification).toBe('Indigenous');
    expect(updateRes.body.data.currentPlaceRelationship).toMatchObject({
      placeId: placeA,
      residenceType: 'Permanent',
      indigenousClassification: 'Indigenous',
    });
    expect(updateRes.body.data.placeRelationships).toHaveLength(1);
  });

  it('4. Switching places refreshes place context, relationship & classification without retaining stale data', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const user: any = {
      _id: new mongoose.Types.ObjectId(userId),
      id: userId,
      displayName: 'Multi Place User',
      email: 'multiplace@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: placeA,
      placeRelationships: [
        {
          placeId: placeA,
          residenceType: 'Permanent',
          indigenousClassification: 'Indigenous',
          createdAt: new Date(),
        },
        {
          placeId: placeB,
          residenceType: 'Temporary',
          indigenousClassification: 'Non-Indigenous',
          createdAt: new Date(),
        },
      ],
      isEmailVerified: true,
      save: jest.fn().mockImplementation(async function (this: any) {
        return this;
      }),
    };

    mockUserModel(user);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(user);

    const token = generateTestToken(user.role, userId);

    // When place A is selected: classification is Indigenous
    const meResA = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(meResA.status).toBe(200);
    expect(meResA.body.data.selectedPlaceId).toBe(placeA);
    expect(meResA.body.data.indigenousClassification).toBe('Indigenous');
    expect(meResA.body.data.currentPlaceRelationship.residenceType).toBe('Permanent');

    // Switch selected place to Place B
    jest.spyOn(placeRepository, 'findById').mockResolvedValue({
      _id: new mongoose.Types.ObjectId(placeB),
      id: placeB,
      canonicalName: 'Jodhpur City',
    } as any);

    const switchRes = await request(app)
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ selectedPlaceId: placeB });

    expect(switchRes.status).toBe(200);
    expect(switchRes.body.data.selectedPlaceId).toBe(placeB);
    // Verified: Classification dynamically switched to Place B's 'Non-Indigenous'
    expect(switchRes.body.data.indigenousClassification).toBe('Non-Indigenous');
    expect(switchRes.body.data.currentPlaceRelationship.residenceType).toBe('Temporary');

    // Deselect place (back to guest view-only)
    const deselectRes = await request(app)
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ selectedPlaceId: null });

    expect(deselectRes.status).toBe(200);
    expect(deselectRes.body.data.selectedPlaceId).toBeNull();
    // Classification must be null when no place selected
    expect(deselectRes.body.data.indigenousClassification).toBeNull();
    expect(deselectRes.body.data.currentPlaceRelationship).toBeNull();
  });

  it('5. Both Indigenous and Non-Indigenous users can contribute under the same applicable rules', async () => {
    const indUserId = new mongoose.Types.ObjectId().toString();
    const indUser: any = {
      _id: new mongoose.Types.ObjectId(indUserId),
      id: indUserId,
      displayName: 'Indigenous Contributor',
      email: 'indig@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: placeA,
      placeRelationships: [
        {
          placeId: placeA,
          residenceType: 'Permanent',
          indigenousClassification: 'Indigenous',
          createdAt: new Date(),
        },
      ],
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    const nonIndUserId = new mongoose.Types.ObjectId().toString();
    const nonIndUser: any = {
      _id: new mongoose.Types.ObjectId(nonIndUserId),
      id: nonIndUserId,
      displayName: 'Non-Indigenous Contributor',
      email: 'nonindig@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: placeA,
      placeRelationships: [
        {
          placeId: placeA,
          residenceType: 'Temporary',
          indigenousClassification: 'Non-Indigenous',
          createdAt: new Date(),
        },
      ],
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };


    jest.spyOn(placeRepository, 'getAncestors').mockResolvedValue([
      { id: 'c1', level: 'COUNTRY', canonicalName: 'India' },
      { id: 's1', level: 'STATE', canonicalName: 'Rajasthan' },
    ]);
    jest.spyOn(claimRepository, 'create').mockImplementation(async (d: any) => ({
      ...d,
      _id: new mongoose.Types.ObjectId(),
      id: 'claim-123',
      status: 'draft',
    }));
    jest.spyOn(placeAttributeRepository, 'create').mockImplementation(async (d: any) => ({
      ...d,
      _id: new mongoose.Types.ObjectId(),
      id: 'attr-123',
    }));

    // Indigenous user submits claim
    activeUserId = indUserId;
    mockUserModel(indUser);

    const indToken = generateTestToken(indUser.role, indUserId);
    const indRes = await request(app)
      .post('/api/v1/claims')
      .set('Authorization', `Bearer ${indToken}`)
      .send({
        title: { original: 'Title Indigenous', language: 'en' },
        body: { original: 'Body story text with sufficient length.', language: 'en' },
        category: 'HISTORICAL_RECORD',
        locationId: placeA,
      });
    expect(indRes.status).toBe(201);

    // Non-Indigenous user submits claim under the same rules
    activeUserId = nonIndUserId;
    mockUserModel(nonIndUser);

    const nonIndToken = generateTestToken(nonIndUser.role, nonIndUserId);
    const nonIndRes = await request(app)
      .post('/api/v1/claims')
      .set('Authorization', `Bearer ${nonIndToken}`)
      .send({
        title: { original: 'Title Non-Indigenous', language: 'en' },
        body: { original: 'Body story text with sufficient length.', language: 'en' },
        category: 'HISTORICAL_RECORD',
        locationId: placeA,
      });
    expect(nonIndRes.status).toBe(201);

    // Both can also submit attributes under the same rules
    mockUserModel(indUser);
    const indAttr = await request(app)
      .post(`/api/v1/places/${placeA}/attributes`)
      .set('Authorization', `Bearer ${indToken}`)
      .send({
        category: 'facility',
        key: 'primary_school_count',
        value: '4',
        sourceDescription: 'Education Dept gazette',
      });
    expect(indAttr.status).toBe(201);

    mockUserModel(nonIndUser);
    const nonIndAttr = await request(app)
      .post(`/api/v1/places/${placeA}/attributes`)
      .set('Authorization', `Bearer ${nonIndToken}`)
      .send({
        category: 'facility',
        key: 'secondary_school_count',
        value: '2',
        sourceDescription: 'Education Dept gazette',
      });
    expect(nonIndAttr.status).toBe(201);
  });

  it('6. Rejects forging placeRelationship with non-existent placeId', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const fakePlaceId = new mongoose.Types.ObjectId().toString();
    const user: any = {
      _id: new mongoose.Types.ObjectId(userId),
      id: userId,
      displayName: 'Forge Test User',
      email: 'forge@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: null,
      placeRelationships: [],
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    mockUserModel(user);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(user as any);
    jest.spyOn(PlaceModel, 'findById').mockImplementation((id: any) => ({
      exec: async () => null, // Place does not exist!
      then: (r: any) => Promise.resolve(null).then(r),
    } as any));

    const token = generateTestToken(user.role, userId);

    const res = await request(app)
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({
        placeRelationship: {
          placeId: fakePlaceId,
          residenceType: 'Permanent',
          indigenousClassification: 'Indigenous',
        },
      });

    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
    expect(res.body.error.message).toContain('Place');
  });

  it('7. Preserves unrelated place relationships when updating a new place', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const existingRel = {
      placeId: placeA,
      residenceType: 'Permanent',
      indigenousClassification: 'Indigenous',
      createdAt: new Date('2026-01-01'),
    };
    const user: any = {
      _id: new mongoose.Types.ObjectId(userId),
      id: userId,
      displayName: 'Multi-Place User',
      email: 'multi@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: placeA,
      placeRelationships: [existingRel],
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    mockUserModel(user);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(user as any);
    jest.spyOn(PlaceModel, 'findById').mockImplementation((id: any) => ({
      exec: async () => ({ _id: id, id: id?.toString() }),
      then: (r: any) => Promise.resolve({ _id: id, id: id?.toString() }).then(r),
    } as any));

    const token = generateTestToken(user.role, userId);

    const res = await request(app)
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({
        placeRelationship: {
          placeId: placeB,
          residenceType: 'Temporary',
          indigenousClassification: 'Non-Indigenous',
        },
      });

    expect(res.status).toBe(200);
    expect(user.placeRelationships).toHaveLength(2);
    // Unrelated place A relationship remains unaltered
    const relA = user.placeRelationships.find((r: any) => r.placeId === placeA);
    expect(relA.residenceType).toBe('Permanent');
    expect(relA.indigenousClassification).toBe('Indigenous');
    // Place B added correctly
    const relB = user.placeRelationships.find((r: any) => r.placeId === placeB);
    expect(relB.residenceType).toBe('Temporary');
    expect(relB.indigenousClassification).toBe('Non-Indigenous');
  });

  it('8. Rejects selecting a place without explicit Indigenous or Non-Indigenous classification', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const user: any = {
      _id: new mongoose.Types.ObjectId(userId),
      id: userId,
      displayName: 'Unclassified Select User',
      email: 'unclassified@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: null,
      placeRelationships: [],
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    mockUserModel(user);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(user as any);

    const token = generateTestToken(user.role, userId);

    const res = await request(app)
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({ selectedPlaceId: placeA });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
    expect(res.body.error.message).toContain('Indigenous or Non-Indigenous classification');
  });

  it('9. Rejects placeRelationship with invalid classification (e.g. pending or invalid)', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const user: any = {
      _id: new mongoose.Types.ObjectId(userId),
      id: userId,
      displayName: 'Invalid Rel User',
      email: 'invalidrel@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: null,
      placeRelationships: [],
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    mockUserModel(user);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(user as any);

    const token = generateTestToken(user.role, userId);

    const res = await request(app)
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .send({
        placeRelationship: {
          placeId: placeA,
          indigenousClassification: 'Pending',
        },
      });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('10. Users with no selected place are blocked from submitting evidence', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const user: any = {
      _id: new mongoose.Types.ObjectId(userId),
      id: userId,
      displayName: 'Guest Evidence User',
      email: 'guestev@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: null,
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    mockUserModel(user);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(user as any);

    const token = generateTestToken(user.role, userId);

    const res = await request(app)
      .post('/api/v1/evidence')
      .set('Authorization', `Bearer ${token}`)
      .send({
        claimId: new mongoose.Types.ObjectId().toString(),
        sourceType: 'DOCUMENT',
        title: 'Evidence Doc',
        description: 'Detailed description of the evidence',
      });

    expect(res.status).toBe(403);
    expect(res.body.error.message).toContain('No place selected. Guest / View-only mode');
  });

  it('11. Users with no selected place can submit feedback (agree, disagree, wrong) on verified claims', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const claimId = new mongoose.Types.ObjectId().toString();
    const user: any = {
      _id: new mongoose.Types.ObjectId(userId),
      id: userId,
      displayName: 'Feedback Guest User',
      email: 'feedbackguest@example.com',
      role: USER_ROLES.CONTRIBUTOR,
      selectedPlaceId: null,
      isEmailVerified: true,
      save: jest.fn().mockResolvedValue(true),
    };

    mockUserModel(user);
    jest.spyOn(authRepository, 'findById').mockResolvedValue(user as any);
    jest.spyOn(claimRepository, 'findById').mockResolvedValue({
      _id: new mongoose.Types.ObjectId(claimId),
      id: claimId,
      status: 'verified',
      isPublic: true,
      submittedBy: new mongoose.Types.ObjectId(),
      locationId: placeA,
      locationPath: [placeA],
    } as any);
    jest.spyOn(claimRepository, 'update').mockResolvedValue({} as any);

    const token = generateTestToken(user.role, userId);

    const res = await request(app)
      .post(`/api/v1/claims/${claimId}/feedback`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        agreement: 'disagree',
        comment: 'This record appears incorrect based on local records.',
      });

    expect([200, 201]).toContain(res.status);
  });
});

