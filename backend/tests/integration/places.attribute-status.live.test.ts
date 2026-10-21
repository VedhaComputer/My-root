import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { createApp } from '../../src/app';
import { PlaceAttributeModel } from '../../src/modules/places/placeAttribute.model';
import { env } from '../../src/config/env';
import { USER_ROLES, UserRole } from '../../src/shared/constants';

const TEST_URI = 'mongodb://127.0.0.1:27017/myroot_test';
const app = createApp();

function generateTestToken(role: UserRole, userId: string, tokenVersion = 1): string {
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

describe('Live MongoDB Regression: Missing-Status Place Attribute Exclusion', () => {
  const trackedDocIds: mongoose.Types.ObjectId[] = [];
  const testPlaceId = new mongoose.Types.ObjectId();
  const authorUserId = new mongoose.Types.ObjectId();
  const readerUserId = new mongoose.Types.ObjectId();

  let originalFallback: string | undefined;

  beforeAll(async () => {
    originalFallback = process.env.JWT_ALLOW_HS256_FALLBACK;
    process.env.JWT_ALLOW_HS256_FALLBACK = 'true';

    // 1. Establish connection to isolated test database
    await mongoose.connect(TEST_URI, {
      serverSelectionTimeoutMS: 5000,
    });

    // 2. Strict Environment & Database Safety Guard
    const resolvedDbName = mongoose.connection.name;
    const resolvedPort = mongoose.connection.port;

    if (
      mongoose.connection.readyState !== 1 ||
      !resolvedDbName ||
      !resolvedDbName.endsWith('_test') ||
      resolvedDbName === 'myroot' ||
      resolvedDbName === 'admin' ||
      resolvedDbName === 'config' ||
      resolvedDbName === 'local'
    ) {
      throw new Error(
        `SAFETY BLOCKER: Refusing to proceed. Resolved database '${resolvedDbName}' on port ${resolvedPort} is NOT a verified isolated test database.`
      );
    }
  });

  afterAll(async () => {
    // Clean up ONLY the exact documents created by this test, even if assertions failed
    try {
      if (trackedDocIds.length > 0 && mongoose.connection.readyState === 1) {
        await PlaceAttributeModel.collection.deleteMany({
          _id: { $in: trackedDocIds },
        });
      }
    } finally {
      await mongoose.disconnect();
      if (originalFallback === undefined) {
        delete process.env.JWT_ALLOW_HS256_FALLBACK;
      } else {
        process.env.JWT_ALLOW_HS256_FALLBACK = originalFallback;
      }
    }
  });

  it('excludes place-attribute document with missing status field from GET /api/v1/places/:id/attributes for authenticated non-privileged user', async () => {
    // Safety verification directly prior to write operation
    const resolvedDbName = mongoose.connection.name;
    expect(resolvedDbName).toBe('myroot_test');
    if (resolvedDbName !== 'myroot_test') {
      throw new Error(`SAFETY BLOCKER: Unexpected database '${resolvedDbName}'. Refusing to write.`);
    }

    const missingStatusId = new mongoose.Types.ObjectId();
    const verifiedStatusId = new mongoose.Types.ObjectId();

    // Insert directly via raw collection API to strictly bypass Mongoose schema default (status: 'pending_review')
    const rawDocMissingStatus = {
      _id: missingStatusId,
      placeId: testPlaceId,
      category: 'facility',
      key: 'Historical Stepwell',
      value: 'Ancient subterranean water structure',
      sourceDescription: 'Imperial Gazetteer 1908',
      submittedBy: authorUserId,
      // status field is deliberately omitted to represent an unmanaged/missing-status record
      history: [],
      isLatest: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const rawDocVerifiedStatus = {
      _id: verifiedStatusId,
      placeId: testPlaceId,
      category: 'facility',
      key: 'Primary Healthcare Centre',
      value: 'Functional government health dispensary',
      sourceDescription: 'District Health Report 2022',
      submittedBy: authorUserId,
      status: 'verified',
      history: [],
      isLatest: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    // Track IDs immediately for guaranteed teardown cleanup
    trackedDocIds.push(missingStatusId, verifiedStatusId);

    // Insert raw documents directly into the verified isolated test collection
    await PlaceAttributeModel.collection.insertMany([rawDocMissingStatus, rawDocVerifiedStatus]);

    // Verify raw document state in live MongoDB to confirm status field is truly absent
    const rawSavedMissing = await PlaceAttributeModel.collection.findOne({ _id: missingStatusId });
    expect(rawSavedMissing).toBeDefined();
    expect(rawSavedMissing).not.toHaveProperty('status');

    const rawSavedVerified = await PlaceAttributeModel.collection.findOne({ _id: verifiedStatusId });
    expect(rawSavedVerified).toBeDefined();
    expect(rawSavedVerified?.status).toBe('verified');

    // Generate token for a non-privileged contributor who is NOT the author of the attributes
    const readerToken = generateTestToken(USER_ROLES.CONTRIBUTOR, readerUserId.toString());

    // Execute actual HTTP request through the Express API stack against live MongoDB
    const res = await request(app)
      .get(`/api/v1/places/${testPlaceId.toString()}/attributes`)
      .set('Authorization', `Bearer ${readerToken}`);

    // Verify HTTP response
    expect(res.status).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);

    const returnedKeys = res.body.data.map((item: any) => item.key);
    const returnedIds = res.body.data.map((item: any) => item._id || item.id);

    // Verified attribute must be included in the public response
    expect(returnedKeys).toContain('Primary Healthcare Centre');
    expect(returnedIds).toContain(verifiedStatusId.toString());

    // Attribute with missing status must be strictly EXCLUDED from the public response
    expect(returnedKeys).not.toContain('Historical Stepwell');
    expect(returnedIds).not.toContain(missingStatusId.toString());
  });
});
