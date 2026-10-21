import { Router, Request, Response } from 'express';
import { getDatabaseStatus } from '../../config/database';

const router = Router();

// Liveness probe: verifies process is alive and responsive. Does NOT fail on external dependency outage.
router.get('/liveness', (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

// Readiness probe: verifies server is ready to accept traffic (database must be connected).
router.get('/readiness', (_req: Request, res: Response) => {
  const dbStatus = getDatabaseStatus();
  const isReady = dbStatus === 'connected';

  res.status(isReady ? 200 : 503).json({
    status: isReady ? 'ok' : 'degraded',
    services: {
      database: dbStatus,
    },
    timestamp: new Date().toISOString(),
  });
});

// Backward-compatible base health check
router.get('/', (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version ?? '1.0.0',
    services: {
      database: getDatabaseStatus(),
    },
  });
});

export default router;
