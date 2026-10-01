import { Router } from 'express';
import { authOf, requireAuth } from '../../common/auth.middleware';
import { parseBody, parseParams, parseQuery } from '../../common/validate';
import { cancelOrderSchema, listOrdersQuery, orderIdParams, placeOrderSchema, quoteSchema } from './orders.schemas';
import { ordersService } from './orders.service';

export const checkoutRouter = Router();
checkoutRouter.use(requireAuth);

/** Preview totals + blockers for the checkout screen. Safe to call on every screen open. */
checkoutRouter.post('/quote', async (req, res) => {
  const { addressId } = parseBody(quoteSchema, req);
  res.json({ quote: await ordersService.quote(authOf(req).userId, addressId) });
});

export const ordersRouter = Router();
ordersRouter.use(requireAuth);

ordersRouter.post('/', async (req, res) => {
  const input = parseBody(placeOrderSchema, req);
  const result = await ordersService.placeOrder(authOf(req).userId, input);
  // 201 for a new order, 200 when an idempotent retry returns the existing one.
  res.status(result.created ? 201 : 200).json(result);
});

ordersRouter.get('/', async (req, res) => {
  const { cursor, limit } = parseQuery(listOrdersQuery, req);
  res.json(await ordersService.list(authOf(req).userId, cursor, limit));
});

ordersRouter.get('/:id', async (req, res) => {
  const { id } = parseParams(orderIdParams, req);
  res.json({ order: await ordersService.get(authOf(req).userId, id) });
});

ordersRouter.post('/:id/cancel', async (req, res) => {
  const { id } = parseParams(orderIdParams, req);
  const { reason } = parseBody(cancelOrderSchema, req);
  res.json({ order: await ordersService.cancel(authOf(req).userId, id, reason) });
});
