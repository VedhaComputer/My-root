import mongoose, { ClientSession } from 'mongoose';
import { PlaceService } from '../../src/modules/places/service';
import { PlaceRepository } from '../../src/modules/places/repository';
import { PlaceModel } from '../../src/modules/places/place.model';
import { PLACE_LEVELS } from '../../src/shared/constants';

// Target port and test database configuration
const TEST_PORT = 27018;
const TEST_DB = 'myroot_concurrency_test';
const TEST_URI = `mongodb://127.0.0.1:${TEST_PORT}/${TEST_DB}?directConnection=true&monitorCommands=true`;

describe('Places Real MongoDB WriteConflict & Driver Retry Direct Proof (Live Replica Set)', () => {
  let realRepo: PlaceRepository;
  let realService: PlaceService;
  const createdPlaceIds: string[] = [];

  // Telemetry collected directly from MongoDB driver events
  const driverCommandFailedEvents: Array<{
    commandName: string;
    code?: number;
    message?: string;
    hasTransientLabel?: boolean;
    errorLabels?: string[];
  }> = [];

  beforeAll(async () => {
    // 1. Establish connection to isolated test replica set with command monitoring enabled
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

    // 3. Register real driver-level APM command listener on MongoClient
    const client = conn.getClient();
    client.on('commandFailed', (event: any) => {
      const failure = event.failure;
      driverCommandFailedEvents.push({
        commandName: event.commandName,
        code: failure?.code,
        message: failure?.message,
        hasTransientLabel: failure?.hasErrorLabel?.('TransientTransactionError') ?? false,
        errorLabels: failure?.errorLabels,
      });
    });

    realRepo = new PlaceRepository();
    realService = new PlaceService(realRepo);
  }, 15000);

  afterAll(async () => {
    if (createdPlaceIds.length > 0) {
      await PlaceModel.deleteMany({ _id: { $in: createdPlaceIds } }).exec();
    }
    await mongoose.disconnect();
  }, 15000);

  afterEach(async () => {
    if (createdPlaceIds.length > 0) {
      await PlaceModel.deleteMany({ _id: { $in: createdPlaceIds } }).exec();
      createdPlaceIds.length = 0;
    }
    driverCommandFailedEvents.length = 0;
  });

  it('captures direct evidence of real MongoDB WriteConflict (code 112) and driver automatic retry', async () => {
    // Setup Parent hierarchy in MongoDB: Country -> State
    const country = await realRepo.create({
      level: PLACE_LEVELS.COUNTRY,
      canonicalName: `RetryProof-Country-${Date.now()}`,
      names: [{ language: 'en', name: 'Proof Country' }],
      parentId: null,
    });
    createdPlaceIds.push(country._id.toString());

    const state = await realRepo.create({
      level: PLACE_LEVELS.STATE,
      canonicalName: `RetryProof-State-${Date.now()}`,
      names: [{ language: 'en', name: 'Proof State' }],
      parentId: country._id.toString(),
    });
    const stateId = state._id.toString();
    createdPlaceIds.push(stateId);

    // Test-local telemetry for tracking callback invocations (driver retries)
    let worker1Invocations = 0;
    let worker2Invocations = 0;

    const child1Canonical = `Child-Worker1-${Date.now()}`;
    const child2Canonical = `Child-Worker2-${Date.now()}`;

    // Worker 1: Creates child 1 and holds parent lock briefly to guarantee overlap
    const runWorker1 = async () => {
      return await realRepo.withTransaction(async (session: ClientSession) => {
        worker1Invocations++;
        // Lock parent document
        const lockedParent = await realRepo.touch(stateId, session);
        if (!lockedParent) throw new Error('Parent not found');

        // Hold transaction open briefly while holding lock on stateId
        await new Promise((resolve) => setTimeout(resolve, 200));

        const created = await realRepo.create(
          {
            level: PLACE_LEVELS.DISTRICT,
            canonicalName: child1Canonical,
            names: [{ language: 'en', name: 'Child 1' }],
            parentId: stateId,
          },
          session
        );
        return created;
      });
    };

    // Worker 2: Competes to lock the exact same parent document (stateId) while Worker 1 holds it
    const runWorker2 = async () => {
      return await realRepo.withTransaction(async (session: ClientSession) => {
        worker2Invocations++;
        // Small delay to ensure Worker 1 has already acquired the document write lock
        await new Promise((resolve) => setTimeout(resolve, 50));

        // Attempting to touch stateId here will encounter write contention / conflict
        const lockedParent = await realRepo.touch(stateId, session);
        if (!lockedParent) throw new Error('Parent not found');

        const created = await realRepo.create(
          {
            level: PLACE_LEVELS.DISTRICT,
            canonicalName: child2Canonical,
            names: [{ language: 'en', name: 'Child 2' }],
            parentId: stateId,
          },
          session
        );
        return created;
      });
    };

    // Execute both conflicting workers concurrently
    const [result1, result2] = await Promise.all([runWorker1(), runWorker2()]);

    createdPlaceIds.push(result1._id.toString());
    createdPlaceIds.push(result2._id.toString());

    // --- DIRECT PROOF 1: Driver Callback Invocations (Retries) ---
    const totalInvocations = worker1Invocations + worker2Invocations;
    // Exactly 2 transactions were submitted. If any was retried, totalInvocations must be > 2.
    expect(totalInvocations).toBeGreaterThan(2);
    // Specifically, Worker 2 had to retry due to lock collision
    expect(worker2Invocations).toBeGreaterThanOrEqual(2);

    // --- DIRECT PROOF 2: MongoDB Driver Command Failed with Transient Transaction Error (WriteConflict 112 / LockTimeout 24) ---
    const writeConflictEvents = driverCommandFailedEvents.filter(
      (e) => (e.code === 112 || e.code === 24) && e.hasTransientLabel === true
    );
    expect(writeConflictEvents.length).toBeGreaterThanOrEqual(1);

    const firstConflict = writeConflictEvents[0];
    expect([112, 24]).toContain(firstConflict.code);
    expect(firstConflict.errorLabels).toContain('TransientTransactionError');

    // --- DIRECT PROOF 3: Final Persisted Database Invariants ---
    // 1. Both children were successfully persisted in MongoDB
    const persistedChildren = await PlaceModel.find({ parentId: stateId }).exec();
    expect(persistedChildren).toHaveLength(2);

    const names = persistedChildren.map((c) => c.canonicalName);
    expect(names).toContain(child1Canonical);
    expect(names).toContain(child2Canonical);

    // 2. Both children reference the correct parent
    expect(persistedChildren[0].parentId!.toString()).toBe(stateId);
    expect(persistedChildren[1].parentId!.toString()).toBe(stateId);

    // 3. Parent document exists and version key (__v) was serialized and incremented
    const persistedParent = await PlaceModel.findById(stateId).exec();
    expect(persistedParent).not.toBeNull();
    expect(persistedParent!.__v).toBeGreaterThanOrEqual(2);
  }, 25000);
});
