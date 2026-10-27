import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';
import { AppError } from '../../common/errors';
import { parseBody, parseParams } from '../../common/validate';
import { shopTvService } from './shop-tv.service';

/** The Jeya TV app: no login, a device key it made on first start (paired once by an admin). */
export const shopTvRouter = Router();

const tvLimiter = rateLimit({
  windowMs: 60_000,
  limit: 60,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: (_req, _res, next) => next(new AppError('RATE_LIMITED', 'Too many requests', { retryAfterSec: 60 })),
});
shopTvRouter.use(tvLimiter);

const deviceKey = z.string().trim().min(32).max(100);

function keyOf(req: { get(name: string): string | undefined }): string {
  const parsed = deviceKey.safeParse(req.get('x-device-key'));
  if (!parsed.success) throw new AppError('UNAUTHORIZED', 'Device key missing', { reason: 'tv_unknown' });
  return parsed.data;
}

shopTvRouter.post('/register', async (req, res) => {
  const { deviceKey: key } = parseBody(z.object({ deviceKey }).strict(), req);
  res.json(await shopTvService.register(key));
});

shopTvRouter.get('/state', async (req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json(await shopTvService.state(keyOf(req)));
});

shopTvRouter.post('/heartbeat', async (req, res) => {
  const { status, appVersion } = parseBody(
    z.object({ status: z.record(z.string(), z.unknown()).refine((v) => JSON.stringify(v).length <= 4000, 'Status too large'), appVersion: z.string().max(20).optional() }).strict(),
    req,
  );
  await shopTvService.heartbeat(keyOf(req), status, appVersion);
  res.status(204).end();
});

shopTvRouter.post('/media/:id/report', async (req, res) => {
  const { id } = parseParams(z.object({ id: z.uuid() }), req);
  const info = parseBody(z.object({ durationMs: z.number().int().min(500).max(6 * 3600_000), aspect: z.number().min(0.1).max(10).nullable() }).strict(), req);
  await shopTvService.reportMedia(keyOf(req), id, info);
  res.status(204).end();
});
