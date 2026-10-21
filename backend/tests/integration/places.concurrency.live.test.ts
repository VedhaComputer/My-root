import mongoose from 'mongoose';
import { PlaceService } from '../../src/modules/places/service';
import { PlaceRepository } from '../../src/modules/places/repository';
import { PlaceModel } from '../../src/modules/places/place.model';
import { PLACE_LEVELS } from '../../src/shared/constants';
import {
  NotFoundError,
  BusinessRuleError,
} from '../../src/shared/errors/AppError';

// Target port and test database configuration
const TEST_PORT = 27018;
const TEST_DB = 'myroot_concurrency_test';
const TEST_URI = `mongodb://127.0.0.1:${TEST_PORT}/${TEST_DB}?directConnection=true`;

describe('Places Live MongoDB Replica-Set Concurrency Tests', () => {
  let realRepo: PlaceRepository;
  let realService: PlaceService;
  const createdPlaceIds: string[] = [];

  beforeAll(async () => {
    // 1. Establish connection to isolated test replica set
    await mongoose.connect(TEST_URI, {
      serverSelectionTimeoutMS: 5000,
    });

    // 2. Strict Environment & Safety Guard: Assert connection properties
    const conn = mongoose.connection;
    const admin = conn.db!.admin();
    const helloRes = await admin.command({ hello: 1 });

    if (conn.port !== TEST_PORT) {
      throw new Error(`SAFETY BLOCKER: Expected port ${TEST_PORT}, but connected to ${conn.port}`);
    }
    if (conn.name !== TEST_DB) {
      throw new Error(`SAFETY BLOCKER: Expected database ${TEST_DB}, but connected to ${conn.name}`);
    }
    if (helloRes.setName !== 'rs0') {
      throw new Error(`SAFETY BLOCKER: Expected replica set rs0, but found ${helloRes.setName}`);
    }
    if (!helloRes.isWritablePrimary) {
      throw new Error('SAFETY BLOCKER: Connected node is not a writable primary');
    }

    realRepo = new PlaceRepository();
    realService = new PlaceService(realRepo);
  }, 15000);

  afterAll(async () => {
    // Clean up only the records created by these tests
    if (createdPlaceIds.length > 0) {
      await PlaceModel.deleteMany({ _id: { $in: createdPlaceIds } }).exec();
    }
    await mongoose.disconnect();
  }, 15000);

  afterEach(async () => {
    // Cleanup records tracked in this suite
    if (createdPlaceIds.length > 0) {
      await PlaceModel.deleteMany({ _id: { $in: createdPlaceIds } }).exec();
      createdPlaceIds.length = 0;
    }
  });

  describe('Scenario 1: Child Create vs. Parent Delete (Real Concurrent Overlap)', () => {
    it('prevents orphaned children when parent deletion overlaps with child creation', async () => {
      // Setup hierarchy: Country -> State -> District
      const country = await realRepo.create({
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: `LiveTest-Country-${Date.now()}`,
        names: [{ language: 'en', name: 'Live Country' }],
        parentId: null,
      });
      createdPlaceIds.push(country._id.toString());

      const state = await realRepo.create({
        level: PLACE_LEVELS.STATE,
        canonicalName: `LiveTest-State-${Date.now()}`,
        names: [{ language: 'en', name: 'Live State' }],
        parentId: country._id.toString(),
      });
      createdPlaceIds.push(state._id.toString());

      const district = await realRepo.create({
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: `LiveTest-District-${Date.now()}`,
        names: [{ language: 'en', name: 'Live District' }],
        parentId: state._id.toString(),
      });
      createdPlaceIds.push(district._id.toString());

      const tehsil = await realRepo.create({
        level: PLACE_LEVELS.TEHSIL,
        canonicalName: `LiveTest-Tehsil-${Date.now()}`,
        names: [{ language: 'en', name: 'Live Tehsil' }],
        parentId: district._id.toString(),
      });
      const tehsilId = tehsil._id.toString();
      createdPlaceIds.push(tehsilId);

      const childCanonical = `LiveTest-City-${Date.now()}`;

      // Launch genuine concurrent overlap:
      // Worker A attempts to delete the parent Tehsil
      // Worker B attempts to create a child City under that parent Tehsil
      const [deleteResult, createResult] = await Promise.allSettled([
        realService.deletePlace(tehsilId),
        realService.createPlace({
          level: PLACE_LEVELS.CITY_TOWN,
          canonicalName: childCanonical,
          names: [{ language: 'en', name: 'Live City' }],
          parentId: tehsilId,
        }),
      ]);

      if (createResult.status === 'fulfilled') {
        createdPlaceIds.push(createResult.value.id);
      }

      // Assert mutual exclusion under WiredTiger write conflict serialization:
      if (deleteResult.status === 'fulfilled') {
        // Parent deletion succeeded. Child creation MUST have failed.
        expect(createResult.status).toBe('rejected');
        const reason = (createResult as PromiseRejectedResult).reason;
        expect(reason).toBeInstanceOf(NotFoundError);

        // Verify persisted database state: Parent is deleted, child is NOT in database
        const persistedParent = await PlaceModel.findById(tehsilId).exec();
        expect(persistedParent).toBeNull();

        const persistedChild = await PlaceModel.findOne({ canonicalName: childCanonical }).exec();
        expect(persistedChild).toBeNull();
      } else {
        // Child creation succeeded. Parent deletion MUST have failed.
        expect(createResult.status).toBe('fulfilled');
        expect(deleteResult.status).toBe('rejected');
        const reason = (deleteResult as PromiseRejectedResult).reason;
        expect(reason).toBeInstanceOf(BusinessRuleError);

        // Verify persisted database state: Parent exists, child exists referencing parent
        const persistedParent = await PlaceModel.findById(tehsilId).exec();
        expect(persistedParent).not.toBeNull();

        const persistedChild = await PlaceModel.findOne({ canonicalName: childCanonical }).exec();
        expect(persistedChild).not.toBeNull();
        expect(persistedChild!.parentId!.toString()).toBe(tehsilId);
      }
    }, 20000);
  });

  describe('Scenario 2: Reparenting vs. Target Parent Deletion (Real Concurrent Overlap)', () => {
    it('prevents reparenting a place to a concurrently deleted parent', async () => {
      const country = await realRepo.create({
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: `LiveTest-Country-2-${Date.now()}`,
        names: [{ language: 'en', name: 'Live Country 2' }],
        parentId: null,
      });
      createdPlaceIds.push(country._id.toString());

      const state = await realRepo.create({
        level: PLACE_LEVELS.STATE,
        canonicalName: `LiveTest-State-2-${Date.now()}`,
        names: [{ language: 'en', name: 'Live State 2' }],
        parentId: country._id.toString(),
      });
      createdPlaceIds.push(state._id.toString());

      const dist = await realRepo.create({
        level: PLACE_LEVELS.DISTRICT,
        canonicalName: `LiveTest-Dist-2-${Date.now()}`,
        names: [{ language: 'en', name: 'Dist 2' }],
        parentId: state._id.toString(),
      });
      createdPlaceIds.push(dist._id.toString());

      const tehsilOld = await realRepo.create({
        level: PLACE_LEVELS.TEHSIL,
        canonicalName: `LiveTest-TehsilOld-${Date.now()}`,
        names: [{ language: 'en', name: 'Tehsil Old' }],
        parentId: dist._id.toString(),
      });
      createdPlaceIds.push(tehsilOld._id.toString());

      const tehsilTarget = await realRepo.create({
        level: PLACE_LEVELS.TEHSIL,
        canonicalName: `LiveTest-TehsilTarget-${Date.now()}`,
        names: [{ language: 'en', name: 'Tehsil Target' }],
        parentId: dist._id.toString(),
      });
      const tehsilTargetId = tehsilTarget._id.toString();
      createdPlaceIds.push(tehsilTargetId);

      const city = await realRepo.create({
        level: PLACE_LEVELS.CITY_TOWN,
        canonicalName: `LiveTest-CityMove-${Date.now()}`,
        names: [{ language: 'en', name: 'Moving City' }],
        parentId: tehsilOld._id.toString(),
      });
      const cityId = city._id.toString();
      createdPlaceIds.push(cityId);

      // Concurrent overlap:
      // Worker A attempts to delete Target Tehsil
      // Worker B attempts to move City under Target Tehsil
      const [deleteResult, reparentResult] = await Promise.allSettled([
        realService.deletePlace(tehsilTargetId),
        realService.updatePlace(cityId, { parentId: tehsilTargetId }),
      ]);

      if (deleteResult.status === 'fulfilled') {
        // Target parent was deleted. Reparenting MUST fail.
        expect(reparentResult.status).toBe('rejected');
        const reason = (reparentResult as PromiseRejectedResult).reason;
        expect(reason).toBeInstanceOf(NotFoundError);

        // Verify persisted state: Target parent is gone; City still points to Old Tehsil
        const persistedTarget = await PlaceModel.findById(tehsilTargetId).exec();
        expect(persistedTarget).toBeNull();

        const persistedCity = await PlaceModel.findById(cityId).exec();
        expect(persistedCity!.parentId!.toString()).toBe(tehsilOld._id.toString());
      } else {
        // Reparenting succeeded. Deletion of Target Tehsil MUST fail because it now has children.
        expect(reparentResult.status).toBe('fulfilled');
        expect(deleteResult.status).toBe('rejected');

        const persistedTarget = await PlaceModel.findById(tehsilTargetId).exec();
        expect(persistedTarget).not.toBeNull();

        const persistedCity = await PlaceModel.findById(cityId).exec();
        expect(persistedCity!.parentId!.toString()).toBe(tehsilTargetId);
      }
    }, 20000);
  });

  describe('Scenario 3: Parent Level Change vs. Child Creation (Real Concurrent Overlap)', () => {
    it('maintains hierarchy validity when parent level update overlaps with child creation', async () => {
      const country = await realRepo.create({
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: `LiveTest-Country-3-${Date.now()}`,
        names: [{ language: 'en', name: 'Live Country 3' }],
        parentId: null,
      });
      createdPlaceIds.push(country._id.toString());

      const state = await realRepo.create({
        level: PLACE_LEVELS.STATE,
        canonicalName: `LiveTest-State-3-${Date.now()}`,
        names: [{ language: 'en', name: 'Live State 3' }],
        parentId: country._id.toString(),
      });
      createdPlaceIds.push(state._id.toString());

      const hub = await realRepo.create({
        level: PLACE_LEVELS.STATE,
        canonicalName: `LiveTest-Hub-${Date.now()}`,
        names: [{ language: 'en', name: 'Hub Place' }],
        parentId: country._id.toString(),
      });
      const hubId = hub._id.toString();
      createdPlaceIds.push(hubId);

      const childCanonical = `LiveTest-Child-${Date.now()}`;

      // Worker A attempts to downgrade Hub from STATE to DISTRICT.
      // Worker B attempts to create a child of level STATE under Hub.
      // Under ALLOWED_PARENT_LEVELS, STATE cannot be under DISTRICT!
      const [updateResult, createResult] = await Promise.allSettled([
        realService.updatePlace(hubId, { level: PLACE_LEVELS.DISTRICT, parentId: state._id.toString() }),
        realService.createPlace({
          level: PLACE_LEVELS.STATE,
          canonicalName: childCanonical,
          names: [{ language: 'en', name: 'Candidate State Child' }],
          parentId: hubId,
        }),
      ]);

      if (createResult.status === 'fulfilled') {
        createdPlaceIds.push(createResult.value.id);
      }

      // Assert that either:
      // A) Hub became DISTRICT, and child creation was blocked/rejected.
      // B) Child of level STATE was created, and Hub could not be downgraded to DISTRICT.
      const persistedHub = await PlaceModel.findById(hubId).exec();
      const persistedChild = await PlaceModel.findOne({ canonicalName: childCanonical }).exec();

      if (updateResult.status === 'fulfilled') {
        expect(persistedHub!.level).toBe(PLACE_LEVELS.DISTRICT);
        expect(persistedChild).toBeNull();
      } else {
        expect(createResult.status).toBe('fulfilled');
        expect(persistedHub!.level).toBe(PLACE_LEVELS.STATE);
        expect(persistedChild).not.toBeNull();
      }
    }, 20000);
  });

  describe('Scenario 4: Real Transaction Write Conflict & Retry Hierarchy Re-validation', () => {
    it('handles concurrent sibling creations under same parent with automatic retry and consistency', async () => {
      const country = await realRepo.create({
        level: PLACE_LEVELS.COUNTRY,
        canonicalName: `LiveTest-Country-4-${Date.now()}`,
        names: [{ language: 'en', name: 'Live Country 4' }],
        parentId: null,
      });
      createdPlaceIds.push(country._id.toString());

      const state = await realRepo.create({
        level: PLACE_LEVELS.STATE,
        canonicalName: `LiveTest-State-4-${Date.now()}`,
        names: [{ language: 'en', name: 'Live State 4' }],
        parentId: country._id.toString(),
      });
      const stateId = state._id.toString();
      createdPlaceIds.push(stateId);

      // Launch 3 simultaneous creations under State.
      // All 3 compete to touch State (__v increment), creating WiredTiger write conflicts.
      // withTransaction must automatically retry transient conflicts and commit all 3.
      const creations = await Promise.all([
        realService.createPlace({
          level: PLACE_LEVELS.DISTRICT,
          canonicalName: `Sibling-1-${Date.now()}`,
          names: [{ language: 'en', name: 'Sib 1' }],
          parentId: stateId,
        }),
        realService.createPlace({
          level: PLACE_LEVELS.DISTRICT,
          canonicalName: `Sibling-2-${Date.now()}`,
          names: [{ language: 'en', name: 'Sib 2' }],
          parentId: stateId,
        }),
        realService.createPlace({
          level: PLACE_LEVELS.DISTRICT,
          canonicalName: `Sibling-3-${Date.now()}`,
          names: [{ language: 'en', name: 'Sib 3' }],
          parentId: stateId,
        }),
      ]);

      creations.forEach((c) => createdPlaceIds.push(c.id));

      expect(creations).toHaveLength(3);

      // Verify all 3 persisted properly in database
      const children = await PlaceModel.find({ parentId: stateId }).exec();
      expect(children).toHaveLength(3);

      // Verify parent was touched (version increased from original 0 to at least 3)
      const persistedState = await PlaceModel.findById(stateId).exec();
      expect(persistedState!.__v).toBeGreaterThanOrEqual(3);
    }, 20000);
  });
});
