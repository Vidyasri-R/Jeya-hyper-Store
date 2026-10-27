import { shopTvService } from '../shop-tv/shop-tv.service';
import express, { Router, type Request } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';
import { AppError } from '../../common/errors';
import { requireStaff, requireStaffAllowingPasswordChange, requireStaffRole, staffOf } from '../../common/staff-auth.middleware';
import { parseBody, parseParams, parseQuery, wantsCleanUp } from '../../common/validate';
import { orderStatus } from '../../db/schema';
import { adminProductsService } from '../admin/admin-products.service';
import { LEADERBOARD_PERIODS, photoWorkService, selfAssignSetting } from '../admin/photo-work.service';
import { usageService } from '../usage/usage.service';
import { changePasswordSchema, staffLoginSchema, staffRefreshSchema } from './staff.schemas';
import { staffAuthService } from './staff-auth.service';
import { STAFF_TABS, staffOrdersService, type StaffTab } from './staff-orders.service';
import { orderAlerts } from './order-alerts.service';

const context = (req: Request) => ({ ipAddress: req.ip ?? null });

/** Per-IP guard in front of the per-account lockout. */
const loginLimiter = rateLimit({
  windowMs: 15 * 60_000,
  limit: 30,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: (_req, _res, next) => next(new AppError('RATE_LIMITED', 'Too many login attempts. Try again in a few minutes.', { retryAfterSec: 900 })),
});

export const staffRouter = Router();

/* ── auth ── */

staffRouter.post('/auth/login', loginLimiter, async (req, res) => {
  const input = parseBody(staffLoginSchema, req);
  res.json(await staffAuthService.login(input, context(req)));
});

staffRouter.post('/auth/refresh', async (req, res) => {
  const { refreshToken } = parseBody(staffRefreshSchema, req);
  res.json(await staffAuthService.refresh(refreshToken));
});

staffRouter.post('/auth/logout', async (req, res) => {
  const { refreshToken } = parseBody(staffRefreshSchema, req);
  await staffAuthService.logout(refreshToken);
  res.status(204).end();
});

/* ── me (reachable before the first password change) ── */

staffRouter.get('/me', requireStaffAllowingPasswordChange, async (req, res) => {
  res.json({ staff: await staffAuthService.me(staffOf(req).staffId) });
});

staffRouter.post('/me/password', requireStaffAllowingPasswordChange, loginLimiter, async (req, res) => {
  const { currentPassword, newPassword } = parseBody(changePasswordSchema, req);
  const deviceInfo = typeof req.headers['x-device-info'] === 'string' ? req.headers['x-device-info'].slice(0, 255) : undefined;
  res.json(await staffAuthService.changePassword(staffOf(req).staffId, currentPassword, newPassword, { ...context(req), ...(deviceInfo ? { deviceInfo } : {}) }));
});

/* ── order board ── */

const tabNames = Object.keys(STAFF_TABS) as [StaffTab, ...StaffTab[]];
const listQuery = z.object({
  tab: z.enum(tabNames).default('new'),
  q: z.string().trim().max(60).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(30),
});
const orderIdParams = z.object({ id: z.uuid('Invalid order id') });
const status = z.enum(orderStatus.enumValues);
const quantity = z
  .union([z.string().trim(), z.number()])
  .transform((value) => String(value))
  .refine((value) => /^\d{1,7}(\.\d{1,3})?$/.test(value), 'Invalid quantity');
const amount = z
  .union([z.string().trim(), z.number()])
  .transform((value) => String(value))
  .refine((value) => /^\d{1,8}(\.\d{1,2})?$/.test(value), 'Invalid amount');

const advanceSchema = z
  .object({
    from: status,
    to: status,
    note: z.string().trim().min(2).max(300).optional(),
    packedItems: z.array(z.object({ productId: z.number().int().positive(), packedQuantity: quantity }).strict()).max(200).optional(),
    codCollectedAmount: amount.optional(),
  })
  .strict();
const cancelSchema = z.object({ from: status, reason: z.string().trim().min(3).max(200) }).strict();

const staffOrders = Router();
// Photo helpers never see orders or customer details.
staffOrders.use(requireStaff, requireStaffRole('staff', 'admin'));

staffOrders.get('/summary', async (req, res) => {
  const summary = await staffOrdersService.summary();
  // Admins see open budget/health alerts on the board too.
  const alerts = staffOf(req).role === 'admin' ? await usageService.openAlertSummary() : null;
  res.json({ ...summary, alerts });
});

staffOrders.get('/', async (req, res) => {
  res.json(await staffOrdersService.list(parseQuery(listQuery, req)));
});

staffOrders.get('/:id', async (req, res) => {
  const { id } = parseParams(orderIdParams, req);
  res.json({ order: await staffOrdersService.detail(id, staffOf(req).role) });
});

staffOrders.post('/:id/advance', async (req, res) => {
  const { id } = parseParams(orderIdParams, req);
  const input = parseBody(advanceSchema, req);
  await staffOrdersService.advance(id, staffOf(req).staffId, input);
  res.json({ order: await staffOrdersService.detail(id, staffOf(req).role) });
});

staffOrders.post('/:id/cancel', async (req, res) => {
  const { id } = parseParams(orderIdParams, req);
  const input = parseBody(cancelSchema, req);
  await staffOrdersService.cancel(id, staffOf(req).staffId, input);
  res.json({ order: await staffOrdersService.detail(id, staffOf(req).role) });
});

staffRouter.use('/orders', staffOrders);

/* ── new-order alerts when the app is closed ── */

/** Android background service: asks about once every 20 s per phone. */
const alertPollLimiter = rateLimit({
  windowMs: 60_000,
  limit: 30,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: (_req, _res, next) => next(new AppError('RATE_LIMITED', 'Too many requests', { retryAfterSec: 60 })),
});

// Device key instead of a login: the phone's background service has no session, and the answer
// holds only order numbers and totals.
staffRouter.get('/alerts/new-orders', alertPollLimiter, async (req, res) => {
  const key = req.get('x-device-key')?.trim();
  if (!key || key.length > 100) throw new AppError('UNAUTHORIZED', 'Device key missing', { reason: 'alert_device_unknown' });
  const { after } = parseQuery(z.object({ after: z.iso.datetime({ offset: true }).optional() }), req);
  res.set('Cache-Control', 'no-store');
  res.json(await orderAlerts.newOrdersFor(key, after ? new Date(after) : undefined));
});

const staffAlerts = Router();
staffAlerts.use(requireStaff, requireStaffRole('staff', 'admin'));

staffAlerts.get('/web-push', async (_req, res) => {
  res.json({ publicKey: await orderAlerts.webPushKey() });
});

staffAlerts.post('/web-push', async (req, res) => {
  const input = parseBody(
    z
      .object({
        endpoint: z.url().max(1000).refine((u) => u.startsWith('https://'), 'Push address must be https'),
        keys: z.object({ p256dh: z.string().min(20).max(200), auth: z.string().min(8).max(100) }),
        label: z.string().trim().max(160).optional(),
      })
      .strict(),
    req,
  );
  await orderAlerts.saveWebPush(staffOf(req).staffId, { endpoint: input.endpoint, ...input.keys, label: input.label });
  res.status(204).end();
});

staffAlerts.post('/web-push/remove', async (req, res) => {
  const { endpoint } = parseBody(z.object({ endpoint: z.string().max(1000) }).strict(), req);
  await orderAlerts.removeWebPush(staffOf(req).staffId, endpoint);
  res.status(204).end();
});

staffAlerts.post('/android', async (req, res) => {
  const { label } = parseBody(z.object({ label: z.string().trim().max(160).optional() }).strict(), req);
  res.status(201).json({ deviceKey: await orderAlerts.addAndroid(staffOf(req).staffId, label) });
});

// The device key is its own proof (works after signing out too).
staffRouter.post('/alerts/android/remove', alertPollLimiter, async (req, res) => {
  const { deviceKey } = parseBody(z.object({ deviceKey: z.string().trim().min(20).max(100) }).strict(), req);
  await orderAlerts.removeAndroid(deviceKey);
  res.status(204).end();
});

staffRouter.use('/alerts', staffAlerts);

/* ── shop audio: the shop phone plays the ad sound at the TV's ad breaks ── */

staffRouter.get('/shop-audio', requireStaff, requireStaffRole('staff', 'admin'), async (_req, res) => {
  res.set('Cache-Control', 'no-store');
  res.json(await shopTvService.audioState());
});

/* ── photo work (any staff role: their assigned products) ── */

const staffPhotos = Router();
staffPhotos.use(requireStaff);

const photoUploads = rateLimit({
  windowMs: 60_000,
  limit: 30,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: (_req, _res, next) => next(new AppError('RATE_LIMITED', 'Too many uploads at once. Wait a moment.', { retryAfterSec: 30 })),
});

/** My products to photograph, best first, and how many I've done. */
staffPhotos.get('/mine', async (req, res) => {
  const { cursor } = parseQuery(z.object({ cursor: z.string().max(400).optional() }), req);
  const me = staffOf(req).staffId;
  const [queue, summary] = await Promise.all([photoWorkService.queue({ assignee: me, cursor, limit: 30 }), photoWorkService.summary()]);
  const mine = summary.people.find((p) => p.staffId === me);
  const self = await selfAssignSetting();
  res.json({
    ...queue,
    open: mine?.open ?? 0,
    done: mine?.done ?? 0,
    doneToday: mine?.doneToday ?? 0,
    /** "Get N more" when the list is empty (if the admin allows it and products are left). */
    canTakeMore: self.enabled && (mine?.open ?? 0) === 0 && summary.totals.unassigned > 0,
    takeMoreBatch: self.batch,
  });
});

/** My list is done: take the next batch myself (most important first), if the admin allows it. */
staffPhotos.post('/mine/more', async (req, res) => {
  const me = staffOf(req).staffId;
  const self = await selfAssignSetting();
  if (!self.enabled) throw new AppError('FORBIDDEN', 'Ask the store admin to give you more products', { reason: 'self_assign_off' });
  const summary = await photoWorkService.summary();
  const mine = summary.people.find((p) => p.staffId === me);
  if ((mine?.open ?? 0) > 0) throw new AppError('CONFLICT', 'Finish the products in your list first', { reason: 'list_not_done', open: mine?.open });
  res.json(await photoWorkService.assign({ staffId: me, count: self.batch }));
});

/** The photo race: who added the most photos (today / this week / all time). Every staff member sees it. */
staffPhotos.get('/leaderboard', async (req, res) => {
  const { period } = parseQuery(z.object({ period: z.enum(LEADERBOARD_PERIODS).default('week') }), req);
  res.json(await photoWorkService.leaderboard(period, staffOf(req).staffId));
});

/** Photos I added, newest first (to check and replace). */
staffPhotos.get('/mine/done', async (req, res) => {
  const { cursor } = parseQuery(z.object({ cursor: z.string().max(400).optional() }), req);
  res.json(await photoWorkService.done({ staffId: staffOf(req).staffId, cursor, limit: 30 }));
});

staffPhotos.get('/by-barcode/:code', async (req, res) => {
  const { code } = parseParams(z.object({ code: z.string().trim().regex(/^[0-9A-Za-z-]{3,40}$/) }), req);
  const product = await adminProductsService.findByBarcode(code);
  if (!product) throw AppError.notFound('Product');
  res.json({ product });
});

staffPhotos.put('/:id/image', photoUploads, express.raw({ type: ['image/jpeg', 'image/png', 'image/webp'], limit: '8mb' }), async (req, res) => {
  const { id } = parseParams(z.object({ id: z.coerce.number().int().positive() }), req);
  const me = staffOf(req);
  if (!(await photoWorkService.canUpload(id, me.staffId, me.role))) {
    throw new AppError('FORBIDDEN', 'This product is not assigned to you', { reason: 'not_assigned' });
  }
  if (!Buffer.isBuffer(req.body) || req.body.length === 0) {
    throw new AppError('BAD_REQUEST', 'Send the photo as the request body (JPG, PNG or WebP)', { reason: 'image_missing' });
  }
  res.json(await adminProductsService.setImage(id, req.body, me.staffId, wantsCleanUp(req)));
});

/** "The photo is still right" after a barcode change (assigned helpers, or admins). */
staffPhotos.post('/:id/photo-ok', async (req, res) => {
  const { id } = parseParams(z.object({ id: z.coerce.number().int().positive() }), req);
  const me = staffOf(req);
  if (!(await photoWorkService.canUpload(id, me.staffId, me.role))) {
    throw new AppError('FORBIDDEN', 'This product is not assigned to you', { reason: 'not_assigned' });
  }
  await adminProductsService.confirmPhoto(id);
  res.status(204).end();
});

staffRouter.use('/photos', staffPhotos);
