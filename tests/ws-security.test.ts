/**
 * WebSocket security tests
 *
 * Covers the three acceptance criteria from the issue:
 *   1. Unauthenticated / disallowed-origin connections are rejected.
 *   2. Connection and subscription caps are enforced.
 *   3. An authenticated connection receives filtered events.
 *
 * The tests mock the authentication layer and the config module so the
 * broadcaster can be exercised in isolation without a real database.
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { createServer, type Server } from 'node:http';
import { AddressInfo } from 'node:net';
import { WebSocket } from 'ws';

// ─── Close-code constants ─────────────────────────────────────────────────────
const WS_CLOSE_UNAUTHORIZED = 4401;
const WS_CLOSE_FORBIDDEN = 4403;
const WS_CLOSE_LIMIT_EXCEEDED = 4429;

// WsAuthError used in mock implementations
class WsAuthError extends Error {
  constructor(
    public readonly code: number,
    public readonly reason: string,
  ) {
    super(reason);
    this.name = 'WsAuthError';
  }
}

// ─── Mocks ────────────────────────────────────────────────────────────────────

// Mock wsAuth entirely — avoids importing db.ts / prisma at module evaluation time.
vi.mock('../src/middleware/wsAuth', () => {
  const WsAuthErrorImpl = class extends Error {
    constructor(
      public readonly code: number,
      public readonly reason: string,
    ) {
      super(reason);
      this.name = 'WsAuthError';
    }
  };

  return {
    WS_CLOSE_UNAUTHORIZED: 4401,
    WS_CLOSE_FORBIDDEN: 4403,
    WS_CLOSE_LIMIT_EXCEEDED: 4429,
    WsAuthError: WsAuthErrorImpl,
    authenticate: vi.fn().mockResolvedValue({ identity: 'apikey:test-key', method: 'apikey' }),
    validateOrigin: vi.fn(), // no-op by default (allows all)
  };
});

// Mock config with tight caps for testing
vi.mock('../src/config', () => ({
  config: {
    wsAllowedOrigins: '',
    wsMaxConnectionsGlobal: 3,
    wsMaxConnectionsPerIp: 2,
    wsMaxFiltersPerConnection: 2,
    wsHeartbeatIntervalMs: 60_000,
    wsIdleTimeoutMs: 120_000,
  },
}));

// ─── Imports (after mocks) ────────────────────────────────────────────────────

const wsAuthModule = await import('../src/middleware/wsAuth');
const { authenticate, validateOrigin } = wsAuthModule;

import {
  attachWebSocketServer,
  broadcastEvent,
  shutdownWebSocketServer,
  connectedClientCount,
} from '../src/ws/eventBroadcaster';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const servers: Server[] = [];

async function createTestServer(): Promise<{ server: Server; port: number }> {
  const server = createServer();
  attachWebSocketServer(server);
  servers.push(server);
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = (server.address() as AddressInfo).port;
  return { server, port };
}

/**
 * Opens a WebSocket and waits for the `open` event.
 */
function wsConnect(port: number, path = '/ws/events', params = ''): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}${path}${params}`);
    ws.once('open', () => resolve(ws));
    ws.once('error', reject);
  });
}

/**
 * Opens a WebSocket and returns the close code when it closes.
 * Works whether the connection opens and then closes (4xxx after handshake)
 * or whether the connection is refused at the TCP level (1006).
 *
 * For our implementation, rejected sockets complete the handshake and then
 * send a 4xxx close frame, so the socket will open then immediately close.
 */
function openAndWaitForClose(
  port: number,
  params = '',
): Promise<{ code: number; reason: string }> {
  return new Promise((resolve) => {
    const ws = new WebSocket(`ws://127.0.0.1:${port}/ws/events${params}`);
    ws.once('close', (code, reason) => resolve({ code, reason: reason.toString() }));
    ws.once('error', (err) => {
      // Some rejections emit an error before close; suppress and wait for close.
      ws.once('close', (code, reason) => resolve({ code, reason: reason.toString() }));
    });
  });
}

afterEach(async () => {
  shutdownWebSocketServer();
  await Promise.all(
    servers.splice(0).map(
      (s) => new Promise<void>((resolve) => s.close(() => resolve())),
    ),
  );
  vi.clearAllMocks();
  // Re-apply default mocks after clearAllMocks
  vi.mocked(authenticate).mockResolvedValue({ identity: 'apikey:test-key', method: 'apikey' });
  vi.mocked(validateOrigin).mockImplementation(() => {});
});

// ─── Test suite ──────────────────────────────────────────────────────────────

// ── Acceptance criterion 1: unauthenticated / disallowed-origin connections rejected ──

describe('WebSocket security — authentication', () => {
  it('rejects a connection with no credentials (close code 4401)', async () => {
    const { port } = await createTestServer();

    vi.mocked(authenticate).mockRejectedValueOnce(
      new WsAuthError(WS_CLOSE_UNAUTHORIZED, 'Authentication required'),
    );

    const result = await openAndWaitForClose(port);
    expect(result.code).toBe(WS_CLOSE_UNAUTHORIZED);
  });

  it('rejects a connection with an invalid API key (close code 4401)', async () => {
    const { port } = await createTestServer();

    vi.mocked(authenticate).mockRejectedValueOnce(
      new WsAuthError(WS_CLOSE_UNAUTHORIZED, 'Invalid or revoked API key'),
    );

    const result = await openAndWaitForClose(port, '?token=bad-key');
    expect(result.code).toBe(WS_CLOSE_UNAUTHORIZED);
  });

  it('rejects a connection from a disallowed origin (close code 4403)', async () => {
    const { port } = await createTestServer();

    vi.mocked(validateOrigin).mockImplementationOnce(() => {
      throw new WsAuthError(WS_CLOSE_FORBIDDEN, 'Origin not allowed');
    });

    const result = await openAndWaitForClose(port);
    expect(result.code).toBe(WS_CLOSE_FORBIDDEN);
  });

  it('accepts a connection with a valid API key', async () => {
    const { port } = await createTestServer();

    vi.mocked(authenticate).mockResolvedValueOnce({
      identity: 'apikey:valid-key',
      method: 'apikey',
    });

    const ws = await wsConnect(port, '/ws/events', '?token=valid-key');
    expect(ws.readyState).toBe(WebSocket.OPEN);
    ws.close();
  });

  it('accepts a connection with a valid JWT Bearer token', async () => {
    const { port } = await createTestServer();

    vi.mocked(authenticate).mockResolvedValueOnce({
      identity: 'jwt:user-123',
      method: 'jwt',
    });

    const ws = await wsConnect(port, '/ws/events', '?token=Bearer%20valid-jwt');
    expect(ws.readyState).toBe(WebSocket.OPEN);
    ws.close();
  });
});

// ── Acceptance criterion 2: connection and subscription caps are enforced ──

describe('WebSocket security — connection caps', () => {
  beforeEach(() => {
    vi.mocked(authenticate).mockResolvedValue({ identity: 'apikey:test', method: 'apikey' });
  });

  it('rejects a connection when global cap is reached (close code 4429)', async () => {
    const { port } = await createTestServer();

    // Config mock sets wsMaxConnectionsGlobal = 3
    const ws1 = await wsConnect(port);
    const ws2 = await wsConnect(port);
    const ws3 = await wsConnect(port);

    // 4th connection must be rejected with 4429
    const result = await openAndWaitForClose(port);
    expect(result.code).toBe(WS_CLOSE_LIMIT_EXCEEDED);

    ws1.close();
    ws2.close();
    ws3.close();
  });

  it('rejects a connection when per-IP cap is reached (close code 4429)', async () => {
    const { port } = await createTestServer();

    // Config mock sets wsMaxConnectionsPerIp = 2
    const ws1 = await wsConnect(port);
    const ws2 = await wsConnect(port);

    // 3rd connection from same IP is rejected
    const result = await openAndWaitForClose(port);
    expect(result.code).toBe(WS_CLOSE_LIMIT_EXCEEDED);

    ws1.close();
    ws2.close();
  });

  it('rejects a connection when filter cap per connection is exceeded (close code 4429)', async () => {
    const { port } = await createTestServer();
    const { config } = await import('../src/config');

    // Temporarily lower the cap to 1 so 2 filters exceed it
    const original = config.wsMaxFiltersPerConnection;
    (config as { wsMaxFiltersPerConnection: number }).wsMaxFiltersPerConnection = 1;

    try {
      const result = await openAndWaitForClose(port, '?contract=C123&eventType=token_transfer');
      expect(result.code).toBe(WS_CLOSE_LIMIT_EXCEEDED);
    } finally {
      (config as { wsMaxFiltersPerConnection: number }).wsMaxFiltersPerConnection = original;
    }
  });

  it('tracks connection count accurately after disconnects', async () => {
    const { port } = await createTestServer();

    const ws1 = await wsConnect(port);
    const ws2 = await wsConnect(port);
    expect(connectedClientCount()).toBe(2);

    await new Promise<void>((resolve) => {
      ws1.once('close', resolve);
      ws1.close();
    });

    // Give event loop time to process the close handler in the broadcaster
    await new Promise((r) => setTimeout(r, 50));
    expect(connectedClientCount()).toBe(1);

    ws2.close();
  });
});

// ── Acceptance criterion 3: authenticated connection receives filtered events ──

describe('WebSocket security — authenticated + filtered event delivery', () => {
  beforeEach(() => {
    vi.mocked(authenticate).mockResolvedValue({ identity: 'apikey:valid-key', method: 'apikey' });
  });

  it('delivers matching events to an authenticated client', async () => {
    const { port } = await createTestServer();
    const ws = await wsConnect(port, '/ws/events', '?contract=C123&eventType=token_transfer');

    const messages: string[] = [];
    ws.on('message', (data) => messages.push(String(data)));

    broadcastEvent({
      id: 'evt-match',
      contractAddress: 'C123',
      eventType: 'token_transfer',
      decoded: { amount: 100 },
      ledger: 500,
      ledgerCloseTime: new Date('2024-01-01T00:00:00.000Z'),
      transactionHash: 'tx-match',
    });

    await new Promise((r) => setTimeout(r, 100));

    expect(messages).toHaveLength(1);
    const parsed = JSON.parse(messages[0]);
    expect(parsed.type).toBe('event');
    expect(parsed.data.id).toBe('evt-match');

    ws.close();
  });

  it('does not deliver events filtered out by contract address', async () => {
    const { port } = await createTestServer();
    const ws = await wsConnect(port, '/ws/events', '?contract=C123');

    const messages: string[] = [];
    ws.on('message', (data) => messages.push(String(data)));

    broadcastEvent({
      id: 'evt-wrong-contract',
      contractAddress: 'C999',
      eventType: 'token_transfer',
      decoded: {},
      ledger: 501,
      ledgerCloseTime: new Date('2024-01-01T00:00:00.000Z'),
      transactionHash: 'tx-2',
    });

    await new Promise((r) => setTimeout(r, 100));
    expect(messages).toHaveLength(0);

    ws.close();
  });

  it('does not deliver events filtered out by event type', async () => {
    const { port } = await createTestServer();
    const ws = await wsConnect(port, '/ws/events', '?eventType=swap');

    const messages: string[] = [];
    ws.on('message', (data) => messages.push(String(data)));

    broadcastEvent({
      id: 'evt-wrong-type',
      contractAddress: 'C123',
      eventType: 'token_transfer',
      decoded: {},
      ledger: 502,
      ledgerCloseTime: new Date('2024-01-01T00:00:00.000Z'),
      transactionHash: 'tx-3',
    });

    await new Promise((r) => setTimeout(r, 100));
    expect(messages).toHaveLength(0);

    ws.close();
  });

  it('delivers all events to a client with no filters', async () => {
    const { port } = await createTestServer();
    const ws = await wsConnect(port);

    const messages: string[] = [];
    ws.on('message', (data) => messages.push(String(data)));

    broadcastEvent({
      id: 'evt-a',
      contractAddress: 'CA',
      eventType: 'foo',
      decoded: {},
      ledger: 600,
      ledgerCloseTime: new Date(),
      transactionHash: 'tx-a',
    });
    broadcastEvent({
      id: 'evt-b',
      contractAddress: 'CB',
      eventType: 'bar',
      decoded: {},
      ledger: 601,
      ledgerCloseTime: new Date(),
      transactionHash: 'tx-b',
    });

    await new Promise((r) => setTimeout(r, 100));
    expect(messages).toHaveLength(2);

    ws.close();
  });
});
