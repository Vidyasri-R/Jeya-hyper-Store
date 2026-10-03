import { Router, type Request } from 'express';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';
import { AppError } from '../../common/errors';
import { requireStaff, requireStaffAllowingPasswordChange, staffOf } from '../../common/staff-auth.middleware';
import { parseBody, parseParams, parseQuery } from '../../common/validate';
import { orderStatus } from '../../db/schema';
import { usageService } from '../usage/usage.service';
import { changePasswordSchema, staffLoginSchema, staffRefreshSchema } from './staff.schemas';
import { staffAuthService } from './staff-auth.service';
import { STAFF_TABS, staffOrdersService, type StaffTab } from './staff-orders.service';

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
staffOrders.use(requireStaff);

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
