import { PlaceGatewayService, sanitizeConnectionError } from '../../../src/modules/places/gateway';

describe('PlaceGateway Upstream Health Check (Unit Tests)', () => {
  let fetchSpy: jest.SpyInstance;
  let consoleLogSpy: jest.SpyInstance;
  let consoleWarnSpy: jest.SpyInstance;

  beforeEach(() => {
    fetchSpy = jest.spyOn(global, 'fetch');
    consoleLogSpy = jest.spyOn(console, 'log').mockImplementation(() => {});
    consoleWarnSpy = jest.spyOn(console, 'warn').mockImplementation(() => {});
  });

  afterEach(() => {
    fetchSpy.mockRestore();
    consoleLogSpy.mockRestore();
    consoleWarnSpy.mockRestore();
  });

  describe('1. Successful Health Response', () => {
    it('establishes connection on 200 OK health response and logs status', async () => {
      const gateway = new PlaceGatewayService('http://localhost:4001', 3000);

      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            status: 'ok',
            service: 'india-place-api',
            timestamp: new Date().toISOString(),
          }),
          {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const result = await gateway.checkUpstreamHealth({ initialRetryDelayMs: 0 });

      expect(result.connected).toBe(true);
      expect(result.status).toBe(200);
      expect(result.service).toBe('india-place-api');
      expect(result.attempts).toBe(1);

      expect(fetchSpy).toHaveBeenCalledTimes(1);
      const [url, init] = fetchSpy.mock.calls[0];
      expect(url.toString()).toBe('http://localhost:4001/health');
      expect(init.method).toBe('GET');
      expect(init.headers['Accept']).toBe('application/json');

      // Verify required startup log messages
      expect(consoleLogSpy).toHaveBeenCalledWith(
        '[PlaceGateway] Checking My Place API at http://localhost:4001 ...'
      );
      expect(consoleLogSpy).toHaveBeenCalledWith(
        '[PlaceGateway] My Place API connection established'
      );
      expect(consoleWarnSpy).not.toHaveBeenCalled();
    });
  });

  describe('2. Unsuccessful HTTP Status Handling', () => {
    it('handles 503 status, retries boundedly, and logs sanitized failure', async () => {
      const gateway = new PlaceGatewayService('http://localhost:4001', 1000);

      fetchSpy.mockResolvedValue(
        new Response(
          JSON.stringify({ status: 'error', message: 'Database disconnected' }),
          {
            status: 503,
            headers: { 'Content-Type': 'application/json' },
          }
        )
      );

      const result = await gateway.checkUpstreamHealth({
        maxRetries: 2,
        initialRetryDelayMs: 0,
      });

      expect(result.connected).toBe(false);
      expect(result.status).toBe(503);
      expect(result.attempts).toBe(3); // Initial + 2 retries
      expect(result.error).toContain('Upstream returned HTTP status 503');

      expect(fetchSpy).toHaveBeenCalledTimes(3);
      expect(consoleWarnSpy).toHaveBeenCalledWith(
        expect.stringContaining('[PlaceGateway] My Place API connection failed: Upstream returned HTTP status 503')
      );
    });

    it('handles 404 status and logs failure', async () => {
      const gateway = new PlaceGatewayService('http://localhost:4001', 1000);

      fetchSpy.mockResolvedValue(
        new Response('Not Found', { status: 404, headers: { 'Content-Type': 'text/plain' } })
      );

      const result = await gateway.checkUpstreamHealth({
        maxRetries: 1,
        initialRetryDelayMs: 0,
      });

      expect(result.connected).toBe(false);
      expect(result.status).toBe(404);
      expect(result.attempts).toBe(2);
      expect(consoleWarnSpy).toHaveBeenCalledWith(
        expect.stringContaining('[PlaceGateway] My Place API connection failed: Upstream returned HTTP status 404')
      );
    });
  });

  describe('3. Connection Refusal & Network Errors', () => {
    it('retries on ECONNREFUSED and logs failure after exhausting retries', async () => {
      const gateway = new PlaceGatewayService('http://localhost:4001', 1000);

      const connError = new Error('connect ECONNREFUSED 127.0.0.1:4001');
      (connError as any).code = 'ECONNREFUSED';
      fetchSpy.mockRejectedValue(connError);

      const result = await gateway.checkUpstreamHealth({
        maxRetries: 2,
        initialRetryDelayMs: 0,
      });

      expect(result.connected).toBe(false);
      expect(result.attempts).toBe(3);
      expect(result.error).toContain('Connection refused (ECONNREFUSED)');
      expect(fetchSpy).toHaveBeenCalledTimes(3);

      expect(consoleWarnSpy).toHaveBeenCalledWith(
        '[PlaceGateway] My Place API connection failed: Connection refused (ECONNREFUSED)'
      );
    });

    it('recovers if second retry succeeds', async () => {
      const gateway = new PlaceGatewayService('http://localhost:4001', 1000);

      const connError = new Error('connect ECONNREFUSED 127.0.0.1:4001');
      (connError as any).code = 'ECONNREFUSED';

      // 1st attempt fails, 2nd attempt succeeds
      fetchSpy
        .mockRejectedValueOnce(connError)
        .mockResolvedValueOnce(
          new Response(JSON.stringify({ status: 'ok', service: 'india-place-api' }), {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          })
        );

      const result = await gateway.checkUpstreamHealth({
        maxRetries: 2,
        initialRetryDelayMs: 0,
      });

      expect(result.connected).toBe(true);
      expect(result.status).toBe(200);
      expect(result.attempts).toBe(2);
      expect(fetchSpy).toHaveBeenCalledTimes(2);

      expect(consoleLogSpy).toHaveBeenCalledWith(
        '[PlaceGateway] My Place API connection established'
      );
      expect(consoleWarnSpy).not.toHaveBeenCalled();
    });

    it('correctly classifies undici TypeError("fetch failed") with ECONNREFUSED cause', async () => {
      const gateway = new PlaceGatewayService('http://localhost:4001', 1000);

      const undiciError = new TypeError('fetch failed');
      (undiciError as any).cause = Object.assign(new Error('connect ECONNREFUSED 127.0.0.1:4001'), {
        code: 'ECONNREFUSED',
      });
      fetchSpy.mockRejectedValue(undiciError);

      const result = await gateway.checkUpstreamHealth({
        maxRetries: 1,
        initialRetryDelayMs: 0,
      });

      expect(result.connected).toBe(false);
      expect(result.attempts).toBe(2);
      expect(result.error).toBe('Connection refused (ECONNREFUSED)');
      expect(consoleWarnSpy).toHaveBeenCalledWith(
        '[PlaceGateway] My Place API connection failed: Connection refused (ECONNREFUSED)'
      );
    });
  });

  describe('4. Timeout Handling', () => {
    it('handles AbortError/TimeoutError and retries boundedly', async () => {
      const gateway = new PlaceGatewayService('http://localhost:4001', 1000);

      const timeoutError = new Error('The operation was aborted');
      timeoutError.name = 'TimeoutError';
      fetchSpy.mockRejectedValue(timeoutError);

      const result = await gateway.checkUpstreamHealth({
        maxRetries: 1,
        initialRetryDelayMs: 0,
      });

      expect(result.connected).toBe(false);
      expect(result.attempts).toBe(2);
      expect(result.error).toContain('Request timed out');
      expect(consoleWarnSpy).toHaveBeenCalledWith(
        expect.stringContaining('[PlaceGateway] My Place API connection failed: Request timed out')
      );
    });

    it('handles undici TypeError("fetch failed") with timeout cause', async () => {
      const gateway = new PlaceGatewayService('http://localhost:4001', 1000);

      const undiciError = new TypeError('fetch failed');
      (undiciError as any).cause = Object.assign(new Error('The operation was aborted due to timeout'), {
        name: 'TimeoutError',
        code: 'ETIMEDOUT',
      });
      fetchSpy.mockRejectedValue(undiciError);

      const result = await gateway.checkUpstreamHealth({
        maxRetries: 1,
        initialRetryDelayMs: 0,
      });

      expect(result.connected).toBe(false);
      expect(result.attempts).toBe(2);
      expect(result.error).toContain('Request timed out');
      expect(consoleWarnSpy).toHaveBeenCalledWith(
        expect.stringContaining('[PlaceGateway] My Place API connection failed: Request timed out')
      );
    });
  });

  describe('5. Base URL Validation', () => {
    it('fails clearly when PLACE_API_BASE_URL is empty', async () => {
      const gateway = new PlaceGatewayService('', 1000);

      const result = await gateway.checkUpstreamHealth();

      expect(result.connected).toBe(false);
      expect(result.attempts).toBe(0);
      expect(result.error).toBe('PLACE_API_BASE_URL is not configured');
      expect(consoleWarnSpy).toHaveBeenCalledWith(
        '[PlaceGateway] My Place API connection failed: PLACE_API_BASE_URL is not configured'
      );
      expect(fetchSpy).not.toHaveBeenCalled();
    });

    it('fails clearly when PLACE_API_BASE_URL is malformed', async () => {
      const gateway = new PlaceGatewayService('://malformed-url', 1000);

      const result = await gateway.checkUpstreamHealth();

      expect(result.connected).toBe(false);
      expect(result.attempts).toBe(0);
      expect(result.error).toContain('Invalid base URL');
      expect(consoleWarnSpy).toHaveBeenCalledWith(
        expect.stringContaining('[PlaceGateway] My Place API connection failed: Invalid base URL')
      );
      expect(fetchSpy).not.toHaveBeenCalled();
    });
  });

  describe('6. Error Sanitization Guardrails', () => {
    it('redacts tokens, credentials, secrets, and newlines from errors', () => {
      const sensitiveMsg =
        'Error connecting with Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.token and secret=supersecret123 to mongodb://user:pass@localhost:27017\r\nAttack line';
      const sanitized = sanitizeConnectionError(sensitiveMsg);

      expect(sanitized).not.toContain('eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9');
      expect(sanitized).toContain('Bearer [REDACTED]');
      expect(sanitized).not.toContain('supersecret123');
      expect(sanitized).toContain('secret=[REDACTED]');
      expect(sanitized).not.toContain('user:pass@');
      expect(sanitized).not.toContain('\r');
      expect(sanitized).not.toContain('\n');
    });
  });
});
