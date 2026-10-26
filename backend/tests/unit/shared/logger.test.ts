import pino from 'pino';
import {
  logger,
  httpLogger,
  SENSITIVE_LOG_FIELDS,
  getCleanUrl,
  customLogLevel,
  compactSerializers,
  customSuccessMessage,
  customErrorMessage,
} from '../../../src/shared/logger';

describe('Logger Configuration and Redaction Unit Tests', () => {
  describe('SENSITIVE_LOG_FIELDS & Pino Redaction', () => {
    it('defines comprehensive sensitive fields list for redaction', () => {
      expect(SENSITIVE_LOG_FIELDS).toContain('req.headers.authorization');
      expect(SENSITIVE_LOG_FIELDS).toContain('req.headers.cookie');
      expect(SENSITIVE_LOG_FIELDS).toContain('password');
      expect(SENSITIVE_LOG_FIELDS).toContain('newPassword');
      expect(SENSITIVE_LOG_FIELDS).toContain('token');
      expect(SENSITIVE_LOG_FIELDS).toContain('refreshToken');
      expect(SENSITIVE_LOG_FIELDS).toContain('accessToken');
      expect(SENSITIVE_LOG_FIELDS).toContain('secret');
      expect(SENSITIVE_LOG_FIELDS).toContain('*.password');
      expect(SENSITIVE_LOG_FIELDS).toContain('*.token');
    });

    it('redacts sensitive credentials, tokens, and authorization headers in structured logs', () => {
      const messages: string[] = [];
      const testDestination = {
        write: (msg: string) => messages.push(msg),
      };

      const testLogger = pino(
        {
          level: 'info',
          redact: {
            paths: SENSITIVE_LOG_FIELDS,
            censor: '[REDACTED]',
          },
        },
        testDestination as any
      );

      testLogger.info({
        event: 'user_login_attempt',
        password: 'SuperSecretPassword123!',
        accessToken: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.sensitive-access-token',
        refreshToken: 'sensitive-refresh-token-456',
        req: {
          headers: {
            authorization: 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.header-token',
            cookie: 'session_id=secret-cookie-value',
            'user-agent': 'MyRootApp/1.0',
          },
        },
        nested: {
          password: 'another-secret-password',
          secret: 'api-secret-key',
        },
      });

      expect(messages.length).toBe(1);
      const parsed = JSON.parse(messages[0]);

      // Assert sensitive fields are censored
      expect(parsed.password).toBe('[REDACTED]');
      expect(parsed.accessToken).toBe('[REDACTED]');
      expect(parsed.refreshToken).toBe('[REDACTED]');
      expect(parsed.req.headers.authorization).toBe('[REDACTED]');
      expect(parsed.req.headers.cookie).toBe('[REDACTED]');
      expect(parsed.nested.password).toBe('[REDACTED]');
      expect(parsed.nested.secret).toBe('[REDACTED]');

      // Plaintext values must NOT appear anywhere in the raw log string
      expect(messages[0]).not.toContain('SuperSecretPassword123!');
      expect(messages[0]).not.toContain('sensitive-access-token');
      expect(messages[0]).not.toContain('sensitive-refresh-token-456');
      expect(messages[0]).not.toContain('header-token');
      expect(messages[0]).not.toContain('secret-cookie-value');
      expect(messages[0]).not.toContain('another-secret-password');
      expect(messages[0]).not.toContain('api-secret-key');
    });
  });

  describe('httpLogger Compact Request/Response Serializers', () => {
    it('compacts request serialization to method, url, query and id without dumping raw headers', () => {
      expect(compactSerializers).toBeDefined();
      expect(compactSerializers.req).toBeDefined();

      const mockReq = {
        id: 'trace-12345',
        method: 'POST',
        url: '/api/v1/auth/login?queryKey=123',
        query: { queryKey: '123' },
        headers: {
          host: 'localhost:3000',
          'user-agent': 'Mozilla/5.0 Chrome',
          accept: 'application/json',
          'content-type': 'application/json',
          'sec-ch-ua': '"Not A(Brand"',
        },
      };

      const serialized = compactSerializers.req(mockReq);
      expect(serialized.id).toBe('trace-12345');
      expect(serialized.method).toBe('POST');
      expect(serialized.url).toBe('/api/v1/auth/login');
      expect(serialized.query).toEqual({ queryKey: '123' });
      // Headers are NOT included in the compact INFO serialization
      expect((serialized as any).headers).toBeUndefined();
    });

    it('compacts response serialization to status code only without dumping response headers', () => {
      expect(compactSerializers.res).toBeDefined();

      const mockRes = {
        statusCode: 200,
        headers: {
          'content-type': 'application/json',
          'x-correlation-id': 'trace-12345',
          'x-powered-by': 'Express',
        },
      };

      const serialized = compactSerializers.res(mockRes);
      expect(serialized.statusCode).toBe(200);
      expect((serialized as any).headers).toBeUndefined();
    });
  });

  describe('httpLogger Custom Log Levels (Error Observability)', () => {
    it('assigns INFO level for successful responses (2xx and 3xx)', () => {
      expect(customLogLevel({}, { statusCode: 200 }, null)).toBe('info');
      expect(customLogLevel({}, { statusCode: 201 }, null)).toBe('info');
      expect(customLogLevel({}, { statusCode: 304 }, null)).toBe('info');
    });

    it('preserves client errors (401, 403, 404, 422, 429) at WARN level so security events are observable', () => {
      // 401 Unauthorized / auth failure
      expect(customLogLevel({}, { statusCode: 401 }, null)).toBe('warn');
      // 403 Forbidden
      expect(customLogLevel({}, { statusCode: 403 }, null)).toBe('warn');
      // 404 Not Found
      expect(customLogLevel({}, { statusCode: 404 }, null)).toBe('warn');
      // 422 Unprocessable Entity
      expect(customLogLevel({}, { statusCode: 422 }, null)).toBe('warn');
      // 429 Rate Limited
      expect(customLogLevel({}, { statusCode: 429 }, null)).toBe('warn');
    });

    it('assigns ERROR level for server errors (5xx) or unhandled exceptions', () => {
      expect(customLogLevel({}, { statusCode: 500 }, null)).toBe('error');
      expect(customLogLevel({}, { statusCode: 502 }, null)).toBe('error');
      expect(customLogLevel({}, { statusCode: 503 }, null)).toBe('error');
      expect(customLogLevel({}, { statusCode: 200 }, new Error('Fatal DB crash'))).toBe('error');
    });
  });

  describe('httpLogger Compact Message Format & Full Path Consistency', () => {
    it('uses originalUrl over router-relative url to preserve canonical /api/v1 prefix without query strings', () => {
      // Simulate Express sub-router where req.url is stripped to '/PL_123' while req.originalUrl is '/api/v1/places/PL_123?filter=true'
      const mockReq = {
        id: 'corr-id-prefix',
        method: 'GET',
        url: '/PL_123?filter=true',
        originalUrl: '/api/v1/places/PL_123?filter=true',
        headers: {},
      };
      const mockRes = { statusCode: 200 };

      expect(getCleanUrl(mockReq)).toBe('/api/v1/places/PL_123');
      const message = customSuccessMessage(mockReq, mockRes, 12);
      expect(message).toBe('GET /api/v1/places/PL_123 200 12ms [corr-id-prefix]');

      const serialized = compactSerializers.req(mockReq);
      expect(serialized.url).toBe('/api/v1/places/PL_123');
    });

    it('formats successful requests as compact single-line messages with method, path, status, time, and correlation ID', () => {
      const mockReq = {
        id: 'corr-id-abc',
        method: 'GET',
        url: '/api/v1/auth/me?format=json',
        originalUrl: '/api/v1/auth/me?format=json',
        headers: {},
      };
      const mockRes = { statusCode: 200 };

      const message = customSuccessMessage(mockReq, mockRes, 15);
      expect(message).toBe('GET /api/v1/auth/me 200 15ms [corr-id-abc]');
    });

    it('formats failed requests with status, error message, and correlation ID', () => {
      const mockReq = {
        id: 'corr-id-err',
        method: 'POST',
        url: '/login',
        originalUrl: '/api/v1/auth/login',
        headers: {},
      };
      const mockRes = { statusCode: 401 };
      const err = new Error('Invalid credentials');

      const message = customErrorMessage(mockReq, mockRes, err);
      expect(message).toBe('POST /api/v1/auth/login 401 - Invalid credentials [corr-id-err]');
    });
  });
});
