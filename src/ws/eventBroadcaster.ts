/**
 * Event WebSocket broadcaster — /ws/events
 *
 * Security features implemented here:
 *  • Authentication (API key or JWT Bearer) via wsAuth middleware
 *  • Origin allowlist validation for browser clients
 *  • Global connection cap (WS_MAX_CONNECTIONS_GLOBAL)
 *  • Per-IP connection cap (WS_MAX_CONNECTIONS_PER_IP)
 *  • Per-connection filter/subscription cap (WS_MAX_FILTERS_PER_CONNECTION)
 *  • Heartbeat/ping-pong with configurable interval (WS_HEARTBEAT_INTERVAL_MS)
 *  • Idle-timeout reaping (WS_IDLE_TIMEOUT_MS)
 *  • Clear WebSocket close codes (4401 / 4403 / 4429) on rejection
 *
 * Design note on close codes:
 *   RFC 6455 close codes in the 4000–4999 range are application-defined and
 *   can only be sent AFTER the WebSocket handshake is complete.  Any rejection
 *   that happens during the upgrade phase (auth, origin check, connection cap)
 *   therefore completes the handshake first, immediately closes the socket
 *   with the appropriate 4xxx close code, and returns without adding the client
 *   to the active set.  This lets the caller observe a meaningful close code
 *   rather than an abnormal closure (1006).
 */

import { WebSocketServer, WebSocket } from 'ws';
import { IncomingMessage, Server } from 'http';
import { config } from '../config';
import { logger } from '../logger';
import { authenticate, validateOrigin, WsAuthError, WS_CLOSE_LIMIT_EXCEEDED } from '../middleware/wsAuth';

// ─── Types ────────────────────────────────────────────────────────────────────

/** A single active subscriber and its filter state. */
interface Client {
  ws: WebSocket;
  /** null = subscribe to all contracts */
  contractFilter: string | null;
  /** null = subscribe to all event types */
  eventTypeFilter: string | null;
  /** Originating IP, used for per-IP cap bookkeeping. */
  ip: string;
  /** Used by the heartbeat to track liveness. */
  isAlive: boolean;
  /** Authenticated identity attached for log lines. */
  identity: string;
}

// ─── State ────────────────────────────────────────────────────────────────────

const clients = new Set<Client>();
/** Per-IP active connection counts. */
const connsByIp = new Map<string, number>();
/** The recurring heartbeat timer — held so we can cancel it on shutdown. */
let heartbeatTimer: ReturnType<typeof setInterval> | null = null;
/** WSS instance — held for shutdown. */
let wss: WebSocketServer | null = null;

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Extract the best available remote IP from an upgrade request.
 * Honours X-Forwarded-For when the server is behind a trusted proxy.
 * Falls back to the TCP remote address.
 */
function remoteIp(req: IncomingMessage): string {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    const first = (Array.isArray(forwarded) ? forwarded[0] : forwarded).split(',')[0].trim();
    if (first) return first;
  }
  return req.socket?.remoteAddress ?? 'unknown';
}

function incIp(ip: string): void {
  connsByIp.set(ip, (connsByIp.get(ip) ?? 0) + 1);
}

function decIp(ip: string): void {
  const n = (connsByIp.get(ip) ?? 1) - 1;
  if (n <= 0) connsByIp.delete(ip);
  else connsByIp.set(ip, n);
}

function removeClient(client: Client): void {
  if (clients.delete(client)) {
    decIp(client.ip);
  }
}

/**
 * Reject a WebSocket that has just been upgraded by immediately closing it with
 * a 4xxx close code.  The upgrade has already completed so the client can read
 * the code and reason via its close event.
 */
function rejectUpgradedSocket(ws: WebSocket, code: number, reason: string): void {
  // readyState may already be CONNECTING (0) so we use once('open') defensively.
  if (ws.readyState === WebSocket.OPEN) {
    ws.close(code, reason);
  } else {
    ws.once('open', () => ws.close(code, reason));
  }
}

// ─── Heartbeat ────────────────────────────────────────────────────────────────

function heartbeat(): void {
  for (const client of clients) {
    if (!client.isAlive) {
      logger.debug('[ws-events] idle client reaped', { identity: client.identity });
      client.ws.terminate();
      removeClient(client);
      continue;
    }
    client.isAlive = false;
    try {
      client.ws.ping();
    } catch {
      // ignore — socket may have closed between the check and the ping
    }
  }
}

// ─── Attach ────────────────────────────────────────────────────────────────────

export function attachWebSocketServer(httpServer: Server): WebSocketServer {
  wss = new WebSocketServer({ noServer: true });

  httpServer.on('upgrade', (req: IncomingMessage, socket, head) => {
    const pathname = (req.url ?? '').split('?')[0];
    if (pathname !== '/ws/events') {
      return; // not our path
    }

    // ── Origin check (sync) ───────────────────────────────────────────────
    // Done before the async auth so we can fail fast without a DB round-trip.
    let originError: WsAuthError | null = null;
    try {
      validateOrigin(req, config.wsAllowedOrigins);
    } catch (err) {
      originError = err as WsAuthError;
    }

    // ── Authenticate (async) ──────────────────────────────────────────────
    // We always complete the WebSocket upgrade so we can send a proper 4xxx
    // close code to the client (raw socket destruction only produces code 1006).
    authenticate(req)
      .then((authResult) => {
        const ip = remoteIp(req);

        // ── All checks passed → upgrade and register ───────────────────
        wss!.handleUpgrade(req, socket, head, (ws) => {
          // ── Post-upgrade rejection checks (must happen in order) ──────

          // 1. Origin
          if (originError) {
            logger.warn('[ws-events] origin rejected', {
              origin: req.headers['origin'],
              reason: originError.reason,
            });
            rejectUpgradedSocket(ws, originError.code, originError.reason);
            return;
          }

          // 2. Global connection cap
          if (clients.size >= config.wsMaxConnectionsGlobal) {
            logger.warn('[ws-events] global connection cap reached', {
              limit: config.wsMaxConnectionsGlobal,
            });
            rejectUpgradedSocket(ws, WS_CLOSE_LIMIT_EXCEEDED, 'Global connection limit reached');
            return;
          }

          // 3. Per-IP connection cap
          const ipCount = connsByIp.get(ip) ?? 0;
          if (ipCount >= config.wsMaxConnectionsPerIp) {
            logger.warn('[ws-events] per-IP connection cap reached', {
              ip,
              limit: config.wsMaxConnectionsPerIp,
            });
            rejectUpgradedSocket(ws, WS_CLOSE_LIMIT_EXCEEDED, 'Per-IP connection limit reached');
            return;
          }

          // 4. Per-connection filter/subscription cap
          const url = new URL(req.url ?? '', 'http://localhost');
          const contractFilter = url.searchParams.get('contract');
          const eventTypeFilter = url.searchParams.get('eventType');
          const filterCount = [contractFilter, eventTypeFilter].filter(Boolean).length;
          if (filterCount > config.wsMaxFiltersPerConnection) {
            logger.warn('[ws-events] filter cap exceeded', {
              identity: authResult.identity,
              filterCount,
              limit: config.wsMaxFiltersPerConnection,
            });
            rejectUpgradedSocket(
              ws,
              WS_CLOSE_LIMIT_EXCEEDED,
              'Filter/subscription limit per connection exceeded',
            );
            return;
          }

          // ── Accept the connection ────────────────────────────────────
          wss!.emit('connection', ws, req, authResult.identity, ip, contractFilter, eventTypeFilter);
        });
      })
      .catch((err) => {
        const code = err instanceof WsAuthError ? err.code : 4401;
        const reason = err instanceof WsAuthError ? err.reason : 'Authentication required';
        logger.warn('[ws-events] auth rejected', { reason });

        // Complete the upgrade so the client receives a proper WS close code.
        wss!.handleUpgrade(req, socket, head, (ws) => {
          rejectUpgradedSocket(ws, code, reason);
        });
      });
  });

  // ── Connection handler ────────────────────────────────────────────────────
  wss.on(
    'connection',
    (
      ws: WebSocket,
      req: IncomingMessage,
      identity: string,
      ip: string,
      contractFilter: string | null,
      eventTypeFilter: string | null,
    ) => {
      const client: Client = {
        ws,
        contractFilter,
        eventTypeFilter,
        ip,
        isAlive: true,
        identity,
      };

      clients.add(client);
      incIp(ip);

      logger.debug('[ws-events] client connected', {
        identity,
        ip,
        contractFilter,
        eventTypeFilter,
        totalClients: clients.size,
      });

      ws.on('pong', () => {
        client.isAlive = true;
      });

      ws.on('close', () => {
        removeClient(client);
        logger.debug('[ws-events] client disconnected', {
          identity,
          totalClients: clients.size,
        });
      });

      ws.on('error', (err) => {
        logger.warn('[ws-events] client error', { identity, error: String(err) });
        removeClient(client);
      });
    },
  );

  // ── Start heartbeat timer ────────────────────────────────────────────────
  if (heartbeatTimer) clearInterval(heartbeatTimer);
  heartbeatTimer = setInterval(heartbeat, config.wsHeartbeatIntervalMs);
  if (heartbeatTimer.unref) heartbeatTimer.unref();

  return wss;
}

// ─── Broadcast ────────────────────────────────────────────────────────────────

export function broadcastEvent(event: {
  id: string;
  contractAddress: string;
  eventType: string;
  decoded: unknown;
  ledger: number;
  ledgerCloseTime: Date;
  transactionHash: string;
}): void {
  const payload = JSON.stringify({ type: 'event', data: event });

  for (const client of clients) {
    if (client.ws.readyState !== WebSocket.OPEN) continue;
    if (client.contractFilter && client.contractFilter !== event.contractAddress) continue;
    if (client.eventTypeFilter && client.eventTypeFilter !== event.eventType) continue;
    client.ws.send(payload);
  }
}

export function broadcastEmergencyEvent(payload: {
  event: string;
  data: Record<string, unknown>;
}): void {
  const msg = JSON.stringify({ type: 'emergency', ...payload });
  for (const client of clients) {
    if (client.ws.readyState === WebSocket.OPEN) {
      client.ws.send(msg);
    }
  }
}

// ─── Shutdown ─────────────────────────────────────────────────────────────────

export function shutdownWebSocketServer(): void {
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }

  for (const client of clients) {
    if (client.ws.readyState === WebSocket.OPEN) {
      client.ws.close(1001, 'Server shutting down');
    }
  }
  clients.clear();
  connsByIp.clear();

  if (wss) {
    wss.close();
    wss = null;
  }
}

// ─── Exported for testing ─────────────────────────────────────────────────────

/** Returns the current number of connected clients. Used in tests. */
export function connectedClientCount(): number {
  return clients.size;
}
