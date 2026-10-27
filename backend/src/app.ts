import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import path from 'path';
import { env } from './config/env';
import { httpLogger, sanitizeCorrelationId } from './shared/logger';
import { errorHandler } from './middleware/errorHandler';
import { generalRateLimiter } from './middleware/rateLimiter';
import healthRouter from './modules/health/routes';
import authRouter from './modules/auth/routes';
import placesRouter from './modules/places/routes';
import claimsRouter from './modules/claims/routes';
import evidenceRouter from './modules/evidence/routes';
import verificationRouter from './modules/verification/routes';
import pollsRouter from './modules/polls/routes';

export function createApp(): express.Application {
  const app = express();

  // Correlation ID middleware: validate client-supplied ID or mint a new UUID
  app.use((req, res, next) => {
    const correlationId = sanitizeCorrelationId(req.headers['x-correlation-id']);
    req.headers['x-correlation-id'] = correlationId;
    res.setHeader('X-Correlation-ID', correlationId);
    next();
  });

  // Structured logging
  app.use(httpLogger);

  // Configure trusted proxy setting safely
  if (env.TRUST_PROXY === 'true') {
    app.set('trust proxy', true);
  } else if (env.TRUST_PROXY === 'false') {
    app.set('trust proxy', false);
  } else if (env.TRUST_PROXY) {
    app.set('trust proxy', env.TRUST_PROXY);
  }

  // Security headers
  app.use(helmet());

  // CORS
  app.use(cors({
    origin: env.CORS_ORIGINS.split(',').map(o => o.trim()),
    credentials: true,
  }));

  // Distributed rate limiting (shared RedisStore or MemoryStore in dev)
  app.use(generalRateLimiter);

  // Route-specific body limits to prevent Denial of Service via large payloads
  const standardJsonParser = express.json({ limit: '100kb' });
  const contentJsonParser = express.json({ limit: '500kb' });
  const uploadJsonParser = express.json({ limit: '10mb' });

  app.use('/api/v1/evidence', uploadJsonParser);
  app.use('/api/v1/claims', contentJsonParser);
  app.use(standardJsonParser);
  app.use(express.urlencoded({ extended: true, limit: '100kb' }));

  // Static uploads directory for persistent media assets
  const uploadDir = env.UPLOAD_DIR || path.resolve(process.cwd(), 'uploads');
  app.use('/uploads', express.static(uploadDir, { maxAge: '7d', dotfiles: 'ignore' }));

  // Routes
  // Documented exception: root /health endpoint preserved for Docker health checks & container orchestration
  app.use('/health', healthRouter);

  // Canonical versioned API routes
  app.use('/api/v1/health', healthRouter);
  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/places', placesRouter);
  app.use('/api/v1/claims', claimsRouter);
  app.use('/api/v1/evidence', evidenceRouter);
  app.use('/api/v1/verification', verificationRouter);
  app.use('/api/v1/polls', pollsRouter);

  // 404 handler
  app.use((_req, res) => {
    res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Route not found' } });
  });

  // Global error handler
  app.use(errorHandler);

  return app;
}
