import request from 'supertest';
import mongoose from 'mongoose';
import { createApp } from '../../src/app';

const app = createApp();

describe('GET /health, /health/liveness, /health/readiness', () => {
  it('returns 200 with status ok for base /health', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
    expect(res.body.services).toBeDefined();
    expect(res.body.services.database).toMatch(/connected|disconnected/);
  });

  it('returns 200 for /health/liveness probe even if process is running', async () => {
    const res = await request(app).get('/health/liveness');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.uptime).toBeDefined();
    expect(res.body.timestamp).toBeDefined();
  });

  it('returns 200 when database is connected on /health/readiness', async () => {
    const res = await request(app).get('/health/readiness');
    // If readyState is 1 (connected), status is 200; if 0 (disconnected), status is 503
    if (mongoose.connection.readyState === 1) {
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
    } else {
      expect(res.status).toBe(503);
      expect(res.body.status).toBe('degraded');
    }
    expect(res.body.services.database).toBeDefined();
  });

  it('returns 404 for unknown routes', async () => {
    const res = await request(app).get('/api/v1/nonexistent');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  describe('Canonical /api/v1/health endpoints', () => {
    it('returns 200 with status ok for canonical /api/v1/health', async () => {
      const res = await request(app).get('/api/v1/health');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.timestamp).toBeDefined();
      expect(res.body.services).toBeDefined();
      expect(res.body.services.database).toMatch(/connected|disconnected/);
    });

    it('returns 200 for canonical /api/v1/health/liveness probe', async () => {
      const res = await request(app).get('/api/v1/health/liveness');
      expect(res.status).toBe(200);
      expect(res.body.status).toBe('ok');
      expect(res.body.uptime).toBeDefined();
      expect(res.body.timestamp).toBeDefined();
    });

    it('returns valid status for canonical /api/v1/health/readiness probe', async () => {
      const res = await request(app).get('/api/v1/health/readiness');
      if (mongoose.connection.readyState === 1) {
        expect(res.status).toBe(200);
        expect(res.body.status).toBe('ok');
      } else {
        expect(res.status).toBe(503);
        expect(res.body.status).toBe('degraded');
      }
      expect(res.body.services.database).toBeDefined();
    });
  });

  describe('Removed duplicate legacy mounts return 404', () => {
    it('returns 404 for legacy unprefixed /claims mount', async () => {
      const res = await request(app).get('/claims');
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 404 for legacy unprefixed /evidence mount', async () => {
      const res = await request(app).get('/evidence');
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 404 for legacy unprefixed /verification mount', async () => {
      const res = await request(app).get('/verification');
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 404 for legacy unprefixed /places mount', async () => {
      const res = await request(app).get('/places');
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 404 for legacy unprefixed /auth mount', async () => {
      const res = await request(app).post('/auth/login').send({ email: 'test@example.com', password: 'password123' });
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });
  });
});
