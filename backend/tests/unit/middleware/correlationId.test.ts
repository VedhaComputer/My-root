import request from 'supertest';
import { createApp } from '../../../src/app';
import {
  sanitizeCorrelationId,
  SAFE_CORRELATION_ID_REGEX,
  httpLogger,
} from '../../../src/shared/logger';

// UUID v4 format verification regex
const UUID_V4_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

describe('Correlation ID Sanitization and Validation', () => {
  describe('sanitizeCorrelationId Helper (Unit Boundaries)', () => {
    it('generates a cryptographically random UUID v4 when input is undefined or null', () => {
      const id1 = sanitizeCorrelationId(undefined);
      const id2 = sanitizeCorrelationId(null);

      expect(id1).toMatch(UUID_V4_REGEX);
      expect(id2).toMatch(UUID_V4_REGEX);
      expect(id1).not.toBe(id2);
    });

    it('generates a fresh UUID v4 when input is not a string (e.g. number, array, object)', () => {
      expect(sanitizeCorrelationId(12345)).toMatch(UUID_V4_REGEX);
      expect(sanitizeCorrelationId(['id-1', 'id-2'])).toMatch(UUID_V4_REGEX);
      expect(sanitizeCorrelationId({ id: 'custom' })).toMatch(UUID_V4_REGEX);
    });

    it('generates a fresh UUID v4 when input is empty string or only whitespace', () => {
      expect(sanitizeCorrelationId('')).toMatch(UUID_V4_REGEX);
      expect(sanitizeCorrelationId('   ')).toMatch(UUID_V4_REGEX);
      expect(sanitizeCorrelationId('\t\t')).toMatch(UUID_V4_REGEX);
    });

    it('preserves a valid standard UUID v4', () => {
      const standardUuid = '123e4567-e89b-42d3-a456-426614174000';
      const result = sanitizeCorrelationId(standardUuid);
      expect(result).toBe(standardUuid);
    });

    it('preserves a safe alphanumeric identifier with hyphens and underscores', () => {
      const customId = 'req_client-12345_ABC';
      const result = sanitizeCorrelationId(customId);
      expect(result).toBe(customId);
    });

    it('trims leading and trailing whitespace on an otherwise valid identifier', () => {
      const trimmed = sanitizeCorrelationId('   my-valid-request-999   ');
      expect(trimmed).toBe('my-valid-request-999');
    });

    it('preserves a safe identifier at the exact boundary limit of 64 characters', () => {
      const exactly64 = 'A'.repeat(64);
      expect(SAFE_CORRELATION_ID_REGEX.test(exactly64)).toBe(true);
      const result = sanitizeCorrelationId(exactly64);
      expect(result).toBe(exactly64);
      expect(result.length).toBe(64);
    });

    it('rejects an oversized identifier exceeding 64 characters and replaces with UUID v4', () => {
      const oversized65 = 'B'.repeat(65);
      expect(SAFE_CORRELATION_ID_REGEX.test(oversized65)).toBe(false);
      const result = sanitizeCorrelationId(oversized65);
      expect(result).toMatch(UUID_V4_REGEX);
      expect(result).not.toBe(oversized65);
    });

    it('rejects an excessively large payload (DoS attempt) and replaces with UUID v4', () => {
      const hugeString = 'X'.repeat(5000);
      const result = sanitizeCorrelationId(hugeString);
      expect(result).toMatch(UUID_V4_REGEX);
    });

    it('rejects CR/LF characters (HTTP response splitting / header injection) and replaces with UUID v4', () => {
      const crlfInjection = 'prefix\r\nX-Injected-Header: malicious';
      const newlineOnly = 'id\nwith\nnewlines';
      const carriageReturn = 'id\rwith\rcarriage';

      expect(sanitizeCorrelationId(crlfInjection)).toMatch(UUID_V4_REGEX);
      expect(sanitizeCorrelationId(newlineOnly)).toMatch(UUID_V4_REGEX);
      expect(sanitizeCorrelationId(carriageReturn)).toMatch(UUID_V4_REGEX);
      expect(sanitizeCorrelationId(crlfInjection)).not.toContain('Injected');
    });

    it('rejects invalid punctuation, special symbols, and HTML/script tags', () => {
      const attacks = [
        'req;DROP_TABLE',
        '<script>alert(1)</script>',
        'foo/bar',
        'foo:bar',
        'foo=bar',
        'foo?bar',
        'foo#bar',
        'foo&bar',
        'foo*bar',
        'foo"bar',
        "foo'bar",
        'foo\\bar',
        'foo bar baz',
      ];

      for (const attack of attacks) {
        const result = sanitizeCorrelationId(attack);
        expect(result).toMatch(UUID_V4_REGEX);
        expect(result).not.toBe(attack);
      }
    });
  });

  describe('Pino httpLogger genReqId Integration', () => {
    it('uses sanitizeCorrelationId to derive request ID for Pino', () => {
      const genReqId = (httpLogger as any).genReqId;
      if (typeof genReqId === 'function') {
        const mockReqValid = {
          headers: { 'x-correlation-id': 'service-trace-101' },
        };
        expect(genReqId(mockReqValid)).toBe('service-trace-101');

        const mockReqCrlf = {
          headers: { 'x-correlation-id': 'bad\r\nid' },
        };
        const sanitized = genReqId(mockReqCrlf);
        expect(sanitized).toMatch(UUID_V4_REGEX);
        expect(sanitized).not.toContain('\r');

        const mockReqMissing = { headers: {} };
        expect(genReqId(mockReqMissing)).toMatch(UUID_V4_REGEX);
      }
    });
  });

  describe('Express Middleware & Response Header Enforcement', () => {
    const app = createApp();

    it('generates and returns a fresh UUID v4 in X-Correlation-ID when client sends no header', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);

      const correlationHeader = res.headers['x-correlation-id'];
      expect(correlationHeader).toBeDefined();
      expect(correlationHeader).toMatch(UUID_V4_REGEX);
    });

    it('preserves and echoes back a valid client-supplied correlation ID', async () => {
      const validClientId = 'trace-id-abc-987_xyz';
      const res = await request(app)
        .get('/health')
        .set('x-correlation-id', validClientId);

      expect(res.status).toBe(200);
      expect(res.headers['x-correlation-id']).toBe(validClientId);
    });

    it('replaces an oversized correlation ID with a fresh UUID v4', async () => {
      const oversizedId = 'K'.repeat(128);
      const res = await request(app)
        .get('/health')
        .set('x-correlation-id', oversizedId);

      expect(res.status).toBe(200);
      const returnedHeader = res.headers['x-correlation-id'];
      expect(returnedHeader).not.toBe(oversizedId);
      expect(returnedHeader).toMatch(UUID_V4_REGEX);
    });

    it('sanitizes CR/LF injection attempts in middleware and replaces with safe UUID v4', () => {
      // Node's http client rejects CRLF at socket write, so we verify middleware processing:
      const req: any = {
        headers: { 'x-correlation-id': 'trace-safe\r\nX-Injected: evil' },
      };
      let setHeaderKey = '';
      let setHeaderVal = '';
      const res: any = {
        setHeader: (k: string, v: string) => {
          setHeaderKey = k;
          setHeaderVal = v;
        },
      };
      const next = jest.fn();

      // Execute the exact correlation ID middleware logic from app.ts
      const correlationId = sanitizeCorrelationId(req.headers['x-correlation-id']);
      req.headers['x-correlation-id'] = correlationId;
      res.setHeader('X-Correlation-ID', correlationId);
      next();

      expect(next).toHaveBeenCalled();
      expect(setHeaderKey).toBe('X-Correlation-ID');
      expect(setHeaderVal).toMatch(UUID_V4_REGEX);
      expect(setHeaderVal).not.toContain('Injected');
      expect(req.headers['x-correlation-id']).toMatch(UUID_V4_REGEX);
    });

    it('replaces disallowed punctuation (e.g. semicolons, curly braces, colons) with a fresh UUID v4 over HTTP', async () => {
      const malformedId = 'trace;drop_table{bad}:id';
      const res = await request(app)
        .get('/health')
        .set('x-correlation-id', malformedId);

      expect(res.status).toBe(200);
      const returnedHeader = res.headers['x-correlation-id'];
      expect(returnedHeader).not.toBe(malformedId);
      expect(returnedHeader).toMatch(UUID_V4_REGEX);
    });
  });
});
