import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { env, PLACEHOLDER_APP_GATE_SECRET } from '../../config/env';
import { AuthenticatedRequest } from '../../shared/types';

interface CachedAppToken {
  token: string;
  expiresAt: number;
  secret: string;
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

    // Strip untrusted client-supplied X-App-Attestation and X-App-Token.
    // Attach Gateway's own trusted service attestation token.
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

      return {
        status: response.status,
        body: responseData,
      };
    } catch (error: any) {
      if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
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
