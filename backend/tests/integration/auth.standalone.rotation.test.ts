/**
 * Phase 1C.17 — Standalone MongoDB Refresh-Token Rotation Failure Safety
 *
 * Tests the non-transactional fallback path in `rotateAndSaveRefreshToken()` against a
 * REAL standalone MongoDB instance on port 27017 (topology: Single/Standalone).
 *
 * Topology proofs enforced before any test runs (safety blockers):
 *   - driver topology.description.type === 'Single'
 *   - every server in description has type 'Standalone' (not RSPrimary)
 *   - supportsTransactions() returns false for this connection
 *   - hello command confirms no setName (standalone, not a replica-set member)
 *
 * Design: uses a DEDICATED Mongoose connection (not the global singleton) for all
 * operations, and creates model instances bound to that connection. This avoids
 * invalidating other model registrations in the same Jest worker.
 *
 * No production credentials, external SMTP, or unrelated application services are used.
 * All test data is isolated to the dedicated database and cleaned up in afterEach/afterAll.
 */

import mongoose, { Connection, Schema, Document } from 'mongoose';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { env } from '../../src/config/env';
import { USER_ROLES } from '../../src/shared/constants';

// ─── Configuration ─────────────────────────────────────────────────────────
const STANDALONE_PORT = 27017;
const STANDALONE_DB   = 'myroot_standalone_rotation_test';
const STANDALONE_URI  = `mongodb://127.0.0.1:${STANDALONE_PORT}/${STANDALONE_DB}`;

// ─── Inline helpers (mirrors production implementations) ───────────────────
function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}
function hashEmail(email: string): string {
  return crypto.createHash('sha256').update(email.trim().toLowerCase()).digest('hex');
}
function makeRefreshToken(userId: string, tokenVersion: number, family: string): string {
  return jwt.sign(
    { userId, jti: crypto.randomUUID(), family, tokenVersion },
    env.JWT_REFRESH_SECRET,
    { expiresIn: '7d' }
  );
}

// ─── Interfaces (mirrors production) ──────────────────────────────────────
interface IRefreshToken extends Document {
  tokenHash: string;
  userId: mongoose.Types.ObjectId;
  tokenFamily: string;
  replacedByTokenHash?: string | null;
  expiresAt: Date;
  revoked: boolean;
}
interface IUser extends Document {
  displayName: string;
  email: string;
  emailHash: string;
  passwordHash: string;
  role: string;
  isEmailVerified: boolean;
  isActive: boolean;
  tokenVersion: number;
}

// ─── Model factories (bound to a specific connection) ─────────────────────
function makeRefreshTokenModel(conn: Connection) {
  const schema = new Schema<IRefreshToken>({
    tokenHash:           { type: String, required: true, unique: true },
    userId:              { type: Schema.Types.ObjectId, required: true },
    tokenFamily:         { type: String, required: true },
    replacedByTokenHash: { type: String, default: null },
    expiresAt:           { type: Date, required: true },
    revoked:             { type: Boolean, default: false },
  });
  return conn.model<IRefreshToken>('RefreshToken', schema);
}
function makeUserModel(conn: Connection) {
  const schema = new Schema<IUser>({
    displayName:      { type: String, required: true },
    email:            { type: String, required: true, unique: true, select: false },
    emailHash:        { type: String, required: true, unique: true },
    passwordHash:     { type: String, required: true, select: false },
    role:             { type: String, default: 'CONTRIBUTOR' },
    isEmailVerified:  { type: Boolean, default: false },
    isActive:         { type: Boolean, default: true },
    tokenVersion:     { type: Number, default: 1 },
  });
  return conn.model<IUser>('User', schema);
}

// ─── Inline AuthRepository (uses dedicated connection models) ─────────────
// This is a minimal replica of the production AuthRepository wired to the
// dedicated standalone connection's model instances, not the global singleton.
class StandaloneAuthRepository {
  constructor(
    private readonly RTModel: ReturnType<typeof makeRefreshTokenModel>,
    private readonly UModel:  ReturnType<typeof makeUserModel>,
    private readonly conn:    Connection
  ) {}

  supportsTransactions(): boolean {
    try {
      if (this.conn.readyState !== 1) return false;
      const desc = (this.conn.getClient() as any)?.topology?.description;
      if (!desc || desc.compatibilityError) return false;
      const type = desc.type;
      if (type === 'ReplicaSetWithPrimary' || type === 'Sharded') return true;
      if (type === 'Single' && desc.servers) {
        for (const s of desc.servers.values()) {
          if ((s as any)?.type === 'RSPrimary') return true;
        }
      }
      return false;
    } catch { return false; }
  }

  async atomicRotateRefreshToken(oldToken: string, newToken: string): Promise<IRefreshToken | null> {
    if (this.conn.readyState !== 1) return null;
    return await this.RTModel.findOneAndUpdate(
      { tokenHash: hashToken(oldToken), revoked: false, expiresAt: { $gt: new Date() } },
      { $set: { revoked: true, replacedByTokenHash: hashToken(newToken) } },
      { new: true }
    ).exec();
  }

  async saveRefreshToken(
    userId: string, token: string, expiresAt: Date, tokenFamily: string
  ): Promise<IRefreshToken> {
    if (this.conn.readyState !== 1) throw new Error('DB disconnected');
    const doc = new this.RTModel({
      userId: new mongoose.Types.ObjectId(userId),
      tokenHash: hashToken(token),
      tokenFamily,
      replacedByTokenHash: null,
      expiresAt,
      revoked: false,
    });
    return await doc.save();
  }

  async findTokenByHash(token: string): Promise<IRefreshToken | null> {
    if (this.conn.readyState !== 1) return null;
    return await this.RTModel.findOne({ tokenHash: hashToken(token) }).exec();
  }

  async findByStoredTokenHash(tokenHash: string): Promise<IRefreshToken | null> {
    if (this.conn.readyState !== 1) return null;
    return await this.RTModel.findOne({ tokenHash }).exec();
  }

  async findById(id: string): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) return null;
    return await this.UModel.findById(id).exec();
  }

  async revokeTokenFamily(tokenFamily: string): Promise<number> {
    const r = await this.RTModel.updateMany({ tokenFamily, revoked: false }, { $set: { revoked: true } }).exec();
    return r.modifiedCount;
  }

  async revokeAllUserRefreshTokens(userId: string): Promise<number> {
    if (!mongoose.Types.ObjectId.isValid(userId)) return 0;
    const r = await this.RTModel.updateMany(
      { userId: new mongoose.Types.ObjectId(userId), revoked: false },
      { $set: { revoked: true } }
    ).exec();
    return r.modifiedCount;
  }

  async incrementTokenVersion(userId: string): Promise<number> {
    const r = await this.UModel.findByIdAndUpdate(userId, { $inc: { tokenVersion: 1 } }, { new: true }).exec();
    return r?.tokenVersion ?? 1;
  }

  /**
   * Non-transactional standalone rotation:
   *  1. atomicRotateRefreshToken (single-document findOneAndUpdate — always atomic)
   *  2. saveRefreshToken (separate insert — if this throws, old token stays revoked)
   */
  async rotateAndSaveRefreshToken(
    oldToken: string, newToken: string, userId: string, expiresAt: Date, tokenFamily: string
  ): Promise<{ rotated: boolean; replacement: IRefreshToken | null }> {
    if (this.conn.readyState !== 1) return { rotated: false, replacement: null };
    if (this.supportsTransactions()) {
      throw new Error('INVARIANT VIOLATION: called standalone rotation path on transaction-capable topology');
    }

    const rotatedDoc = await this.atomicRotateRefreshToken(oldToken, newToken);
    if (!rotatedDoc) return { rotated: false, replacement: null };

    // Fail closed: if saveRefreshToken throws, old token remains revoked.
    const doc = await this.saveRefreshToken(userId, newToken, expiresAt, tokenFamily);
    return { rotated: true, replacement: doc };
  }
}

// ─── Inline minimal AuthService (uses StandaloneAuthRepository) ───────────
class StandaloneAuthService {
  constructor(private readonly repo: StandaloneAuthRepository) {}

  async refreshToken(refreshTokenStr: string): Promise<{ accessToken: string; refreshToken: string }> {
    let payload: any;
    try {
      payload = jwt.verify(refreshTokenStr, env.JWT_REFRESH_SECRET);
    } catch {
      throw new Error('Invalid or expired refresh token');
    }
    if (!payload?.userId) throw new Error('Invalid or expired refresh token');

    const existingDoc = await this.repo.findTokenByHash(refreshTokenStr);

    if (existingDoc && existingDoc.revoked) {
      const expectedReplacementHash = existingDoc.replacedByTokenHash;
      let isAbortedRotation = false;
      if (expectedReplacementHash) {
        const replacementDoc = await this.repo.findByStoredTokenHash(expectedReplacementHash);
        if (!replacementDoc) isAbortedRotation = true;
      }

      if (isAbortedRotation) {
        throw new Error('Token rotation was interrupted. Please log in again.');
      } else {
        if (existingDoc.tokenFamily) await this.repo.revokeTokenFamily(existingDoc.tokenFamily);
        await this.repo.revokeAllUserRefreshTokens(payload.userId);
        await this.repo.incrementTokenVersion(payload.userId);
        throw new Error('Refresh token reuse detected. All active sessions have been revoked.');
      }
    }

    const user = await this.repo.findById(payload.userId);
    if (!user || !user.isActive) throw new Error('User account not found or disabled');

    const rawTokenVersion = payload.tokenVersion;
    if (
      typeof rawTokenVersion !== 'number' || !Number.isFinite(rawTokenVersion) ||
      !Number.isInteger(rawTokenVersion) || rawTokenVersion < 0
    ) {
      throw new Error('Invalid or expired refresh token');
    }
    const currentTokenVersion = user.tokenVersion ?? 1;
    if (rawTokenVersion !== currentTokenVersion) throw new Error('Token has been revoked');

    const userId    = user._id.toString();
    const family    = payload.family || existingDoc?.tokenFamily || crypto.randomUUID();
    const expiresAt = new Date(Date.now() + 7 * 24 * 3_600_000);
    const newToken  = jwt.sign(
      { userId, jti: crypto.randomUUID(), family, tokenVersion: currentTokenVersion },
      env.JWT_REFRESH_SECRET,
      { expiresIn: '7d' }
    );

    const result = await this.repo.rotateAndSaveRefreshToken(
      refreshTokenStr, newToken, userId, expiresAt, family
    );

    if (!result.rotated) throw new Error('Invalid or expired refresh token');

    const accessToken = jwt.sign(
      { userId, email: user.email ?? '', role: user.role, tokenVersion: currentTokenVersion },
      env.JWT_REFRESH_SECRET,  // use HS256 for test access token (JWT_ALLOW_HS256_FALLBACK)
      { expiresIn: '15m' }
    );

    return { accessToken, refreshToken: newToken };
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Test Suite
// ══════════════════════════════════════════════════════════════════════════
describe('Standalone MongoDB: Refresh-Token Rotation Failure Safety (Live Integration)', () => {
  let conn: Connection;
  let RTModel: ReturnType<typeof makeRefreshTokenModel>;
  let UModel:  ReturnType<typeof makeUserModel>;
  let repo: StandaloneAuthRepository;
  let service: StandaloneAuthService;
  let testUserId: string;
  let originalAllowFallback: string | undefined;

  const createdTokenFamilies: string[] = [];

  // ── One-time setup ────────────────────────────────────────────────────────
  beforeAll(async () => {
    originalAllowFallback = process.env.JWT_ALLOW_HS256_FALLBACK;
    process.env.JWT_ALLOW_HS256_FALLBACK = 'true';

    // Create a DEDICATED connection — do not touch the global mongoose singleton
    conn = await mongoose.createConnection(STANDALONE_URI, {
      serverSelectionTimeoutMS: 5000,
      connectTimeoutMS: 5000,
    }).asPromise();

    // ── Topology Safety Guards ─────────────────────────────────────────────
    const client = conn.getClient() as any;
    const desc   = client?.topology?.description;
    if (!desc) throw new Error('SAFETY BLOCKER: Cannot read topology description');
    if (desc.type !== 'Single') {
      throw new Error(
        `SAFETY BLOCKER: Expected topology 'Single', got '${desc.type}'. ` +
        'This test must only run against a true standalone MongoDB.'
      );
    }
    for (const server of desc.servers.values() as IterableIterator<any>) {
      if (server.type !== 'Standalone') {
        throw new Error(
          `SAFETY BLOCKER: Expected server type 'Standalone', got '${server.type}'. ` +
          'Refusing to run against a replica-set member.'
        );
      }
    }
    const hello = await conn.db!.admin().command({ hello: 1 });
    if (hello.setName) {
      throw new Error(
        `SAFETY BLOCKER: hello.setName='${hello.setName}' — this is a replica-set member.`
      );
    }
    if (conn.name !== STANDALONE_DB) {
      throw new Error(`SAFETY BLOCKER: Expected db '${STANDALONE_DB}', got '${conn.name}'`);
    }

    // Create model instances bound to the dedicated connection
    RTModel = makeRefreshTokenModel(conn);
    UModel  = makeUserModel(conn);

    // Instantiate repository and service
    repo    = new StandaloneAuthRepository(RTModel, UModel, conn);
    service = new StandaloneAuthService(repo);

    if (repo.supportsTransactions()) {
      throw new Error('SAFETY BLOCKER: supportsTransactions()=true on standalone — test would use wrong path');
    }

    // Create test user
    const user = await UModel.create({
      displayName:  'Standalone Test User',
      email:        'standalone.rotation.test@myroot.test',
      emailHash:    hashEmail('standalone.rotation.test@myroot.test'),
      passwordHash: '$2a$10$fakeHashForTestingOnlyDoNotUseInProduction000000000000000',
      role:         USER_ROLES.CONTRIBUTOR,
      isEmailVerified: true,
      isActive:     true,
      tokenVersion: 1,
    });
    testUserId = user._id.toString();
  });

  afterEach(async () => {
    jest.restoreAllMocks();
    if (createdTokenFamilies.length > 0) {
      await RTModel.deleteMany({ tokenFamily: { $in: [...createdTokenFamilies] } });
      createdTokenFamilies.length = 0;
    }
  });

  afterAll(async () => {
    if (originalAllowFallback === undefined) {
      delete process.env.JWT_ALLOW_HS256_FALLBACK;
    } else {
      process.env.JWT_ALLOW_HS256_FALLBACK = originalAllowFallback;
    }
    if (conn.readyState === 1) {
      await conn.db?.dropDatabase();
      await conn.close();
    }
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 1. Topology proof
  // ══════════════════════════════════════════════════════════════════════════
  it('topology: Single/Standalone, no setName, supportsTransactions() = false', async () => {
    const client = conn.getClient() as any;
    const desc   = client?.topology?.description;

    expect(desc.type).toBe('Single');
    const serverTypes: string[] = [];
    for (const s of desc.servers.values() as IterableIterator<any>) serverTypes.push((s as any).type);
    expect(serverTypes).toEqual(['Standalone']);

    const hello = await conn.db!.admin().command({ hello: 1 });
    expect(hello.setName).toBeUndefined();

    expect(repo.supportsTransactions()).toBe(false);
  });

  it('confirms transactions are rejected by standalone MongoDB (error code 20)', async () => {
    const session = conn.getClient().startSession();
    let txError: any;
    try {
      await session.withTransaction(async () => {
        await RTModel.create(
          [{ tokenHash: 'tx-topology-probe', tokenFamily: 'tx-probe',
             userId: new mongoose.Types.ObjectId(), expiresAt: new Date(Date.now() + 60000), revoked: false }],
          { session }
        );
      });
    } catch (err) {
      txError = err;
    } finally {
      await session.endSession();
      await RTModel.deleteMany({ tokenFamily: 'tx-probe' });
    }
    expect(txError).toBeDefined();
    expect(txError.code).toBe(20);
    expect(txError.message).toContain('Transaction numbers are only allowed on a replica set member or mongos');
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2. Baseline: standalone happy-path rotation succeeds
  // ══════════════════════════════════════════════════════════════════════════
  it('happy path: old token revoked and replacement persisted on standalone', async () => {
    const family  = 'standalone-test-family-happy';
    createdTokenFamilies.push(family);
    const oldRaw  = 'standalone-happy-old-raw-token-abc123';
    const newRaw  = 'standalone-happy-new-raw-token-xyz456';
    const oldHash = hashToken(oldRaw);
    const newHash = hashToken(newRaw);
    const expires = new Date(Date.now() + 3_600_000);

    await RTModel.create({
      userId: new mongoose.Types.ObjectId(testUserId),
      tokenHash: oldHash, tokenFamily: family,
      replacedByTokenHash: null, expiresAt: expires, revoked: false,
    });

    const result = await repo.rotateAndSaveRefreshToken(oldRaw, newRaw, testUserId, expires, family);
    expect(result.rotated).toBe(true);
    expect(result.replacement).not.toBeNull();

    // Verify REAL PERSISTED DATABASE STATE
    const persistedOld = await RTModel.findOne({ tokenHash: oldHash });
    expect(persistedOld!.revoked).toBe(true);
    expect(persistedOld!.replacedByTokenHash).toBe(newHash);

    const persistedNew = await RTModel.findOne({ tokenHash: newHash });
    expect(persistedNew!.revoked).toBe(false);
    expect(persistedNew!.tokenFamily).toBe(family);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3. Confirmed failure: old token remains revoked, no replacement in DB
  // ══════════════════════════════════════════════════════════════════════════
  it('old token remains revoked in DB when saveRefreshToken throws after atomicRotateRefreshToken succeeds', async () => {
    const family  = 'standalone-test-family-fail-persist';
    createdTokenFamilies.push(family);
    const oldRaw  = 'standalone-failpersist-old-token-abc123';
    const newRaw  = 'standalone-failpersist-new-token-xyz456';
    const oldHash = hashToken(oldRaw);
    const newHash = hashToken(newRaw);
    const expires = new Date(Date.now() + 3_600_000);

    await RTModel.create({
      userId: new mongoose.Types.ObjectId(testUserId),
      tokenHash: oldHash, tokenFamily: family,
      replacedByTokenHash: null, expiresAt: expires, revoked: false,
    });

    jest.spyOn(repo, 'saveRefreshToken').mockRejectedValueOnce(
      new Error('Simulated write failure: network timeout after oldToken revoked')
    );

    await expect(
      repo.rotateAndSaveRefreshToken(oldRaw, newRaw, testUserId, expires, family)
    ).rejects.toThrow('Simulated write failure: network timeout after oldToken revoked');

    // ── Verify REAL PERSISTED DATABASE STATE ──────────────────────────────
    const persistedOld = await RTModel.findOne({ tokenHash: oldHash });
    expect(persistedOld!.revoked).toBe(true);           // old token stays revoked (fail closed)
    expect(persistedOld!.replacedByTokenHash).toBe(newHash); // pointer was set by atomicRotate

    const persistedNew = await RTModel.findOne({ tokenHash: newHash });
    expect(persistedNew).toBeNull();                    // replacement was NEVER persisted
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4. No credentials returned when persistence fails
  // ══════════════════════════════════════════════════════════════════════════
  it('authService.refreshToken returns no credentials when saveRefreshToken fails (fail closed)', async () => {
    const family   = 'standalone-test-family-no-creds';
    createdTokenFamilies.push(family);
    const rawToken  = makeRefreshToken(testUserId, 1, family);
    const tokenHash = hashToken(rawToken);
    const expires   = new Date(Date.now() + 7 * 24 * 3_600_000);

    await RTModel.create({
      userId: new mongoose.Types.ObjectId(testUserId),
      tokenHash, tokenFamily: family,
      replacedByTokenHash: null, expiresAt: expires, revoked: false,
    });

    jest.spyOn(repo, 'saveRefreshToken').mockRejectedValueOnce(
      new Error('Simulated: disk write failure mid-rotation')
    );

    let result: any;
    let caughtError: any;
    try {
      result = await service.refreshToken(rawToken);
    } catch (err) {
      caughtError = err;
    }

    expect(result).toBeUndefined();                    // no credentials leaked
    expect(caughtError).toBeDefined();
    expect(caughtError.message).toBe('Simulated: disk write failure mid-rotation');

    // Old token still revoked in DB
    const persistedOld = await RTModel.findOne({ tokenHash });
    expect(persistedOld!.revoked).toBe(true);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5. Retry after interrupted rotation → interrupted-rotation error, no reactivation
  // ══════════════════════════════════════════════════════════════════════════
  it('retry with old token yields interrupted-rotation error; old token stays revoked in DB', async () => {
    const family   = 'standalone-test-family-retry';
    createdTokenFamilies.push(family);
    const rawToken  = makeRefreshToken(testUserId, 1, family);
    const tokenHash = hashToken(rawToken);
    const expires   = new Date(Date.now() + 7 * 24 * 3_600_000);

    await RTModel.create({
      userId: new mongoose.Types.ObjectId(testUserId),
      tokenHash, tokenFamily: family,
      replacedByTokenHash: null, expiresAt: expires, revoked: false,
    });

    // First call: persistence interrupted
    jest.spyOn(repo, 'saveRefreshToken').mockRejectedValueOnce(
      new Error('Simulated: connection reset before replacement persisted')
    );
    await expect(service.refreshToken(rawToken)).rejects.toThrow(
      'Simulated: connection reset before replacement persisted'
    );

    // Confirm interrupted state persisted in DB correctly
    const afterInterrupt = await RTModel.findOne({ tokenHash });
    expect(afterInterrupt!.revoked).toBe(true);
    const replacementHash = afterInterrupt!.replacedByTokenHash;
    expect(replacementHash).toBeTruthy();   // atomicRotate set the pointer

    const replacementDoc = await RTModel.findOne({ tokenHash: replacementHash! });
    expect(replacementDoc).toBeNull();      // replacement is NOT in DB

    // Second call (retry with same old token): must fail with interrupted-rotation error
    await expect(service.refreshToken(rawToken)).rejects.toThrow(
      'Token rotation was interrupted. Please log in again.'
    );

    // DB STATE: old token still revoked — NOT reactivated
    const afterRetry = await RTModel.findOne({ tokenHash });
    expect(afterRetry!.revoked).toBe(true);

    const replacementAfterRetry = await RTModel.findOne({ tokenHash: replacementHash! });
    expect(replacementAfterRetry).toBeNull();
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 6. Other valid sessions are NOT revoked as a side effect
  // ══════════════════════════════════════════════════════════════════════════
  it('other valid sessions for same user survive interrupted rotation (no side-effect revocation)', async () => {
    const failFamily  = 'standalone-test-family-fail-main';
    const otherFamily = 'standalone-test-family-other-session';
    createdTokenFamilies.push(failFamily, otherFamily);
    const expires = new Date(Date.now() + 7 * 24 * 3_600_000);

    const rawFailToken  = makeRefreshToken(testUserId, 1, failFamily);
    const failTokenHash = hashToken(rawFailToken);

    await RTModel.create({
      userId: new mongoose.Types.ObjectId(testUserId),
      tokenHash: failTokenHash, tokenFamily: failFamily,
      replacedByTokenHash: null, expiresAt: expires, revoked: false,
    });

    // A separate active session that must survive
    const otherTokenHash = hashToken('standalone-other-session-token-survives-failure-123');
    await RTModel.create({
      userId: new mongoose.Types.ObjectId(testUserId),
      tokenHash: otherTokenHash, tokenFamily: otherFamily,
      replacedByTokenHash: null, expiresAt: expires, revoked: false,
    });

    // Interrupt rotation of failToken
    jest.spyOn(repo, 'saveRefreshToken').mockRejectedValueOnce(
      new Error('Simulated: replacement persistence failed mid-way')
    );
    await expect(service.refreshToken(rawFailToken)).rejects.toThrow(
      'Simulated: replacement persistence failed mid-way'
    );

    // Retry: interrupted-rotation error (not reuse-detection revocation)
    await expect(service.refreshToken(rawFailToken)).rejects.toThrow(
      'Token rotation was interrupted. Please log in again.'
    );

    // OTHER SESSION: must still be active — not revoked as a side effect
    const otherSession = await RTModel.findOne({ tokenHash: otherTokenHash });
    expect(otherSession).not.toBeNull();
    expect(otherSession!.revoked).toBe(false);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 7. Concurrent rotation on standalone: exactly one wins
  // ══════════════════════════════════════════════════════════════════════════
  it('concurrent rotation on standalone: exactly one succeeds, one active replacement in DB', async () => {
    const family  = 'standalone-test-family-concurrent';
    createdTokenFamilies.push(family);
    const oldRaw  = 'standalone-concurrent-old-token-abc999';
    const new1Raw = 'standalone-concurrent-new-token-req1';
    const new2Raw = 'standalone-concurrent-new-token-req2';
    const oldHash = hashToken(oldRaw);
    const expires = new Date(Date.now() + 3_600_000);

    await RTModel.create({
      userId: new mongoose.Types.ObjectId(testUserId),
      tokenHash: oldHash, tokenFamily: family,
      replacedByTokenHash: null, expiresAt: expires, revoked: false,
    });

    const [r1, r2] = await Promise.all([
      repo.rotateAndSaveRefreshToken(oldRaw, new1Raw, testUserId, expires, family),
      repo.rotateAndSaveRefreshToken(oldRaw, new2Raw, testUserId, expires, family),
    ]);

    const rotatedFlags = [r1.rotated, r2.rotated].sort();
    expect(rotatedFlags).toEqual([false, true]);

    // Verify REAL PERSISTED DATABASE STATE
    const persistedOld = await RTModel.findOne({ tokenHash: oldHash });
    expect(persistedOld!.revoked).toBe(true);

    const activeReplacements = await RTModel.find({ tokenFamily: family, revoked: false });
    expect(activeReplacements.length).toBe(1);
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 8. rotateAndSaveRefreshToken returns rotated:false for already-revoked token
  // ══════════════════════════════════════════════════════════════════════════
  it('returns rotated:false without creating any new document when old token is already revoked', async () => {
    const family  = 'standalone-test-family-already-revoked';
    createdTokenFamilies.push(family);
    const oldRaw  = 'standalone-already-revoked-token-abc';
    const newRaw  = 'standalone-already-revoked-new-token-abc';
    const oldHash = hashToken(oldRaw);
    const expires = new Date(Date.now() + 3_600_000);

    await RTModel.create({
      userId: new mongoose.Types.ObjectId(testUserId),
      tokenHash: oldHash, tokenFamily: family,
      replacedByTokenHash: 'previous-replacement-hash',
      expiresAt: expires, revoked: true,
    });

    const saveRefreshSpy = jest.spyOn(repo, 'saveRefreshToken');
    const result = await repo.rotateAndSaveRefreshToken(oldRaw, newRaw, testUserId, expires, family);

    expect(result.rotated).toBe(false);
    expect(result.replacement).toBeNull();
    expect(saveRefreshSpy).not.toHaveBeenCalled();

    const newInDb = await RTModel.findOne({ tokenHash: hashToken(newRaw) });
    expect(newInDb).toBeNull();
  });
});
