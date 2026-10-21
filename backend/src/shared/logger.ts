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

export const logger = pino({
  level: env.NODE_ENV === 'test' ? 'silent' : 'info',
  redact: {
    paths: [
      'req.headers.authorization',
      'req.headers.cookie',
      'password',
      'token',
      'refreshToken',
      'accessToken',
      'secret',
      'biography',
      '*.password',
      '*.token',
      '*.secret',
    ],
    remove: true,
  },
});

export const httpLogger = pinoHttp({
  logger,
  genReqId: (req) => {
    return sanitizeCorrelationId(req.headers['x-correlation-id']);
  },
});
