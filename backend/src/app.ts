import { randomUUID } from 'node:crypto';
import compression from 'compression';
import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';
import { errorHandler, notFoundHandler } from './common/error-handler';
import { env } from './config/env';
import { logger } from './config/logger';
import { pingDb } from './db/client';
import { traffic } from './infra/traffic';
import { razorpayWebhookHandler } from './modules/payments/payments.routes';
import { v1Router } from './routes';

export function createApp(): Express {
  const app = express();

  // Render terminates TLS at its proxy; needed for correct req.ip (OTP rate limiting).
  app.set('trust proxy', 1);
  app.disable('x-powered-by');
  app.use((_req, _res, next) => {
    traffic.countRequest();
    next();
  });

  app.use(
    pinoHttp({
      logger,
      genReqId: (req, res) => {
        const incoming = req.headers['x-request-id'];
        const id = typeof incoming === 'string' && incoming.length <= 64 ? incoming : randomUUID();
        res.setHeader('x-request-id', id);
        return id;
      },
      autoLogging: { ignore: (req) => req.url?.startsWith('/health') ?? false },
    }),
  );
  app.use(helmet());
  app.use(cors({ origin: env.CORS_ORIGINS.length > 0 ? env.CORS_ORIGINS : false }));
  // Never leave a client hanging: answer "busy, retry" (with the CORS headers already set above)
  // before the apps' own 25 s timeout, which they would otherwise report as "no internet".
  app.use((req, res, next) => {
    // Uploads take longer: photos (resize + R2) and the daily stock file (~9,000 products, ~20-40 s).
    const slow = req.path.endsWith('/image') || req.path.endsWith('/catalog/import');
    res.setTimeout(slow ? 120_000 : 20_000, () => {
      if (res.headersSent) return;
      req.log.error({ path: req.path }, 'request timed out');
      res.status(503).json({ error: { code: 'UPSTREAM_UNAVAILABLE', message: 'The server is busy right now. Please try again.', details: { reason: 'request_timeout' }, requestId: req.id } });
    });
    next();
  });
  app.use(compression());
  // Raw body for signature verification — must be registered before express.json().
  app.post('/v1/webhooks/razorpay', ...razorpayWebhookHandler);
  app.use(express.json({ limit: '100kb' }));

  /** Liveness — process is up. Render health check points here. */
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', uptime: Math.round(process.uptime()) });
  });

  /** Readiness — dependencies reachable. */
  app.get('/health/ready', async (_req, res) => {
    const startedAt = Date.now();
    try {
      await pingDb();
      res.json({ status: 'ok', db: { ok: true, latencyMs: Date.now() - startedAt } });
    } catch (error) {
      logger.error({ err: error }, 'readiness check failed');
      res.status(503).json({ status: 'degraded', db: { ok: false } });
    }
  });

  app.use('/v1', v1Router);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
