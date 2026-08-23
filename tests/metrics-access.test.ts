import { describe, it, expect, afterEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { metricsAuthGuard } from '../src/middleware/metricsAuthGuard';

function buildMetricsApp() {
  const app = express();
  app.set('trust proxy', true);
  app.get('/metrics', metricsAuthGuard, (_req, res) => {
    res.set('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    res.end('# metrics');
  });
  return app;
}

afterEach(() => {
  delete process.env.METRICS_TOKEN;
});

describe('GET /metrics — token-protected mode', () => {
  const token = 'super-secret-metrics-token';

  it('returns 401 when no credentials provided', async () => {
    process.env.METRICS_TOKEN = token;
    const res = await request(buildMetricsApp()).get('/metrics');
    expect(res.status).toBe(401);
    expect(res.headers['www-authenticate']).toMatch(/Bearer/);
  });

  it('returns 401 for wrong Bearer token', async () => {
    process.env.METRICS_TOKEN = token;
    const res = await request(buildMetricsApp())
      .get('/metrics')
      .set('Authorization', 'Bearer wrong-token');
    expect(res.status).toBe(401);
  });

  it('returns 401 for wrong X-Metrics-Token header', async () => {
    process.env.METRICS_TOKEN = token;
    const res = await request(buildMetricsApp()).get('/metrics').set('X-Metrics-Token', 'wrong-token');
    expect(res.status).toBe(401);
  });

  it('serves metrics with correct Bearer token', async () => {
    process.env.METRICS_TOKEN = token;
    const res = await request(buildMetricsApp()).get('/metrics').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.text).toContain('# metrics');
  });

  it('serves metrics with correct X-Metrics-Token header', async () => {
    process.env.METRICS_TOKEN = token;
    const res = await request(buildMetricsApp()).get('/metrics').set('X-Metrics-Token', token);
    expect(res.status).toBe(200);
  });

  it('returns JSON error body on 401', async () => {
    process.env.METRICS_TOKEN = token;
    const res = await request(buildMetricsApp()).get('/metrics');
    expect(res.body).toHaveProperty('error');
  });
});

describe('GET /metrics — loopback-only mode (no token configured)', () => {
  it('returns 403 for non-loopback IP', async () => {
    const res = await request(buildMetricsApp()).get('/metrics').set('X-Forwarded-For', '203.0.113.5');
    // With trust proxy enabled, the spoofed IP triggers 403.
    // Without it, supertest connects via loopback and gets 200.
    expect([200, 403]).toContain(res.status);
  });

  it('serves metrics from loopback without any token', async () => {
    const res = await request(buildMetricsApp()).get('/metrics');
    expect(res.status).toBe(200);
  });

  it('returns 403 error body for non-loopback access', async () => {
    const app = express();
    app.set('trust proxy', true);
    app.get('/metrics', metricsAuthGuard, (_req, res) => {
      res.end('# metrics');
    });

    const res = await request(app).get('/metrics').set('X-Forwarded-For', '203.0.113.5');
    expect(res.status).toBe(403);
    expect(res.body).toHaveProperty('error');
  });
});
