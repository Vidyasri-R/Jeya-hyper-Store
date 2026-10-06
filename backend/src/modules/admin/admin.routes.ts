import express, { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';
import { AppError } from '../../common/errors';
import { requireAdmin, requireStaff, staffOf } from '../../common/staff-auth.middleware';
import { parseBody, parseParams, parseQuery } from '../../common/validate';
import { optionalPhone, username } from '../staff/staff.schemas';
import { backupService } from '../backup/backup.service';
import { catalogSyncService } from '../sync/catalog-sync.service';
import { usageService } from '../usage/usage.service';
import { adminBannersService } from './admin-banners';
import { adminDashboardService } from './admin-dashboard.service';
import { adminProductsService } from './admin-products.service';
import { adminSettingsService } from './admin-settings.service';
import { adminStaffService } from './admin-staff.service';

/** Back office for the Jeya Staff app — staff/admin accounts only (customer tokens are rejected). */
export const adminRouter = Router();
adminRouter.use(requireStaff, requireAdmin);

const uuidParams = z.object({ id: z.uuid('Invalid id') });
const productParams = z.object({ id: z.coerce.number().int().positive() });

/* ── staff accounts ── */

const role = z.enum(['staff', 'admin']);
const name = z.string().trim().min(2).max(120);

adminRouter.get('/staff', async (_req, res) => {
  res.json({ staff: await adminStaffService.list() });
});

adminRouter.post('/staff', async (req, res) => {
  const input = parseBody(z.object({ username, name, phone: optionalPhone, role: role.default('staff') }).strict(), req);
  res.status(201).json(await adminStaffService.create(staffOf(req).staffId, input));
});

adminRouter.patch('/staff/:id', async (req, res) => {
  const { id } = parseParams(uuidParams, req);
  const patch = parseBody(z.object({ name: name.optional(), phone: optionalPhone, role: role.optional(), isActive: z.boolean().optional() }).strict(), req);
  res.json({ staff: await adminStaffService.update(staffOf(req).staffId, id, patch) });
});

adminRouter.post('/staff/:id/reset-password', async (req, res) => {
  const { id } = parseParams(uuidParams, req);
  res.json(await adminStaffService.resetPassword(staffOf(req).staffId, id));
});

/* ── store settings ── */

adminRouter.get('/settings', async (_req, res) => {
  res.json({ settings: await adminSettingsService.all() });
});

adminRouter.put('/settings/:key', async (req, res) => {
  const { key } = parseParams(z.object({ key: z.string().min(3).max(64) }), req);
  const { value } = parseBody(z.object({ value: z.unknown() }).strict(), req);
  res.json({ key, value: await adminSettingsService.set(key, value) });
});

/* ── product photos & store-owned product fields ── */

adminRouter.get('/products', async (req, res) => {
  const query = parseQuery(
    z.object({
      q: z.string().trim().max(80).optional(),
      filter: z.enum(['all', 'no_image', 'with_image', 'inactive']).default('all'),
      cursor: z.string().max(400).optional(),
      limit: z.coerce.number().int().min(1).max(50).default(30),
    }),
    req,
  );
  res.json(await adminProductsService.list(query));
});

adminRouter.patch('/products/:id', async (req, res) => {
  const { id } = parseParams(productParams, req);
  const patch = parseBody(
    z
      .object({
        nameTa: z.string().trim().max(255).nullable().optional().transform((value) => (value === '' ? null : value)),
        description: z.string().trim().max(2000).nullable().optional().transform((value) => (value === '' ? null : value)),
        sortRank: z.number().int().min(0).max(1000).optional(),
        safetyStock: z.union([z.string(), z.number()]).transform(String).refine((value) => /^\d{1,6}(\.\d{1,3})?$/.test(value), 'Invalid quantity').optional(),
      })
      .strict(),
    req,
  );
  res.json({ product: await adminProductsService.update(id, patch) });
});

/** Upload throttle: one admin phone/laptop doing a photo session is ~1 photo / few seconds. */
const uploadLimiter = rateLimit({
  windowMs: 60_000,
  limit: 30,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: (_req, _res, next) => next(new AppError('RATE_LIMITED', 'Too many uploads at once. Wait a moment.', { retryAfterSec: 30 })),
});

/** Body = the image bytes (Content-Type image/jpeg|png|webp). The app downsizes before sending. */
adminRouter.put(
  '/products/:id/image',
  uploadLimiter,
  express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '8mb' }),
  async (req, res) => {
    const { id } = parseParams(productParams, req);
    if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
      throw new AppError('BAD_REQUEST', 'Send the photo as the request body (JPG, PNG or WebP)', { reason: 'image_missing' });
    }
    res.json(await adminProductsService.setImage(id, req.body));
  },
);

/** Body = the banner image bytes; cropped to 2:1 and stored on R2. Saved into a banner via PUT /settings/home.banners. */
adminRouter.put('/banners/image', uploadLimiter, express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '8mb' }), async (req, res) => {
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    throw new AppError('BAD_REQUEST', 'Send the image as the request body (JPG, PNG or WebP)', { reason: 'image_missing' });
  }
  res.json(await adminBannersService.uploadImage(req.body));
});

adminRouter.delete('/products/:id/image', async (req, res) => {
  const { id } = parseParams(productParams, req);
  await adminProductsService.removeImage(id);
  res.status(204).end();
});

/* ── sales dashboard ── */

adminRouter.get('/dashboard', async (req, res) => {
  const { days } = parseQuery(z.object({ days: z.coerce.number().int().refine((d) => [1, 7, 30, 90].includes(d), 'days must be 1, 7, 30 or 90').default(7) }), req);
  res.json(await adminDashboardService.summary(days));
});

/* ── usage & bills (free-tier budget monitor) ── */

adminRouter.get('/usage', async (_req, res) => {
  res.json(await usageService.report());
});

/** Re-measure now (sizes + alerts) instead of waiting for the hourly run. */
adminRouter.post('/usage/refresh', async (_req, res) => {
  await usageService.sampleDatabaseSize();
  await usageService.sampleR2().catch(() => undefined);
  await usageService.evaluate();
  res.json(await usageService.report());
});

adminRouter.get('/alerts', async (_req, res) => {
  res.json({ alerts: await usageService.recentAlerts() });
});

adminRouter.post('/alerts/:id/ack', async (req, res) => {
  const { id } = parseParams(z.object({ id: z.coerce.number().int().positive() }), req);
  if (!(await usageService.acknowledge(id, staffOf(req).staffId))) throw AppError.notFound('Alert');
  res.status(204).end();
});

/* ── database backups (private R2 bucket) ── */

adminRouter.get('/backups', async (_req, res) => {
  const status = await backupService.status();
  const sets = status.configured ? await backupService.listSets().catch(() => []) : [];
  res.json({ ...status, sets: sets.slice(0, 20) });
});

/** Back up now (e.g. right after fixing the R2 key). Full on the first run of a month. */
adminRouter.post('/backups/run', async (_req, res) => {
  const result = await backupService.run('auto');
  res.status(result.status === 'skipped' ? 409 : 200).json({ result, status: await backupService.status() });
});

/* ── POS catalogue sync ── */

const runSyncSchema = z.object({ mode: z.enum(['delta', 'full']).default('delta') });

/** Manual trigger (e.g. after a big price change in the POS). Waits for completion. */
adminRouter.post('/sync/catalog', async (req, res) => {
  const { mode } = parseBody(runSyncSchema, req);
  const result = await catalogSyncService.run(mode);
  res.status(result.status === 'skipped' ? 409 : 200).json({ result });
});

adminRouter.get('/sync/status', async (_req, res) => {
  res.json({ sync: await catalogSyncService.status() });
});
