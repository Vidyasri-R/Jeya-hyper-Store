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
import { WEB_CATEGORIES } from '../catalog-import/category-map';
import { catalogImportService } from '../catalog-import/catalog-import.service';
import { adminBannersService } from './admin-banners';
import { adminCategoriesService } from './admin-categories.service';
import { photoWorkService } from './photo-work.service';
import { adminDashboardService } from './admin-dashboard.service';
import { adminProductsService } from './admin-products.service';
import { adminSettingsService } from './admin-settings.service';
import { adminStaffService } from './admin-staff.service';
import { EXPENSE_CATEGORIES, financeService } from './finance.service';
import { perksService } from '../perks/perks.service';

/** Back office for the Jeya Staff app — staff/admin accounts only (customer tokens are rejected). */
export const adminRouter = Router();
adminRouter.use(requireStaff, requireAdmin);

const uuidParams = z.object({ id: z.uuid('Invalid id') });
const productParams = z.object({ id: z.coerce.number().int().positive() });

/* ── staff accounts ── */

const role = z.enum(['staff', 'admin', 'photos']);
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
        /** Flavours / colours the customer picks from (one POS item); null removes them. */
        options: z
          .object({
            label: z.string().trim().min(2).max(30),
            values: z.array(z.string().trim().min(1).max(40)).min(2, 'Add at least two choices').max(30),
            /** Photo per choice (uploaded with PUT /products/:id/choice-image). */
            images: z.record(z.string().trim().min(1).max(40), z.url().max(500)).optional(),
          })
          .strict()
          .refine((o) => new Set(o.values.map((v) => v.toLowerCase())).size === o.values.length, 'A choice is listed twice')
          .refine((o) => Object.keys(o.images ?? {}).every((k) => o.values.includes(k)), 'A photo belongs to a choice that is not listed')
          .nullable()
          .optional(),
        optionsForAllSizes: z.boolean().optional(),
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
    res.json(await adminProductsService.setImage(id, req.body, staffOf(req).staffId));
  },
);

/** Body = a photo of one choice (a flavour / pen design) — same white-background clean-up as product photos. */
adminRouter.put('/products/:id/choice-image', uploadLimiter, express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '8mb' }), async (req, res) => {
  const { id } = parseParams(productParams, req);
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    throw new AppError('BAD_REQUEST', 'Send the photo as the request body (JPG, PNG or WebP)', { reason: 'image_missing' });
  }
  res.json(await adminProductsService.uploadChoiceImage(id, req.body));
});

/** Body = the banner image bytes; cropped to 2:1 and stored on R2. Saved into a banner via PUT /settings/home.banners. */
adminRouter.put('/banners/image', uploadLimiter, express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '8mb' }), async (req, res) => {
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    throw new AppError('BAD_REQUEST', 'Send the image as the request body (JPG, PNG or WebP)', { reason: 'image_missing' });
  }
  res.json(await adminBannersService.uploadImage(req.body));
});

/* ── shop categories (pictures) and the customer home lists ── */

adminRouter.get('/categories', async (_req, res) => {
  res.json({ categories: await adminCategoriesService.list() });
});

adminRouter.put('/categories/:id/image', uploadLimiter, express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '8mb' }), async (req, res) => {
  const { id } = parseParams(productParams, req);
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    throw new AppError('BAD_REQUEST', 'Send the photo as the request body (JPG, PNG or WebP)', { reason: 'image_missing' });
  }
  res.json(await adminCategoriesService.setImage(id, req.body));
});

adminRouter.delete('/categories/:id/image', async (req, res) => {
  const { id } = parseParams(productParams, req);
  await adminCategoriesService.removeImage(id);
  res.status(204).end();
});

/** The chosen products with details; saved with PUT /settings/home.lists {offers: ids, popular: ids}. */
adminRouter.get('/home-lists', async (_req, res) => {
  res.json(await adminCategoriesService.homeLists());
});

/* ── photo work: who photographs which products ── */

adminRouter.get('/photo-work', async (_req, res) => {
  res.json(await photoWorkService.summary());
});

adminRouter.get('/photo-work/queue', async (req, res) => {
  const q = parseQuery(
    z.object({
      assignee: z.union([z.enum(['any', 'unassigned']), z.uuid()]).default('any'),
      categoryId: z.coerce.number().int().positive().optional(),
      cursor: z.string().max(400).optional(),
      limit: z.coerce.number().int().min(1).max(50).default(30),
    }),
    req,
  );
  res.json(await photoWorkService.queue(q));
});

adminRouter.post('/photo-work/assign', async (req, res) => {
  const body = parseBody(z.object({ staffId: z.uuid(), count: z.number().int().min(1).max(1000), categoryId: z.number().int().positive().optional() }).strict(), req);
  res.json(await photoWorkService.assign(body));
});

adminRouter.post('/photo-work/unassign', async (req, res) => {
  const { staffId } = parseBody(z.object({ staffId: z.uuid() }).strict(), req);
  res.json(await photoWorkService.unassign(staffId));
});

/* ── daily stock file (GoFrugal "Current Stock Detail" CSV) ── */

const stockFile = express.text({ type: ['text/csv', 'text/plain', 'application/vnd.ms-excel', 'application/octet-stream'], limit: '30mb' });
const stockFileBody = (req: express.Request) => {
  if (typeof req.body !== 'string' || req.body.length < 20) {
    throw new AppError('BAD_REQUEST', 'Send the CSV file as the request body', { reason: 'stock_file_missing' });
  }
  return req.body;
};

/** ?apply=true imports; otherwise returns what would change (nothing is written). */
adminRouter.post('/catalog/import', uploadLimiter, stockFile, async (req, res) => {
  const { apply } = parseQuery(z.object({ apply: z.enum(['true', 'false']).default('false') }), req);
  const text = stockFileBody(req);
  const preview = await catalogImportService.preview(text); // before applying, so it describes this import
  if (apply === 'true') res.json({ applied: true, result: await catalogImportService.apply(text), preview });
  else res.json({ applied: false, preview });
});

adminRouter.get('/catalog/import', async (_req, res) => {
  res.json({ last: await catalogImportService.lastImport(), settings: await catalogImportService.settings(), categories: WEB_CATEGORIES });
});

adminRouter.get('/products/by-barcode/:code', async (req, res) => {
  const { code } = parseParams(z.object({ code: z.string().trim().regex(/^[0-9A-Za-z-]{3,40}$/) }), req);
  const product = await adminProductsService.findByBarcode(code);
  if (!product) throw AppError.notFound('Product');
  res.json({ product });
});

adminRouter.delete('/products/:id/image', async (req, res) => {
  const { id } = parseParams(productParams, req);
  await adminProductsService.removeImage(id);
  res.status(204).end();
});

/* ── finance (online shop): sales, costs, margin, expenses, profit ── */

const day = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD');
const range = z
  .object({ from: day, to: day })
  .refine((r) => r.from <= r.to, 'The end date is before the start date')
  .refine((r) => (Date.parse(r.to) - Date.parse(r.from)) / 86_400_000 <= 400, 'Pick at most about a year');

adminRouter.get('/finance', async (req, res) => {
  const { from, to } = parseQuery(range, req);
  res.json(await financeService.report(from, to));
});

adminRouter.get('/expenses', async (req, res) => {
  const { from, to } = parseQuery(range, req);
  res.json({ expenses: await financeService.listExpenses(from, to), categories: EXPENSE_CATEGORIES });
});

adminRouter.post('/expenses', async (req, res) => {
  const body = parseBody(
    z
      .object({
        spentOn: day,
        category: z.enum(EXPENSE_CATEGORIES),
        amount: z.union([z.string(), z.number()]).transform(String).refine((v) => /^\d{1,9}(\.\d{1,2})?$/.test(v) && Number(v) > 0, 'Enter an amount like 450 or 450.50'),
        note: z.string().trim().max(200).nullable().optional(),
      })
      .strict(),
    req,
  );
  res.status(201).json({ expense: await financeService.addExpense(staffOf(req).staffId, body) });
});

adminRouter.delete('/expenses/:id', async (req, res) => {
  const { id } = parseParams(productParams, req);
  await financeService.removeExpense(id);
  res.status(204).end();
});

/* ── premium customers: free delivery and / or a discount, by phone number ── */

adminRouter.get('/members', async (_req, res) => {
  res.json({ members: await perksService.list() });
});

adminRouter.put('/members', async (req, res) => {
  const body = parseBody(
    z
      .object({
        phone: z.string().trim().min(10).max(16),
        name: z.string().trim().max(120).nullable().optional(),
        freeDelivery: z.boolean(),
        discountPercent: z.number().min(0).max(50),
        note: z.string().trim().max(200).nullable().optional(),
        isActive: z.boolean().optional(),
      })
      .strict(),
    req,
  );
  res.json({ member: await perksService.save(staffOf(req).staffId, body) });
});

adminRouter.delete('/members/:phone', async (req, res) => {
  const { phone } = parseParams(z.object({ phone: z.string().regex(/^\d{10,15}$/) }), req);
  await perksService.remove(phone);
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
