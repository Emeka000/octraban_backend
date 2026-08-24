import { Response } from 'express';

/**
 * Central switch for endpoints that would otherwise fabricate data because no
 * real upstream integration exists yet (oracle price feeds, cross-chain
 * bridges, ZK-proof verification, simulated bot execution, ...).
 *
 * Off by default so the API never presents synthetic data as if it were real.
 * Set MOCK_DATA=true (ENABLE_EXPERIMENTAL=true is accepted as an alias) to opt
 * in for local development/demos — every response produced while the flag is
 * on is explicitly annotated with `mock: true`.
 */
export function isMockDataEnabled(): boolean {
  return process.env.MOCK_DATA === 'true' || process.env.ENABLE_EXPERIMENTAL === 'true';
}

/** Tags a payload as synthetic so callers can't mistake it for real data. */
export function annotateMock<T extends Record<string, unknown>>(payload: T): T & { mock: true } {
  return { ...payload, mock: true };
}

const DEFAULT_DISABLED_MESSAGE =
  'This endpoint returns synthetic/experimental data and is disabled by default. ' +
  'Set MOCK_DATA=true to enable it; responses will be explicitly marked "mock": true.';

export interface MockGateOptions {
  /** HTTP status to use when mock data is disabled. Default 404. */
  disabledStatus?: number;
  /** Message returned when disabled. */
  disabledMessage?: string;
}

/**
 * Sends `payload` annotated with `mock: true` when MOCK_DATA is enabled, or
 * blocks the response with a clear error when it is not (the default,
 * production-safe posture).
 */
export function sendMockGated(
  res: Response,
  payload: Record<string, unknown>,
  options: MockGateOptions = {},
): Response {
  if (!isMockDataEnabled()) {
    return res.status(options.disabledStatus ?? 404).json({
      error: options.disabledMessage ?? DEFAULT_DISABLED_MESSAGE,
      mock: true,
    });
  }
  return res.json(annotateMock(payload));
}
