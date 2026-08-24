import { Request, Response, NextFunction } from 'express';

/**
 * Gates GET /metrics. When METRICS_TOKEN is set, a matching Bearer token or
 * X-Metrics-Token header is required (401 otherwise). Without it, only
 * loopback callers (127.0.0.1/::1) are allowed (403 for anyone else) so the
 * scrape endpoint isn't exposed by default.
 */
export function metricsAuthGuard(req: Request, res: Response, next: NextFunction): void {
  const metricsToken = process.env.METRICS_TOKEN?.trim() || null;

  if (metricsToken) {
    const provided =
      (req.headers['authorization'] as string | undefined)?.replace(/^Bearer\s+/i, '') ||
      (req.headers['x-metrics-token'] as string | undefined) ||
      '';
    if (provided !== metricsToken) {
      res
        .status(401)
        .set('WWW-Authenticate', 'Bearer realm="metrics"')
        .json({ error: 'Unauthorized' });
      return;
    }
    next();
    return;
  }

  const ip = (req.ip ?? '').replace('::ffff:', '');
  if (ip !== '127.0.0.1' && ip !== '::1') {
    res.status(403).json({ error: 'Metrics endpoint requires METRICS_TOKEN for remote access' });
    return;
  }
  next();
}
