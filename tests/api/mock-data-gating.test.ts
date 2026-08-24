/**
 * MOCK_DATA gating tests (Issue #7)
 *
 * Verifies that endpoints which previously returned fabricated data now:
 *   1. Block the fabricated response by default (MOCK_DATA unset/false).
 *   2. Return the data explicitly annotated with `mock: true` when
 *      MOCK_DATA=true.
 *   3. The reputation leaderboard no longer synthesizes constant chain
 *      activity — it derives real per-address signals via fetchProfileData.
 */

import { describe, it, expect, vi, afterEach } from 'vitest';
import express from 'express';
import request from 'supertest';

// ── Mocks ─────────────────────────────────────────────────────────────────────

vi.mock('../../src/db', () => ({
  prismaRead: {
    reputationProfile: { findMany: vi.fn() },
  },
  prismaWrite: {},
}));

vi.mock('../../src/cache', () => ({
  cacheGet: vi.fn(),
  cacheSet: vi.fn(),
}));

vi.mock('../../src/indexer/arbitrage-engine', () => ({
  buildPriceGraph: vi.fn(),
  detectNegativeCycles: vi.fn(),
  simulateExecution: vi.fn(),
  simulateCustomRoute: vi.fn(),
  getMarketAnalytics: vi.fn(),
  inferBotStrategy: vi.fn(),
  replayBlock: vi.fn(),
  expireStaleOpportunities: vi.fn(),
}));

vi.mock('../../src/reputation/score', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../src/reputation/score')>();
  return { ...actual, fetchProfileData: vi.fn() };
});

import { oracleFeedsRouter } from '../../src/api/oracle-feeds';
import { arbitrageRouter } from '../../src/api/arbitrage';
import { dataMarketRouter } from '../../src/api/data-market';
import { reputationRouter } from '../../src/api/reputation';
import { prismaRead } from '../../src/db';
import { fetchProfileData } from '../../src/reputation/score';

function mount(router: express.Router, base: string) {
  const app = express();
  app.use(express.json());
  app.use(base, router);
  return app;
}

const ORIGINAL_MOCK_DATA = process.env.MOCK_DATA;

afterEach(() => {
  if (ORIGINAL_MOCK_DATA === undefined) delete process.env.MOCK_DATA;
  else process.env.MOCK_DATA = ORIGINAL_MOCK_DATA;
  vi.clearAllMocks();
});

describe('oracle-feeds price (Issue #7)', () => {
  it('blocks the fabricated price by default', async () => {
    delete process.env.MOCK_DATA;
    const app = mount(oracleFeedsRouter, '/oracle-feeds');

    const res = await request(app).get('/oracle-feeds/assets/XLM-USD/price');

    expect(res.status).toBe(404);
    expect(res.body.mock).toBe(true);
    expect(res.body.price).toBeUndefined();
  });

  it('returns a labeled demo price when MOCK_DATA=true', async () => {
    process.env.MOCK_DATA = 'true';
    const app = mount(oracleFeedsRouter, '/oracle-feeds');

    const res = await request(app).get('/oracle-feeds/assets/XLM-USD/price');

    expect(res.status).toBe(200);
    expect(res.body.mock).toBe(true);
    expect(res.body.price).toBe(0.12);
  });
});

describe('arbitrage cross-chain + bot demo (Issue #7)', () => {
  it('blocks demo cross-chain opportunities by default', async () => {
    delete process.env.MOCK_DATA;
    const app = mount(arbitrageRouter, '/arbitrage');

    const res = await request(app).get('/arbitrage/cross-chain/opportunities');

    expect(res.status).toBe(404);
    expect(res.body.mock).toBe(true);
  });

  it('returns labeled demo cross-chain opportunities when enabled', async () => {
    process.env.MOCK_DATA = 'true';
    const app = mount(arbitrageRouter, '/arbitrage');

    const res = await request(app).get('/arbitrage/cross-chain/opportunities');

    expect(res.status).toBe(200);
    expect(res.body.mock).toBe(true);
    expect(Array.isArray(res.body.opportunities)).toBe(true);
  });

  it('blocks simulated bot deployment by default', async () => {
    delete process.env.MOCK_DATA;
    const app = mount(arbitrageRouter, '/arbitrage');

    const res = await request(app)
      .post('/arbitrage/bot/deploy')
      .send({ maxCapital: 1000, targetPairs: ['XLM/USD'] });

    expect(res.status).toBe(404);
    expect(res.body.mock).toBe(true);
  });

  it('deploys a labeled simulated bot when MOCK_DATA=true', async () => {
    process.env.MOCK_DATA = 'true';
    const app = mount(arbitrageRouter, '/arbitrage');

    const res = await request(app)
      .post('/arbitrage/bot/deploy')
      .send({ maxCapital: 1000, targetPairs: ['XLM/USD'] });

    expect(res.status).toBe(201);
    expect(res.body.mock).toBe(true);
    expect(typeof res.body.address).toBe('string');
  });
});

describe('data-market synthetic price history (Issue #7)', () => {
  it('blocks the synthetic time series by default', async () => {
    delete process.env.MOCK_DATA;
    const app = mount(dataMarketRouter, '/data-market');

    const res = await request(app).get('/data-market/prices/history');

    expect(res.status).toBe(404);
    expect(res.body.mock).toBe(true);
  });

  it('returns a labeled synthetic series when MOCK_DATA=true', async () => {
    process.env.MOCK_DATA = 'true';
    const app = mount(dataMarketRouter, '/data-market');

    const res = await request(app).get('/data-market/prices/history?days=3');

    expect(res.status).toBe(200);
    expect(res.body.mock).toBe(true);
    expect(res.body.history).toHaveLength(3);
  });
});

describe('reputation leaderboard uses real per-address data (Issue #7)', () => {
  it('derives the leaderboard from fetchProfileData instead of fabricated constants', async () => {
    (prismaRead.reputationProfile.findMany as ReturnType<typeof vi.fn>).mockResolvedValue([
      { address: 'GADDRHIGH', chain: 'stellar', combinedScore: 500 },
      { address: 'GADDRLOW', chain: 'stellar', combinedScore: 100 },
    ]);

    (fetchProfileData as ReturnType<typeof vi.fn>).mockImplementation(async (address: string) => {
      if (address === 'GADDRHIGH') {
        return [
          {
            chainId: 'stellar',
            address,
            transactionCount: 900,
            successfulTransactionCount: 890,
            sybilRisk: 0.05,
          },
        ];
      }
      return [
        {
          chainId: 'stellar',
          address,
          transactionCount: 3,
          successfulTransactionCount: 1,
          sybilRisk: 0.9,
        },
      ];
    });

    const app = mount(reputationRouter, '/reputation');
    const res = await request(app).get('/reputation/leaderboard');

    expect(res.status).toBe(200);
    // Real per-address activity was fetched for every profile — no hardcoded
    // constant chain data stands in for it anymore.
    expect(fetchProfileData).toHaveBeenCalledWith('GADDRHIGH');
    expect(fetchProfileData).toHaveBeenCalledWith('GADDRLOW');
    expect(res.body.leaderboard[0].address).toBe('GADDRHIGH');
  });
});
