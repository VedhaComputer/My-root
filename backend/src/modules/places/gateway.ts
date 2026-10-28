import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env, PLACEHOLDER_APP_GATE_SECRET } from '../../config/env';
import { AuthenticatedRequest } from '../../shared/types';
import { logger, sanitizeCorrelationId } from '../../shared/logger';

interface CachedAppToken {
  token: string;
  expiresAt: number;
  secret: string;
}

export interface HealthCheckOptions {
  timeoutMs?: number;
  maxRetries?: number;
  initialRetryDelayMs?: number;
  silent?: boolean;
}

export interface HealthCheckResult {
  connected: boolean;
  status?: number;
  service?: string;
  error?: string;
  attempts: number;
}

/**
 * Sanitizes connection errors and responses to ensure no credentials, tokens,
 * passwords, or sensitive connection parameters are exposed in log messages.
 */
export function sanitizeConnectionError(error: unknown): string {
  let message = 'Unknown connection error';
  if (error instanceof Error) {
    const cause = (error as any)?.cause;
    if (cause && typeof cause === 'object' && (cause.code || cause.message)) {
      message = `${error.message}: ${cause.code || cause.message}`;
    } else {
      message = error.message;
    }
  } else if (typeof error === 'string') {
    message = error;
  }

  // Redact Bearer tokens and authorization headers
  message = message.replace(/Bearer\s+[a-zA-Z0-9._-]+/gi, 'Bearer [REDACTED]');
  // Redact secrets, passwords, tokens in query/body strings
  message = message.replace(/(key|secret|token|password|auth)=[^&\s]+/gi, '$1=[REDACTED]');
  // Redact credentials in URLs (e.g. user:pass@host)
  message = message.replace(/(?:[a-zA-Z0-9._%+-]+):(?:[^\s@:]+)@/g, '<REDACTED_CREDENTIALS>@');
  // Redact MongoDB connection URIs
  message = message.replace(/mongodb(?:\+srv)?:\/\/[^\s'",]+/gi, '<REDACTED_URI>');
  // Strip control characters and newlines (CRLF injection prevention)
  message = message.replace(/[\r\n\t]/g, ' ').replace(/\s+/g, ' ').trim();

  if (message.length > 200) {
    message = message.substring(0, 197) + '...';
  }

  return message;
}

let cachedAppToken: CachedAppToken | null = null;

export class PlaceGatewayService {
  private baseUrl: string;
  private timeoutMs: number;

  constructor(
    baseUrl: string = env.PLACE_API_BASE_URL,
    timeoutMs: number = env.PLACE_API_TIMEOUT_MS
  ) {
    this.baseUrl = baseUrl.replace(/\/+$/, '');
    this.timeoutMs = timeoutMs;
  }

  public isProxyEnabled(): boolean {
    if (process.env.PLACE_API_PROXY_ENABLED !== undefined) {
      return process.env.PLACE_API_PROXY_ENABLED === 'true';
    }
    return env.PLACE_API_PROXY_ENABLED;
  }

  public getAppAttestationToken(): string {
    // 1. Use explicitly configured static token if available
    const envToken = process.env.PLACE_API_APP_TOKEN || env.PLACE_API_APP_TOKEN;
    if (envToken && envToken.trim()) {
      return envToken.trim();
    }

    const secret =
      process.env.PLACE_API_APP_GATE_SECRET ||
      env.PLACE_API_APP_GATE_SECRET ||
      PLACEHOLDER_APP_GATE_SECRET;

    if (env.NODE_ENV === 'production' && (!secret || secret === PLACEHOLDER_APP_GATE_SECRET)) {
      throw new Error('PLACE_API_APP_GATE_SECRET cannot use placeholder in production environment');
    }

    // 2. Check memory cache for unexpired service attestation token signed with same secret
    const now = Date.now();
    if (
      cachedAppToken &&
      cachedAppToken.secret === secret &&
      cachedAppToken.expiresAt > now + 60000
    ) {
      return cachedAppToken.token;
    }

    // 3. Generate approved service attestation token using configured app gate secret
    const token = jwt.sign(
      {
        appId: 'myroot-backend-gateway',
        platform: 'service' as const,
        isApproved: true,
      },
      secret,
      { expiresIn: '1h' }
    );

    cachedAppToken = {
      token,
      expiresAt: now + 3600000,
      secret,
    };

    return token;
  }

  /**
   * Explicitly map outgoing contract differences (Frontend -> Place API).
   * E.g. Flutter sends level 'STATE', Place API uses 'STATE_UT'.
   */
  public mapOutgoingLevel(level?: string): string | undefined {
    if (!level) return undefined;
    if (level === 'STATE') return 'STATE_UT';
    return level;
  }

  /**
   * Explicitly map incoming contract differences (Place API -> Frontend).
   * Ensures 'id' is always populated for Flutter (from _id if necessary),
   * and maps 'STATE_UT' to 'STATE'.
   */
  public mapIncomingPlaceData(data: any): any {
    if (!data) return data;

    if (Array.isArray(data)) {
      return data.map((item) => this.mapIncomingPlaceData(item));
    }

    if (typeof data === 'object') {
      const mapped = { ...data };
      if (!mapped.id && mapped._id) {
        mapped.id = mapped._id;
      }
      if (mapped.level === 'STATE_UT') {
        mapped.level = 'STATE';
      }
      if (Array.isArray(mapped.children)) {
        mapped.children = mapped.children.map((child: any) => this.mapIncomingPlaceData(child));
      }
      if (Array.isArray(mapped.parentPath)) {
        mapped.parentPath = mapped.parentPath.map((p: any) => this.mapIncomingPlaceData(p));
      }
      return mapped;
    }

    return data;
  }

  /**
   * Core proxy dispatcher with strict security guardrails:
   * - Destination URL is strictly fixed to ${baseUrl}${path}; arbitrary destinations are rejected.
   * - Path variables are encoded to prevent traversal.
   * - User RS256 token is forwarded as Bearer token; never altered or minted.
   * - App attestation is sent via X-App-Attestation; never conflated with user identity.
   * - Sensible timeouts and non-leaking errors.
   */
  public async executeProxy(
    method: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE',
    subPath: string,
    req?: Request,
    body?: any
  ): Promise<{ status: number; body: any }> {
    const targetUrl = new URL(`${this.baseUrl}${subPath}`);

    // Forward sanitized query parameters strictly matching allowlist
    const ALLOWED_QUERY_PARAMS = ['level', 'parentId', 'search', 'page', 'limit'];
    if (req?.query && Object.keys(req.query).length > 0) {
      // 1. Strict positive integer validation for page
      if ('page' in req.query) {
        const rawPage = req.query.page;
        const pageStr = typeof rawPage === 'string' ? rawPage.trim() : typeof rawPage === 'number' ? String(rawPage) : '';
        if (!pageStr || !/^[1-9]\d*$/.test(pageStr) || !Number.isSafeInteger(Number(pageStr))) {
          return {
            status: 400,
            body: {
              error: {
                code: 'VALIDATION_ERROR',
                message: 'Invalid page parameter: must be a strict positive integer',
              },
            },
          };
        }
      }

      // 2. Strict positive integer validation for limit (1..100)
      if ('limit' in req.query) {
        const rawLimit = req.query.limit;
        const limitStr = typeof rawLimit === 'string' ? rawLimit.trim() : typeof rawLimit === 'number' ? String(rawLimit) : '';
        const limitNum = Number(limitStr);
        if (!limitStr || !/^[1-9]\d*$/.test(limitStr) || !Number.isSafeInteger(limitNum) || limitNum < 1 || limitNum > 100) {
          return {
            status: 400,
            body: {
              error: {
                code: 'VALIDATION_ERROR',
                message: 'Invalid limit parameter: must be a positive integer between 1 and 100',
              },
            },
          };
        }
      }

      // 3. Strict validation for parentId matching project's place ID pattern
      if ('parentId' in req.query) {
        const rawParentId = req.query.parentId;
        const parentIdStr = typeof rawParentId === 'string' ? rawParentId.trim() : '';
        if (!parentIdStr || !/^[a-zA-Z0-9_-]{2,100}$/.test(parentIdStr)) {
          return {
            status: 400,
            body: {
              error: {
                code: 'VALIDATION_ERROR',
                message: 'Invalid parentId parameter format',
              },
            },
          };
        }
      }

      for (const [key, val] of Object.entries(req.query)) {
        if (!ALLOWED_QUERY_PARAMS.includes(key)) {
          continue;
        }
        if (typeof val === 'string' || typeof val === 'number') {
          const stringVal = String(val).trim();
          if (stringVal.length > 0 && stringVal.length <= 100) {
            if (key === 'level') {
              targetUrl.searchParams.set(key, this.mapOutgoingLevel(stringVal)!);
            } else {
              targetUrl.searchParams.set(key, stringVal);
            }
          }
        }
      }
    }

    // Construct forward headers
    const headers: Record<string, string> = {
      Accept: 'application/json',
    };

    if (body && ['POST', 'PUT', 'PATCH'].includes(method)) {
      headers['Content-Type'] = 'application/json';
    }

    // Forward user RS256 access token if present
    if (req?.headers?.authorization) {
      headers['Authorization'] = req.headers.authorization;
    }

    // Strip untrusted client-supplied X-App-Attestation and attach Gateway's trusted service attestation token
    headers['X-App-Attestation'] = this.getAppAttestationToken();

    try {
      const response = await fetch(targetUrl.toString(), {
        method,
        headers,
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(this.timeoutMs),
      });

      let responseData: any;
      const contentType = response.headers.get('content-type') || '';
      if (contentType.includes('application/json')) {
        responseData = await response.json();
      } else {
        const text = await response.text();
        responseData = { message: text };
      }

      // Map incoming response data for contract compatibility
      if (responseData && responseData.data) {
        responseData.data = this.mapIncomingPlaceData(responseData.data);
      }

      if (response.status >= 400) {
        const correlationId = sanitizeCorrelationId(req?.headers?.['x-correlation-id']);
        const hasAuthHeader = Boolean(req?.headers?.authorization && req.headers.authorization.startsWith('Bearer '));
        logger.warn(
          {
            correlationId,
            subPath,
            status: response.status,
            hasAuthHeader,
            upstreamCode: responseData?.error?.code || 'UNKNOWN',
          },
          `[PlaceGateway] Upstream India Place API returned status ${response.status}`
        );
      }

      return {
        status: response.status,
        body: responseData,
      };
    } catch (error: any) {
      const correlationId = sanitizeCorrelationId(req?.headers?.['x-correlation-id']);
      const cause = error?.cause as any;
      const errorCode = cause?.code || error?.code;
      const errorMessage = cause?.message || error?.message || '';

      if (
        error?.name === 'TimeoutError' ||
        error?.name === 'AbortError' ||
        errorCode === 'ETIMEDOUT' ||
        cause?.name === 'TimeoutError' ||
        cause?.name === 'AbortError'
      ) {
        logger.warn(
          { correlationId, subPath, error: 'TIMEOUT' },
          '[PlaceGateway] Upstream India Place API request timed out'
        );
        return {
          status: 504,
          body: {
            error: {
              code: 'GATEWAY_TIMEOUT',
              message: 'Upstream India Place API request timed out',
            },
          },
        };
      }

      logger.warn(
        { correlationId, subPath, error: errorMessage || 'CONNECT_ERROR' },
        '[PlaceGateway] Failed to connect to upstream India Place API'
      );
      return {
        status: 502,
        body: {
          error: {
            code: 'BAD_GATEWAY',
            message: 'Failed to connect to upstream India Place API',
          },
        },
      };
    }
  }

  public getBaseUrl(): string {
    return this.baseUrl;
  }

  /**
   * Verifies connectivity to the configured upstream My Place API.
   * Performs an unauthenticated HTTP GET to /health with bounded timeout and retries.
   * Never logs sensitive keys, credentials, or tokens.
   */
  public async checkUpstreamHealth(options?: HealthCheckOptions): Promise<HealthCheckResult> {
    try {
      const baseUrl = this.baseUrl?.trim() || '';
      if (!baseUrl) {
        const sanitizedReason = 'PLACE_API_BASE_URL is not configured';
        if (!options?.silent) {
          console.warn(`[PlaceGateway] My Place API connection failed: ${sanitizedReason}`);
          logger.warn({ error: sanitizedReason }, `[PlaceGateway] My Place API connection failed: ${sanitizedReason}`);
        }
        return { connected: false, error: sanitizedReason, attempts: 0 };
      }

      let healthUrl: string;
      try {
        healthUrl = new URL(`${baseUrl}/health`).toString();
      } catch (urlErr) {
        const sanitizedReason = `Invalid base URL (${sanitizeConnectionError(urlErr)})`;
        if (!options?.silent) {
          console.warn(`[PlaceGateway] My Place API connection failed: ${sanitizedReason}`);
          logger.warn({ baseUrl, error: sanitizedReason }, `[PlaceGateway] My Place API connection failed: ${sanitizedReason}`);
        }
        return { connected: false, error: sanitizedReason, attempts: 0 };
      }

      const timeoutMs = options?.timeoutMs ?? Math.min(this.timeoutMs, 3000);
      const maxRetries = options?.maxRetries ?? 2;
      const initialDelay = options?.initialRetryDelayMs ?? 300;
      const totalAttempts = 1 + Math.max(0, maxRetries);

      if (!options?.silent) {
        console.log(`[PlaceGateway] Checking My Place API at ${baseUrl} ...`);
        logger.info({ baseUrl, healthUrl }, `[PlaceGateway] Checking My Place API at ${baseUrl} ...`);
      }

      let lastError = 'Unknown error';
      let lastStatus: number | undefined;

      for (let attempt = 1; attempt <= totalAttempts; attempt++) {
        try {
          const response = await fetch(healthUrl, {
            method: 'GET',
            headers: {
              Accept: 'application/json',
            },
            signal: AbortSignal.timeout(timeoutMs),
          });

          lastStatus = response.status;

          if (response.status === 200) {
            let body: any = null;
            const contentType = response.headers.get('content-type') || '';
            if (contentType.includes('application/json')) {
              body = await response.json().catch(() => null);
            }

            if (!options?.silent) {
              console.log('[PlaceGateway] My Place API connection established');
              logger.info(
                {
                  baseUrl,
                  service: body?.service || 'india-place-api',
                  status: response.status,
                  attempts: attempt,
                },
                '[PlaceGateway] My Place API connection established'
              );
            }

            return {
              connected: true,
              status: response.status,
              service: body?.service || 'india-place-api',
              attempts: attempt,
            };
          }

          lastError = `Upstream returned HTTP status ${response.status}`;
        } catch (err: any) {
          const cause = err?.cause as any;
          const errorCode = cause?.code || err?.code;
          const errorMessage = cause?.message || err?.message || '';

          if (
            err?.name === 'TimeoutError' ||
            err?.name === 'AbortError' ||
            errorCode === 'ETIMEDOUT' ||
            cause?.name === 'TimeoutError' ||
            cause?.name === 'AbortError'
          ) {
            lastError = `Request timed out after ${timeoutMs}ms`;
          } else if (errorCode === 'ECONNREFUSED' || errorMessage.includes('ECONNREFUSED')) {
            lastError = 'Connection refused (ECONNREFUSED)';
          } else {
            lastError = sanitizeConnectionError(errorMessage || err?.message || 'Connection error');
          }
        }

        if (attempt < totalAttempts) {
          const delay = initialDelay * Math.pow(2, attempt - 1);
          if (delay > 0) {
            await new Promise((resolve) => setTimeout(resolve, delay));
          }
        }
      }

      const sanitizedReason = sanitizeConnectionError(lastError);
      if (!options?.silent) {
        console.warn(`[PlaceGateway] My Place API connection failed: ${sanitizedReason}`);
        logger.warn(
          {
            baseUrl,
            error: sanitizedReason,
            status: lastStatus,
            attempts: totalAttempts,
          },
          `[PlaceGateway] My Place API connection failed: ${sanitizedReason}`
        );
      }

      return {
        connected: false,
        status: lastStatus,
        error: sanitizedReason,
        attempts: totalAttempts,
      };
    } catch (unexpectedError: any) {
      const sanitizedReason = sanitizeConnectionError(unexpectedError);
      if (!options?.silent) {
        console.warn(`[PlaceGateway] My Place API connection failed: ${sanitizedReason}`);
        logger.warn(
          { baseUrl: this.baseUrl, error: sanitizedReason },
          `[PlaceGateway] My Place API connection failed: ${sanitizedReason}`
        );
      }
      return {
        connected: false,
        error: sanitizedReason,
        attempts: 0,
      };
    }
  }

  // ==========================================
  // Route Handlers for Controller Integration
  // ==========================================

  public listPlaces = async (req: Request, res: Response, _next: NextFunction): Promise<void> => {
    const result = await this.executeProxy('GET', '/places', req);
    res.status(result.status).json(result.body);
  };

  public getPlaceById = async (req: Request, res: Response, _next: NextFunction): Promise<void> => {
    const id = encodeURIComponent(req.params.id);
    const result = await this.executeProxy('GET', `/places/${id}`, req);
    res.status(result.status).json(result.body);
  };

  public getChildren = async (req: Request, res: Response, _next: NextFunction): Promise<void> => {
    const id = encodeURIComponent(req.params.id);
    const result = await this.executeProxy('GET', `/places/${id}/children`, req);
    res.status(result.status).json(result.body);
  };

  public createPlace = async (
    req: AuthenticatedRequest,
    res: Response,
    _next: NextFunction
  ): Promise<void> => {
    const outgoingBody = { ...req.body };
    if (outgoingBody.level) {
      outgoingBody.level = this.mapOutgoingLevel(outgoingBody.level);
    }

    const result = await this.executeProxy('POST', '/places', req, outgoingBody);
    res.status(result.status).json(result.body);
  };

  public updatePlace = async (
    req: AuthenticatedRequest,
    res: Response,
    _next: NextFunction
  ): Promise<void> => {
    const id = encodeURIComponent(req.params.id);
    const outgoingBody = { ...req.body };
    if (outgoingBody.level) {
      outgoingBody.level = this.mapOutgoingLevel(outgoingBody.level);
    }

    // Explicitly map Flutter's PUT to Place API's PATCH
    const result = await this.executeProxy('PATCH', `/places/${id}`, req, outgoingBody);
    res.status(result.status).json(result.body);
  };

  public deletePlace = async (
    req: AuthenticatedRequest,
    res: Response,
    _next: NextFunction
  ): Promise<void> => {
    const id = encodeURIComponent(req.params.id);
    const result = await this.executeProxy('DELETE', `/places/${id}`, req);
    res.status(result.status).json(result.body);
  };
}

export const placeGatewayService = new PlaceGatewayService();
