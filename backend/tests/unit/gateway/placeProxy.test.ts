import request from 'supertest';
import jwt from 'jsonwebtoken';
import { createApp } from '../../../src/app';
import { env, envSchema, PLACEHOLDER_APP_GATE_SECRET } from '../../../src/config/env';
import { USER_ROLES } from '../../../src/shared/constants';
import { TEST_RSA_PRIVATE_KEY } from '../../fixtures/testKeys';
import { placeGatewayService } from '../../../src/modules/places/gateway';

const app = createApp();

function generateUserToken(role: string, userId = '507f1f77bcf86cd799439011', tokenVersion = 1): string {
  return jwt.sign(
    {
      sub: userId,
      userId,
      email: 'test@example.com',
      role,
      displayName: 'Gateway Test User',
      tokenVersion,
    },
    TEST_RSA_PRIVATE_KEY,
    {
      algorithm: 'RS256',
      issuer: 'myroot-backend',
      audience: 'myroot-platform',
      expiresIn: '15m',
    }
  );
}

describe('India Place API Gateway Proxy (Unit Tests)', () => {
  let fetchSpy: jest.SpyInstance;
  let priorProxyEnv: string | undefined;

  beforeAll(() => {
    priorProxyEnv = process.env.PLACE_API_PROXY_ENABLED;
    process.env.PLACE_API_PROXY_ENABLED = 'true';
  });

  afterAll(() => {
    if (priorProxyEnv !== undefined) {
      process.env.PLACE_API_PROXY_ENABLED = priorProxyEnv;
    } else {
      delete process.env.PLACE_API_PROXY_ENABLED;
    }
  });

  beforeEach(() => {
    fetchSpy = jest.spyOn(global, 'fetch');
  });

  afterEach(() => {
    fetchSpy.mockRestore();
  });

  describe('1. Successful Authenticated Proxy & Bearer Forwarding', () => {
    it('forwards query parameters and passes unchanged user RS256 Bearer token upstream', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            data: [
              {
                _id: 'plc_rj_01',
                level: 'STATE_UT',
                canonicalName: 'Rajasthan',
                names: [{ language: 'en', name: 'Rajasthan' }],
              },
            ],
            pagination: { total: 1, page: 1, limit: 20 },
          }),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const res = await request(app)
        .get('/api/v1/places?level=STATE&search=Rajasthan&page=1&limit=20')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.data[0].id).toBe('plc_rj_01');
      expect(res.body.data[0].level).toBe('STATE'); // Mapped from STATE_UT

      expect(fetchSpy).toHaveBeenCalledTimes(1);
      const [calledUrl, calledInit] = fetchSpy.mock.calls[0];

      // Verify destination is strictly anchored to configured Place API base URL
      expect(calledUrl.toString()).toBe(
        'http://localhost:4001/places?level=STATE_UT&search=Rajasthan&page=1&limit=20'
      );

      // Verify exact user Bearer token is forwarded without modification or elevation
      expect(calledInit.headers['Authorization']).toBe(`Bearer ${userToken}`);
      // Verify separate approved App-Attestation header is attached
      expect(calledInit.headers['X-App-Attestation']).toBeDefined();
      expect(calledInit.headers['X-App-Attestation']).not.toBe(userToken);
    });

    it('forwards GET /places/:id and maps _id to id', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            data: {
              _id: 'plc_country_ind',
              level: 'COUNTRY',
              canonicalName: 'India',
              names: [{ language: 'en', name: 'India' }],
              parentId: null,
            },
          }),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const res = await request(app)
        .get('/api/v1/places/plc_country_ind')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe('plc_country_ind');
      expect(res.body.data.canonicalName).toBe('India');

      expect(fetchSpy).toHaveBeenCalledWith(
        'http://localhost:4001/places/plc_country_ind',
        expect.objectContaining({ method: 'GET' })
      );
    });

    it('forwards GET /places/:id/children and maps children array', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            data: [
              {
                _id: 'plc_state_rj',
                level: 'STATE_UT',
                canonicalName: 'Rajasthan',
                parentId: 'plc_country_ind',
              },
            ],
          }),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const res = await request(app)
        .get('/api/v1/places/plc_country_ind/children')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data[0].id).toBe('plc_state_rj');
      expect(res.body.data[0].level).toBe('STATE');

      expect(fetchSpy).toHaveBeenCalledWith(
        'http://localhost:4001/places/plc_country_ind/children',
        expect.objectContaining({ method: 'GET' })
      );
    });
  });

  describe('2. Contract Preservation & Method Mapping', () => {
    it('maps POST /places with body and returns 201 with mapped response', async () => {
      const adminToken = generateUserToken(USER_ROLES.ADMIN);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            data: {
              _id: 'plc_dist_01',
              level: 'DISTRICT',
              canonicalName: 'Jaipur',
              names: [{ language: 'en', name: 'Jaipur' }],
              parentId: 'plc_state_rj',
            },
          }),
          {
            status: 201,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          level: 'DISTRICT',
          canonicalName: 'Jaipur',
          names: [{ language: 'en', name: 'Jaipur' }],
          parentId: 'plc_state_rj',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.id).toBe('plc_dist_01');
      expect(res.body.data.canonicalName).toBe('Jaipur');

      expect(fetchSpy).toHaveBeenCalledWith(
        'http://localhost:4001/places',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({
            level: 'DISTRICT',
            canonicalName: 'Jaipur',
            names: [{ language: 'en', name: 'Jaipur' }],
            parentId: 'plc_state_rj',
          }),
        })
      );
    });

    it('maps Flutter PUT /places/:id to upstream PATCH /places/:id', async () => {
      const modToken = generateUserToken(USER_ROLES.MODERATOR);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            data: {
              _id: 'plc_dist_01',
              level: 'DISTRICT',
              canonicalName: 'Jaipur City',
              names: [{ language: 'en', name: 'Jaipur City' }],
            },
          }),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const res = await request(app)
        .put('/api/v1/places/plc_dist_01')
        .set('Authorization', `Bearer ${modToken}`)
        .send({
          canonicalName: 'Jaipur City',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe('plc_dist_01');
      expect(res.body.data.canonicalName).toBe('Jaipur City');

      expect(fetchSpy).toHaveBeenCalledWith(
        'http://localhost:4001/places/plc_dist_01',
        expect.objectContaining({
          method: 'PATCH',
          body: JSON.stringify({ canonicalName: 'Jaipur City' }),
        })
      );
    });

    it('forwards DELETE /places/:id and preserves upstream non-success status', async () => {
      const adminToken = generateUserToken(USER_ROLES.ADMIN);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            error: {
              code: 'NOT_FOUND',
              message: 'Route not found',
            },
          }),
          {
            status: 404,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const res = await request(app)
        .delete('/api/v1/places/plc_dist_01')
        .set('Authorization', `Bearer ${adminToken}`);

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');

      expect(fetchSpy).toHaveBeenCalledWith(
        'http://localhost:4001/places/plc_dist_01',
        expect.objectContaining({ method: 'DELETE' })
      );
    });
  });

  describe('3. Missing/Invalid User Token Rejection', () => {
    it('rejects protected POST /places with 401 when Authorization header is missing', async () => {
      const res = await request(app)
        .post('/api/v1/places')
        .send({
          level: 'COUNTRY',
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
      expect(res.body.error.message).toBe('No token provided');
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('rejects protected POST /places with 401 when user token signature is invalid', async () => {
      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', 'Bearer invalid.tampered.token')
        .send({
          level: 'COUNTRY',
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
      expect(res.body.error.message).toBe('Invalid or expired token');
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });

  describe('4. Protected-Route Authorization & Privilege Protection', () => {
    it('rejects POST /places with 403 when user has CONTRIBUTOR role (requires ADMIN)', async () => {
      const contributorToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${contributorToken}`)
        .send({
          level: 'COUNTRY',
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('rejects POST /places with 403 when user has MODERATOR role (requires ADMIN)', async () => {
      const modToken = generateUserToken(USER_ROLES.MODERATOR);

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${modToken}`)
        .send({
          level: 'COUNTRY',
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('rejects DELETE /places/:id with 403 when user has MODERATOR role (requires ADMIN)', async () => {
      const modToken = generateUserToken(USER_ROLES.MODERATOR);

      const res = await request(app)
        .delete('/api/v1/places/plc_01')
        .set('Authorization', `Bearer ${modToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });

  describe('5. Upstream Timeout, Connection Failure & Non-Success Handling', () => {
    it('returns 504 GATEWAY_TIMEOUT when upstream Place API times out', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      const abortError = new Error('The operation was aborted due to timeout');
      abortError.name = 'TimeoutError';
      fetchSpy.mockRejectedValueOnce(abortError);

      const res = await request(app)
        .get('/api/v1/places')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(504);
      expect(res.body.error.code).toBe('GATEWAY_TIMEOUT');
      expect(res.body.error.message).toBe('Upstream India Place API request timed out');
    });

    it('returns 504 GATEWAY_TIMEOUT when undici throws fetch failed with TimeoutError cause', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      const undiciError = new TypeError('fetch failed');
      (undiciError as any).cause = Object.assign(new Error('Headers timeout'), {
        name: 'TimeoutError',
        code: 'UND_ERR_HEADERS_TIMEOUT',
      });
      fetchSpy.mockRejectedValueOnce(undiciError);

      const res = await request(app)
        .get('/api/v1/places')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(504);
      expect(res.body.error.code).toBe('GATEWAY_TIMEOUT');
      expect(res.body.error.message).toBe('Upstream India Place API request timed out');
    });

    it('returns 502 BAD_GATEWAY when connection to Place API fails', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      const connError = new TypeError('fetch failed: connect ECONNREFUSED 127.0.0.1:4001');
      fetchSpy.mockRejectedValueOnce(connError);

      const res = await request(app)
        .get('/api/v1/places')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(502);
      expect(res.body.error.code).toBe('BAD_GATEWAY');
      expect(res.body.error.message).toBe('Failed to connect to upstream India Place API');
    });

    it('preserves upstream business rule error (422) and code', async () => {
      const adminToken = generateUserToken(USER_ROLES.ADMIN);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            error: {
              code: 'BUSINESS_RULE_VIOLATION',
              message: 'State cannot be created without a Country parent',
            },
          }),
          {
            status: 422,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const res = await request(app)
        .post('/api/v1/places')
        .set('Authorization', `Bearer ${adminToken}`)
        .send({
          level: 'STATE',
          canonicalName: 'Orphan State',
          names: [{ language: 'en', name: 'Orphan State' }],
          parentId: 'non_existent_country',
        });

      expect(res.status).toBe(422);
      expect(res.body.error.code).toBe('BUSINESS_RULE_VIOLATION');
      expect(res.body.error.message).toBe('State cannot be created without a Country parent');
    });
  });

  describe('6. App-Attestation Gate Separation & Forwarding', () => {
    it('attaches approved app-attestation token with service payload', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      fetchSpy.mockResolvedValueOnce(
        new Response(JSON.stringify({ data: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        })
      );

      await request(app)
        .get('/api/v1/places')
        .set('Authorization', `Bearer ${userToken}`);

      const calledInit = fetchSpy.mock.calls[0][1];
      const appToken = calledInit.headers['X-App-Attestation'];

      expect(appToken).toBeDefined();
      const decodedApp = jwt.decode(appToken) as any;
      expect(decodedApp.appId).toBe('myroot-backend-gateway');
      expect(decodedApp.platform).toBe('service');
      expect(decodedApp.isApproved).toBe(true);
    });

    it('strips untrusted client-supplied X-App-Attestation and X-App-Token headers, using Gateway-owned service token', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);
      const untrustedClientToken = 'untrusted_attacker_injected_token';

      fetchSpy.mockResolvedValueOnce(
        new Response(JSON.stringify({ data: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        })
      );

      await request(app)
        .get('/api/v1/places')
        .set('Authorization', `Bearer ${userToken}`)
        .set('X-App-Attestation', untrustedClientToken)
        .set('X-App-Token', untrustedClientToken);

      const calledInit = fetchSpy.mock.calls[0][1];
      const outgoingAppToken = calledInit.headers['X-App-Attestation'];
      expect(outgoingAppToken).toBeDefined();
      expect(outgoingAppToken).not.toBe(untrustedClientToken);
      expect(calledInit.headers['X-App-Token']).toBeUndefined();

      const decoded = jwt.decode(outgoingAppToken) as any;
      expect(decoded.appId).toBe('myroot-backend-gateway');
      expect(decoded.platform).toBe('service');
      expect(decoded.isApproved).toBe(true);
    });

    it('never allows app-attestation alone to grant user role on protected route', async () => {
      // Send valid app-attestation but NO user token on protected route
      const res = await request(app)
        .post('/api/v1/places')
        .set('X-App-Attestation', 'valid_attestation_token')
        .send({
          level: 'COUNTRY',
          canonicalName: 'India',
          names: [{ language: 'en', name: 'India' }],
        });

      // Must be rejected with 401 unauthenticated
      expect(res.status).toBe(401);
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });

  describe('7. Arbitrary URL Prevention & Strict Routing', () => {
    it('strictly encodes path parameters and prevents destination spoofing', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      fetchSpy.mockResolvedValueOnce(
        new Response(JSON.stringify({ data: null }), {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        })
      );

      // Attempt path traversal via parameter
      await request(app)
        .get('/api/v1/places/%2e%2e%2fevil_target')
        .set('Authorization', `Bearer ${userToken}`);

      expect(fetchSpy).toHaveBeenCalledTimes(1);
      const calledUrl = fetchSpy.mock.calls[0][0];

      // Verifies the target URL is strictly anchored to http://localhost:4001/places/...
      expect(calledUrl.toString()).toBe('http://localhost:4001/places/..%2Fevil_target');
    });
  });

  describe('8. Production App-Attestation Secret Fail-Closed Validation', () => {
    const baseValidConfig = {
      NODE_ENV: 'production',
      PORT: '3000',
      MONGODB_URI: 'mongodb://localhost:27017/test',
      JWT_ACCESS_SECRET: 'test_access_secret_long_enough_32ch',
      JWT_REFRESH_SECRET: 'test_refresh_secret_long_enough_32c',
      PLACE_API_PROXY_ENABLED: 'true',
    };

    it('rejects missing or empty PLACE_API_APP_GATE_SECRET in production when proxy is enabled', () => {
      const { PLACE_API_APP_GATE_SECRET, ...rest } = baseValidConfig as any;
      const result = envSchema.safeParse(rest);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('PLACE_API_APP_GATE_SECRET'))).toBe(true);
      }
    });

    it('rejects known placeholder PLACE_API_APP_GATE_SECRET in production', () => {
      const config = {
        ...baseValidConfig,
        PLACE_API_APP_GATE_SECRET: PLACEHOLDER_APP_GATE_SECRET,
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('PLACE_API_APP_GATE_SECRET'))).toBe(true);
      }
    });

    it('rejects secret shorter than 32 characters in production', () => {
      const config = {
        ...baseValidConfig,
        PLACE_API_APP_GATE_SECRET: 'too_short_secret',
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('PLACE_API_APP_GATE_SECRET'))).toBe(true);
      }
    });

    it('accepts strong secret (>= 32 chars and not placeholder) in production', () => {
      const config = {
        ...baseValidConfig,
        PLACE_API_APP_GATE_SECRET: 'my_production_secure_secret_at_least_32_chars_long',
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(true);
    });

    it('rejects missing PLACE_API_APP_GATE_SECRET in production even when PLACE_API_APP_TOKEN is set', () => {
      const config = {
        ...baseValidConfig,
        PLACE_API_APP_TOKEN: 'static_production_app_token_value_configured',
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('PLACE_API_APP_GATE_SECRET'))).toBe(true);
      }
    });

    it('rejects known placeholder PLACE_API_APP_GATE_SECRET in production even when PLACE_API_APP_TOKEN is set', () => {
      const config = {
        ...baseValidConfig,
        PLACE_API_APP_TOKEN: 'static_production_app_token_value_configured',
        PLACE_API_APP_GATE_SECRET: PLACEHOLDER_APP_GATE_SECRET,
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('PLACE_API_APP_GATE_SECRET'))).toBe(true);
      }
    });

    it('rejects short (< 32 chars) PLACE_API_APP_GATE_SECRET in production even when PLACE_API_APP_TOKEN is set', () => {
      const config = {
        ...baseValidConfig,
        PLACE_API_APP_TOKEN: 'static_production_app_token_value_configured',
        PLACE_API_APP_GATE_SECRET: 'too_short_secret',
      };
      const result = envSchema.safeParse(config);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('PLACE_API_APP_GATE_SECRET'))).toBe(true);
      }
    });

    it('allows missing or placeholder secret in development or test environments', () => {
      const devConfig = {
        ...baseValidConfig,
        NODE_ENV: 'development',
      };
      expect(envSchema.safeParse(devConfig).success).toBe(true);

      const testConfig = {
        ...baseValidConfig,
        NODE_ENV: 'test',
        PLACE_API_APP_GATE_SECRET: PLACEHOLDER_APP_GATE_SECRET,
      };
      expect(envSchema.safeParse(testConfig).success).toBe(true);
    });
  });

  describe('9. Gateway Query Parameter Validation & Sanitization', () => {
    it('rejects invalid page values (empty, decimal, negative, zero, non-numeric, unsafe) with 400', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      const invalidPages = ['', '0', '-1', '1.5', 'abc', '99999999999999999999'];
      for (const p of invalidPages) {
        const res = await request(app)
          .get(`/api/v1/places?page=${encodeURIComponent(p)}`)
          .set('Authorization', `Bearer ${userToken}`);

        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_ERROR');
        expect(fetchSpy).not.toHaveBeenCalled();
      }
    });

    it('rejects invalid limit values (empty, decimal, negative, zero, non-numeric, >100) with 400', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      const invalidLimits = ['', '0', '-5', '10.5', 'xyz', '101'];
      for (const l of invalidLimits) {
        const res = await request(app)
          .get(`/api/v1/places?limit=${encodeURIComponent(l)}`)
          .set('Authorization', `Bearer ${userToken}`);

        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_ERROR');
        expect(fetchSpy).not.toHaveBeenCalled();
      }
    });

    it('rejects malformed parentId (empty, too short, traversal, symbols) with 400', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      const invalidParentIds = ['', 'a', '../bad', 'inv?id=1', 'invalid/path'];
      for (const parentId of invalidParentIds) {
        const res = await request(app)
          .get(`/api/v1/places?parentId=${encodeURIComponent(parentId)}`)
          .set('Authorization', `Bearer ${userToken}`);

        expect(res.status).toBe(400);
        expect(res.body.error.code).toBe('VALIDATION_ERROR');
        expect(fetchSpy).not.toHaveBeenCalled();
      }
    });

    it('accepts valid query parameters and forwards sanitized parameters to upstream', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            data: [],
            pagination: { total: 0, page: 2, limit: 50 },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } }
        )
      );

      const res = await request(app)
        .get('/api/v1/places?page=2&limit=50&parentId=plc_rj_01')
        .set('Authorization', `Bearer ${userToken}`);

      expect(res.status).toBe(200);
      expect(fetchSpy).toHaveBeenCalledTimes(1);
      const [calledUrl] = fetchSpy.mock.calls[0];
      expect(calledUrl.toString()).toBe('http://localhost:4001/places?page=2&limit=50&parentId=plc_rj_01');
    });

    it('accepts Mongoose 24-hex ObjectId and India Place API string formats as parentId', async () => {
      const userToken = generateUserToken(USER_ROLES.CONTRIBUTOR);

      const validParentIds = ['507f1f77bcf86cd799439011', 'PL_VIL_06_077_00382_060008', 'plc_dist_01'];
      for (const parentId of validParentIds) {
        fetchSpy.mockResolvedValueOnce(
          new Response(
            JSON.stringify({ data: [] }),
            { status: 200, headers: { 'Content-Type': 'application/json' } }
          )
        );

        const res = await request(app)
          .get(`/api/v1/places?parentId=${encodeURIComponent(parentId)}`)
          .set('Authorization', `Bearer ${userToken}`);

        expect(res.status).toBe(200);
      }
      expect(fetchSpy).toHaveBeenCalledTimes(validParentIds.length);
    });

    it('direct executeProxy invocation rejects invalid query parameters with 400', async () => {
      const pageRes = await placeGatewayService.executeProxy('GET', '/places', { query: { page: '0' } } as any);
      expect(pageRes.status).toBe(400);
      expect(pageRes.body.error.code).toBe('VALIDATION_ERROR');

      const limitRes = await placeGatewayService.executeProxy('GET', '/places', { query: { limit: '200' } } as any);
      expect(limitRes.status).toBe(400);
      expect(limitRes.body.error.code).toBe('VALIDATION_ERROR');

      const parentRes = await placeGatewayService.executeProxy('GET', '/places', { query: { parentId: '../evil' } } as any);
      expect(parentRes.status).toBe(400);
      expect(parentRes.body.error.code).toBe('VALIDATION_ERROR');
    });
  });
});

