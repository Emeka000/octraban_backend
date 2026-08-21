/**
 * OpenTelemetry SDK initialisation.
 * Must be imported BEFORE any other application code (see src/index.ts top).
 *
 * Tracing is **off by default**.  Set TRACING_ENABLED=true (and optionally
 * OTLP_ENDPOINT) to turn it on.  When OTLP_ENDPOINT is set but
 * TRACING_ENABLED is absent the SDK is also started, so existing deployments
 * that configure only the endpoint continue to work without changes.
 *
 * Environment variables
 * ─────────────────────
 * TRACING_ENABLED   – "true" / "1" to start the SDK (default: off)
 * OTLP_ENDPOINT     – OTLP collector base URL (default: http://localhost:4318)
 *                     Setting this variable alone also enables tracing.
 * SERVICE_NAME      – Reported service name (default: "octraban")
 */

import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { Resource } from '@opentelemetry/resources';
import { trace, SpanStatusCode } from '@opentelemetry/api';
import {
  SEMRESATTRS_SERVICE_NAME,
  SEMRESATTRS_SERVICE_VERSION,
} from '@opentelemetry/semantic-conventions';
import { logger } from './logger';

// ---------------------------------------------------------------------------
// Public API — tracer and span helper (always available; no-ops when disabled)
// ---------------------------------------------------------------------------

const SERVICE_NAME_DEFAULT = 'octraban';
const SERVICE_VERSION_DEFAULT = process.env.npm_package_version ?? '1.0.0';

export const tracer = trace.getTracer(
  process.env.SERVICE_NAME ?? SERVICE_NAME_DEFAULT,
  SERVICE_VERSION_DEFAULT,
);

/** Run fn inside a named span; sets ERROR status on throw. */
export async function withSpan<T>(
  name: string,
  fn: (span: ReturnType<typeof tracer.startSpan>) => Promise<T>,
): Promise<T> {
  return tracer.startActiveSpan(name, async (span) => {
    try {
      return await fn(span);
    } catch (err) {
      span.setStatus({ code: SpanStatusCode.ERROR, message: String(err) });
      throw err;
    } finally {
      span.end();
    }
  });
}

export { trace, SpanStatusCode };

// ---------------------------------------------------------------------------
// Gating logic — exported for testing
// ---------------------------------------------------------------------------

/** Returns true when the environment signals that tracing should start. */
export function isTracingEnabled(env: NodeJS.ProcessEnv = process.env): boolean {
  const flag = env.TRACING_ENABLED;
  const endpoint = env.OTLP_ENDPOINT;
  return flag === 'true' || flag === '1' || (endpoint !== undefined && endpoint !== '');
}

// ---------------------------------------------------------------------------
// SDK initialisation
// ---------------------------------------------------------------------------

let _sdk: NodeSDK | null = null;

/**
 * Initialise the OpenTelemetry SDK.  Called once at process startup.
 * Safe to call multiple times — subsequent calls are no-ops.
 *
 * Returns true if the SDK was started successfully, false otherwise.
 */
export function initTracing(env: NodeJS.ProcessEnv = process.env): boolean {
  if (_sdk !== null) return true; // already initialised

  if (!isTracingEnabled(env)) {
    logger.info('OpenTelemetry tracing disabled (set TRACING_ENABLED=true to enable)');
    return false;
  }

  const endpoint = env.OTLP_ENDPOINT ?? 'http://localhost:4318';
  const serviceName = env.SERVICE_NAME ?? SERVICE_NAME_DEFAULT;
  const serviceVersion = env.npm_package_version ?? SERVICE_VERSION_DEFAULT;

  const resource = new Resource({
    [SEMRESATTRS_SERVICE_NAME]: serviceName,
    [SEMRESATTRS_SERVICE_VERSION]: serviceVersion,
  });

  try {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    _sdk = new NodeSDK({
      resource: resource as any, // duplicate @opentelemetry/resources versions in sub-packages
      traceExporter: new OTLPTraceExporter({ url: `${endpoint}/v1/traces` }),
      instrumentations: [
        getNodeAutoInstrumentations({
          '@opentelemetry/instrumentation-fs': { enabled: false },
        }),
      ],
    });

    _sdk.start();
    logger.info('OpenTelemetry tracing started', { endpoint, service: serviceName });
    return true;
  } catch (err) {
    // A startup failure (e.g. bad exporter config) must never crash the process.
    logger.warn('OpenTelemetry SDK failed to start — tracing disabled', {
      error: String(err),
    });
    _sdk = null;
    return false;
  }
}

// ---------------------------------------------------------------------------
// Graceful shutdown — flush spans on SIGTERM and SIGINT
// ---------------------------------------------------------------------------

async function shutdownTracing(): Promise<void> {
  if (!_sdk) return;
  try {
    await _sdk.shutdown();
    logger.info('OpenTelemetry SDK shut down cleanly');
  } catch (err) {
    logger.warn('OpenTelemetry SDK shutdown error (spans may be incomplete)', {
      error: String(err),
    });
  }
}

process.on('SIGTERM', () => void shutdownTracing());
process.on('SIGINT', () => void shutdownTracing());

// ---------------------------------------------------------------------------
// Auto-start at import time (production path) — reads process.env
// ---------------------------------------------------------------------------

initTracing();
