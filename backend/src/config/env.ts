import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

export const PLACEHOLDER_APP_GATE_SECRET = 'replace_with_secure_random_secret_min_32_chars_for_apps';

export const envSchema = z
  .object({
    NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
    PORT: z.string().default('3001').transform(Number),
    MONGODB_URI: z.string().min(1, 'MONGODB_URI is required'),
    JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 chars'),
    JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 chars'),
    JWT_ACCESS_EXPIRES_IN: z.string().default('15m'),
    JWT_REFRESH_EXPIRES_IN: z.string().default('7d'),
    RATE_LIMIT_WINDOW_MS: z.string().default('900000').transform(Number),
    RATE_LIMIT_MAX: z.string().default('100').transform(Number),
    AUTH_RATE_LIMIT_WINDOW_MS: z.string().default('900000').transform(Number),
    AUTH_RATE_LIMIT_MAX: z.string().default('20').transform(Number),
    TRUST_PROXY: z.string().default('false'),
    CORS_ORIGINS: z.string().default('http://localhost:3000'),

    // Email Delivery Configuration
    EMAIL_FROM: z
      .string()
      .default('noreply@myroot.in')
      .refine((val) => !/[\r\n]/.test(val), {
        message: 'EMAIL_FROM cannot contain newline characters (CRLF injection prevention)',
      })
      .refine(
        (val) => {
          const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
          const formattedRegex = /^.+<[^\s@]+@[^\s@]+\.[^\s@]+>$/;
          return emailRegex.test(val.trim()) || formattedRegex.test(val.trim());
        },
        {
          message: 'EMAIL_FROM must be a valid email address (e.g. noreply@myroot.in or "My Root <noreply@myroot.in>")',
        }
      ),
    FRONTEND_URL: z.string().url().default('http://localhost:3000'),
    MAIL_TRANSPORT: z.enum(['console', 'test', 'smtp', 'custom']).optional(),
    SMTP_HOST: z.string().min(1).optional(),
    SMTP_PORT: z
      .string()
      .transform(Number)
      .pipe(z.number().int().min(1).max(65535))
      .default('587')
      .optional(),
    SMTP_SECURE: z
      .enum(['true', 'false'])
      .transform((v) => v === 'true')
      .optional(),
    SMTP_USER: z.string().min(1).optional(),
    SMTP_PASS: z.string().min(1).optional(),
    SMTP_TIMEOUT_MS: z
      .string()
      .transform(Number)
      .pipe(z.number().int().min(500).max(120000))
      .default('10000')
      .optional(),

    // RS256 Configuration (Optional in Phase 2; resolved via keys.ts)
    JWT_PRIVATE_KEY_PATH: z.string().optional(),
    JWT_PUBLIC_KEY_PATH: z.string().optional(),
    JWT_PRIVATE_KEY: z.string().optional(),
    JWT_PUBLIC_KEY: z.string().optional(),
    JWT_ISSUER: z.string().min(1).default('myroot-backend'),
    JWT_AUDIENCE: z.string().min(1).default('myroot-platform'),
    JWT_ALLOW_HS256_FALLBACK: z.enum(['true', 'false']).default('false').transform((v) => v === 'true'),

    // India Place API Gateway Configuration
    PLACE_API_BASE_URL: z.string().url().default('http://localhost:4001'),
    PLACE_API_APP_GATE_SECRET: z.string().min(32, 'PLACE_API_APP_GATE_SECRET must be at least 32 chars').optional(),
    PLACE_API_APP_TOKEN: z.string().optional(),
    PLACE_API_TIMEOUT_MS: z.string().default('5000').transform(Number),
    PLACE_API_PROXY_ENABLED: z.string().optional().transform((v) => {
      if (v !== undefined) return v === 'true';
      return process.env.NODE_ENV !== 'test';
    }),
  })
  .refine(
    (data) => {
      if (data.NODE_ENV === 'production' && data.PLACE_API_PROXY_ENABLED) {
        return (
          data.PLACE_API_APP_GATE_SECRET &&
          data.PLACE_API_APP_GATE_SECRET.length >= 32 &&
          data.PLACE_API_APP_GATE_SECRET !== PLACEHOLDER_APP_GATE_SECRET
        );
      }
      return true;
    },
    {
      message:
        'PLACE_API_APP_GATE_SECRET must be explicitly configured (min 32 chars) in production and cannot use the placeholder literal',
      path: ['PLACE_API_APP_GATE_SECRET'],
    }
  )
  .refine(
    (data) => {
      if (data.NODE_ENV === 'production') {
        if (data.MAIL_TRANSPORT === 'console' || data.MAIL_TRANSPORT === 'test' || data.MAIL_TRANSPORT === 'custom') {
          return false;
        }
        if (data.MAIL_TRANSPORT === 'smtp') {
          return !!(data.SMTP_HOST && data.SMTP_USER && data.SMTP_PASS && data.EMAIL_FROM);
        }
      }
      return true;
    },
    {
      message:
        'Production environment permits only MAIL_TRANSPORT=smtp (transports "console", "test", and "custom" are strictly prohibited; SMTP requires SMTP_HOST, SMTP_USER, SMTP_PASS, and EMAIL_FROM)',
      path: ['MAIL_TRANSPORT'],
    }
  );

const parseResult = envSchema.safeParse(process.env);

if (!parseResult.success) {
  console.error('❌ Invalid environment configuration:');
  console.error(parseResult.error.format());
  process.exit(1);
}

export const env = parseResult.data;
