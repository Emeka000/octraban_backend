/**
 * WebSocket Authentication & Authorization Middleware
 *
 * Provides a reusable authenticate() function that is called during the HTTP
 * upgrade handshake (before the WebSocket connection is fully established).
 * Supports two credential types, checked in order:
 *
 *   1. API key — passed as the `token` query parameter or the `X-Api-Key`
 *      header value forwarded via the `Sec-WebSocket-Protocol` sub-protocol
 *      field (some browser WS clients cannot set arbitrary headers).
 *   2. Bearer JWT — passed as the `token` query parameter with a "Bearer "
 *      prefix, or via the `Authorization` header on the upgrade request.
 *
 * Returns an {@link WsAuthResult} on success or throws a {@link WsAuthError}
 * whose `code` and `reason` fields are suitable for use as the WebSocket
 * close code and reason string.
 *
 * Callers should reject the upgrade (destroy the socket) when authentication
 * fails; the error's `code` value maps to a registered WebSocket status code:
 *   - 4401 : missing or invalid credentials
 *   - 4403 : origin not in the allowed list
 *   - 4429 : connection or subscription cap exceeded
 */

import crypto from 'crypto';
import { IncomingMessage } from 'http';
import { prismaRead } from '../db';
import { verifyToken } from '../auth/tokens';
import { logger } from '../logger';

// ─── Close codes ─────────────────────────────────────────────────────────────
/** Close code sent when credentials are missing or invalid. */
export const WS_CLOSE_UNAUTHORIZED = 4401;
/** Close code sent when the Origin header is not in the allowlist. */
export const WS_CLOSE_FORBIDDEN = 4403;
/** Close code sent when a connection or subscription cap is exceeded. */
export const WS_CLOSE_LIMIT_EXCEEDED = 4429;

// ─── Error type ──────────────────────────────────────────────────────────────
export class WsAuthError extends Error {
  constructor(
    public readonly code: number,
    public readonly reason: string,
  ) {
    super(reason);
    this.name = 'WsAuthError';
  }
}

// ─── Result type ─────────────────────────────────────────────────────────────
export interface WsAuthResult {
  /** Human-readable identifier attached to log lines. */
  identity: string;
  /** Auth method used — 'apikey' | 'jwt'. */
  method: 'apikey' | 'jwt';
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function sha256(raw: string): string {
  return crypto.createHash('sha256').update(raw).digest('hex');
}

/** Extract the raw API-key credential from an upgrade request. */
function extractApiKey(req: IncomingMessage, url: URL): string | null {
  // 1. ?token=<key> query param
  const qpToken = url.searchParams.get('token');
  if (qpToken && !qpToken.startsWith('Bearer ')) return qpToken;

  // 2. X-Api-Key header on the upgrade request (non-browser clients)
  const header = (req.headers['x-api-key'] ?? '') as string;
  if (header) return header;

  return null;
}

/** Extract a Bearer JWT token string from an upgrade request. */
function extractJwtToken(req: IncomingMessage, url: URL): string | null {
  // 1. Authorization: Bearer <token> header
  const authHeader = (req.headers['authorization'] ?? '') as string;
  if (authHeader.startsWith('Bearer ')) return authHeader.slice(7);

  // 2. ?token=Bearer+<token> query param (URL-encoded space or literal "Bearer ")
  const qpToken = url.searchParams.get('token');
  if (qpToken?.startsWith('Bearer ')) return qpToken.slice(7);

  return null;
}

// ─── Origin allowlist check ──────────────────────────────────────────────────

/**
 * Checks the Origin header against an allowlist.
 *
 * @param req The HTTP upgrade request.
 * @param allowedOrigins Comma-separated list of exact origin URLs.
 *   Pass an empty string to allow all origins (development only).
 */
export function validateOrigin(req: IncomingMessage, allowedOrigins: string): void {
  if (!allowedOrigins) return; // empty = allow all (dev mode)

  const origin = (req.headers['origin'] ?? '') as string;
  if (!origin) {
    // Non-browser clients (curl, server-to-server) do not send Origin.
    // We permit them so programmatic consumers work without configuration.
    return;
  }

  const allowed = allowedOrigins
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  if (!allowed.includes(origin)) {
    logger.warn('[ws-auth] Origin rejected', { origin });
    throw new WsAuthError(WS_CLOSE_FORBIDDEN, 'Origin not allowed');
  }
}

// ─── Authenticate ─────────────────────────────────────────────────────────────

/**
 * Authenticates a WebSocket upgrade request.
 *
 * Resolves on success; throws {@link WsAuthError} on failure.
 */
export async function authenticate(req: IncomingMessage): Promise<WsAuthResult> {
  const url = new URL(req.url ?? '', 'http://localhost');

  // ── Try API key first ────────────────────────────────────────────────────
  const rawKey = extractApiKey(req, url);
  if (rawKey) {
    const hash = sha256(rawKey);
    let record: { id: string; name: string; revokedAt: Date | null; expiresAt: Date | null } | null =
      null;

    try {
      record = await prismaRead.devApiKey.findFirst({
        where: { keyHash: hash, status: 'active' },
        select: { id: true, name: true, revokedAt: true, expiresAt: true },
      });
    } catch (err) {
      logger.error('[ws-auth] DB error during API key lookup', { err });
      throw new WsAuthError(WS_CLOSE_UNAUTHORIZED, 'Authentication service unavailable');
    }

    if (!record || record.revokedAt || (record.expiresAt && record.expiresAt <= new Date())) {
      throw new WsAuthError(WS_CLOSE_UNAUTHORIZED, 'Invalid or revoked API key');
    }

    return { identity: `apikey:${record.id}`, method: 'apikey' };
  }

  // ── Try JWT ─────────────────────────────────────────────────────────────
  const jwtToken = extractJwtToken(req, url);
  if (jwtToken) {
    const payload = await verifyToken(jwtToken);
    if (!payload) {
      throw new WsAuthError(WS_CLOSE_UNAUTHORIZED, 'Invalid or expired token');
    }
    return { identity: `jwt:${payload.userId}`, method: 'jwt' };
  }

  // ── No credentials at all ────────────────────────────────────────────────
  throw new WsAuthError(WS_CLOSE_UNAUTHORIZED, 'Authentication required');
}
