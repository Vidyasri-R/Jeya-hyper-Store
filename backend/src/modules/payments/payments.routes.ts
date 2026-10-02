import express, { Router } from 'express';
import { z } from 'zod';
import { authOf, requireAuth } from '../../common/auth.middleware';
import { parseBody, parseParams } from '../../common/validate';
import { orderIdParams } from '../orders/orders.schemas';
import { paymentsService } from './payments.service';

/** Mounted under /v1/orders/:id/payment (auth required). */
export const orderPaymentRouter = Router({ mergeParams: true });
orderPaymentRouter.use(requireAuth);

orderPaymentRouter.post('/', async (req, res) => {
  const { id } = parseParams(orderIdParams, req);
  res.json({ payment: await paymentsService.initiate(authOf(req).userId, id) });
});

const confirmSchema = z
  .object({
    razorpayOrderId: z.string().regex(/^order_[A-Za-z0-9]+$/),
    razorpayPaymentId: z.string().regex(/^pay_[A-Za-z0-9]+$/),
    razorpaySignature: z.string().regex(/^[0-9a-f]{64}$/i),
  })
  .strict();

orderPaymentRouter.post('/confirm', async (req, res) => {
  const { id } = parseParams(orderIdParams, req);
  const input = parseBody(confirmSchema, req);
  const result = await paymentsService.confirm(authOf(req).userId, id, input);
  res.status(result.status === 'paid' ? 200 : 202).json(result);
});

/**
 * Razorpay webhook. Mounted in app.ts BEFORE express.json(), because the signature is
 * computed over the exact raw bytes.
 */
export const razorpayWebhookHandler = [
  express.raw({ type: 'application/json', limit: '256kb' }),
  async (req: express.Request, res: express.Response) => {
    const body = Buffer.isBuffer(req.body) ? req.body : Buffer.from('');
    const result = await paymentsService.handleWebhook(
      body,
      req.header('x-razorpay-signature') ?? undefined,
      req.header('x-razorpay-event-id') ?? undefined,
    );
    res.json({ ok: true, ...result });
  },
];
