import pino from 'pino';
import pinoHttp from 'pino-http';
import { randomUUID } from 'node:crypto';
import { env } from '../config/env';

/**
 * Valid correlation ID format specification:
 * - Length: 1 to 64 characters
 * - Character set: ASCII alphanumeric, hyphens, and underscores (/^[a-zA-Z0-9_-]{1,64}$/)
 * - Disallowed: Whitespace, control characters, CR/LF (header injection prevention), and punctuation outside [-_]
 */
export const SAFE_CORRELATION_ID_REGEX = /^[a-zA-Z0-9_-]{1,64}$/;

/**
 * Validates and sanitizes a candidate correlation ID.
 * If candidate matches the safe format, returns the trimmed candidate.
 * Otherwise, fails closed and generates a cryptographically random UUID v4.
 */
export function sanitizeCorrelationId(rawId: unknown): string {
  if (typeof rawId === 'string') {
    const trimmed = rawId.trim();
    if (SAFE_CORRELATION_ID_REGEX.test(trimmed)) {
      return trimmed;
    }
  }
  return randomUUID();
}

export const SENSITIVE_LOG_FIELDS = [
  'req.headers.authorization',
  'req.headers.cookie',
  'req.headers["set-cookie"]',
  'res.headers["set-cookie"]',
  'password',
  'newPassword',
  'currentPassword',
  'confirmPassword',
  'token',
  'refreshToken',
  'accessToken',
  'secret',
  'biography',
  '*.password',
  '*.newPassword',
  '*.currentPassword',
  '*.confirmPassword',
  '*.token',
  '*.refreshToken',
  '*.accessToken',
  '*.secret',
  '*.cookie',
  '*.authorization',
];

export const logger = pino({
  level: env.NODE_ENV === 'test' ? 'silent' : 'info',
  redact: {
    paths: SENSITIVE_LOG_FIELDS,
    censor: '[REDACTED]',
  },
});

export function getCleanUrl(req: any): string {
  const rawUrl = req?.originalUrl || req?.raw?.originalUrl || req?.url || '';
  return rawUrl.split('?')[0];
}

export function customLogLevel(_req: any, res: any, err?: any): string {
  if (res?.statusCode >= 500 || err) {
    return 'error';
  }
  if (res?.statusCode >= 400) {
    return 'warn';
  }
  return 'info';
}

export const compactSerializers = {
  req: (req: any) => ({
    id: req.id,
    method: req.method,
    url: getCleanUrl(req),
    query: req.query,
  }),
  res: (res: any) => ({
    statusCode: res.statusCode,
  }),
  err: pino.stdSerializers.err,
};

export function customSuccessMessage(req: any, res: any, responseTime: number): string {
  const correlationId = req.id || req.headers?.['x-correlation-id'] || 'no-id';
  const cleanUrl = getCleanUrl(req);
  return `${req.method} ${cleanUrl} ${res.statusCode} ${responseTime}ms [${correlationId}]`;
}

export function customErrorMessage(req: any, res: any, err: any): string {
  const correlationId = req.id || req.headers?.['x-correlation-id'] || 'no-id';
  const cleanUrl = getCleanUrl(req);
  return `${req.method} ${cleanUrl} ${res.statusCode} - ${err?.message || 'Request failed'} [${correlationId}]`;
}

export const httpLogger = pinoHttp({
  logger: logger as any,
  genReqId: (req) => {
    return sanitizeCorrelationId(req.headers['x-correlation-id']);
  },
  customLogLevel,
  serializers: compactSerializers,
  customSuccessMessage,
  customErrorMessage,
});
