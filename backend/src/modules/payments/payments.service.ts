import { eq } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { fromPaise, toPaise } from '../../common/money';
import { logger } from '../../config/logger';
import { db, type Transaction } from '../../db/client';
import { orderItems, orders, users, type Order, type PaymentMethod } from '../../db/schema';
import { razorpay, razorpayConfigured, type RazorpayPayment } from '../../integrations/razorpay/client';
import { ordersRepository } from '../orders/orders.repository';
import { paymentsRepository } from './payments.repository';

/** Extra hold granted when the customer opens the payment sheet (capped from order creation). */
const PAYMENT_SHEET_HOLD_MS = 10 * 60 * 1000;
const MAX_TOTAL_HOLD_MS = 30 * 60 * 1000;

function mapMethod(method: string): PaymentMethod {
  return method === 'upi' || method === 'card' || method === 'netbanking' || method === 'wallet' ? method : 'online';
}

type RefundRequest = { paymentId: string; providerPaymentId: string; amountPaise: number; orderId: string; reason: string };

async function lockOrder(tx: Transaction, orderId: string): Promise<Order> {
  const [row] = await tx.select().from(orders).where(eq(orders.id, orderId)).for('update').limit(1);
  if (!row) throw new Error(`order ${orderId} vanished`);
  return row;
}

/**
 * THE single place a captured payment is applied — used by the app's confirm call,
 * the webhook and the reconciler, in any order and any number of times.
 */
async function applyCaptured(providerOrderId: string, payment: RazorpayPayment): Promise<{ order: Order | null; refund: RefundRequest | null }> {
  const result = await db.transaction(async (tx) => {
    const attempt = await paymentsRepository.lockByProviderOrderId(tx, providerOrderId);
    if (!attempt) {
      logger.error({ providerOrderId, paymentId: payment.id }, 'captured payment for unknown razorpay order');
      return { order: null, refund: null };
    }
    if (attempt.status === 'captured') {
      // Already applied (same payment) — or a second capture on the same gateway order, which Razorpay prevents.
      return { order: await lockOrder(tx, attempt.orderId), refund: null };
    }

    const order = await lockOrder(tx, attempt.orderId);
    const amountOk = payment.amount === toPaise(attempt.amount) && payment.currency === 'INR';
    await paymentsRepository.markCaptured(tx, attempt.id, {
      providerPaymentId: payment.id,
      method: mapMethod(payment.method),
      capturedAt: new Date((payment.created_at ?? Date.now() / 1000) * 1000),
    });

    const refundAll = (reason: string): { order: Order; refund: RefundRequest } => ({
      order,
      refund: { paymentId: attempt.id, providerPaymentId: payment.id, amountPaise: payment.amount, orderId: order.id, reason },
    });

    if (!amountOk) {
      logger.error({ orderId: order.id, expected: attempt.amount, got: payment.amount }, 'payment amount mismatch — refunding');
      return refundAll('Amount mismatch');
    }

    const alreadyPaid = (await paymentsRepository.capturedForOrder(tx, order.id)).some((p) => p.id !== attempt.id);
    if (alreadyPaid) return refundAll('Duplicate payment for an already-paid order');

    if (order.orderStatus === 'pending_payment') {
      const updated = await ordersRepository.updateOrder(tx, order.id, {
        orderStatus: 'placed',
        paymentStatus: 'paid',
        placedAt: new Date(),
        reservationExpiresAt: null,
      });
      await ordersRepository.addHistory(tx, [
        { orderId: order.id, fromStatus: 'pending_payment', toStatus: 'placed', changedBy: null, note: `Paid online (${payment.method})` },
      ]);
      return { order: updated, refund: null };
    }

    if (order.orderStatus === 'payment_failed') {
      // Paid after the hold expired: try to take the stock back; refund if it's gone.
      const items = await tx.select().from(orderItems).where(eq(orderItems.orderId, order.id));
      const short = await ordersRepository.reserve(tx, items.map((item) => ({ productId: item.productId, quantity: item.quantity })));
      if (short.length > 0) {
        await ordersRepository.updateOrder(tx, order.id, { paymentStatus: 'paid' });
        return refundAll('Paid after the payment window; items no longer in stock');
      }
      const updated = await ordersRepository.updateOrder(tx, order.id, {
        orderStatus: 'placed',
        paymentStatus: 'paid',
        gofrugalSyncStatus: 'pending',
        placedAt: new Date(),
      });
      await ordersRepository.addHistory(tx, [
        { orderId: order.id, fromStatus: 'payment_failed', toStatus: 'placed', changedBy: null, note: 'Payment received late; items re-reserved' },
      ]);
      return { order: updated, refund: null };
    }

    // Cancelled (or already beyond placed): keep the money record, give it back.
    await ordersRepository.updateOrder(tx, order.id, { paymentStatus: 'paid' });
    return refundAll(`Payment captured for a ${order.orderStatus} order`);
  });

  if (result.refund) await issueRefund(result.refund);
  return result;
}

/** Idempotent per payment: the refund row is written before the gateway call. */
async function issueRefund(request: RefundRequest): Promise<void> {
  let refund = await paymentsRepository.refundForPayment(db, request.paymentId);
  if (refund && refund.status !== 'pending') return;
  refund ??= await paymentsRepository.insertRefund(db, {
    paymentId: request.paymentId,
    orderId: request.orderId,
    amount: fromPaise(request.amountPaise),
    reason: request.reason,
    status: 'pending',
  });

  try {
    const result = await razorpay.refund(request.providerPaymentId, request.amountPaise, { orderId: request.orderId, reason: request.reason.slice(0, 200) });
    await db.transaction(async (tx) => {
      await paymentsRepository.updateRefund(tx, refund.id, {
        providerRefundId: result.id,
        status: result.status === 'failed' ? 'failed' : 'processed',
      });
      await tx.update(orders).set({ paymentStatus: 'refunded' }).where(eq(orders.id, request.orderId));
    });
    logger.warn({ orderId: request.orderId, amount: fromPaise(request.amountPaise), reason: request.reason }, 'refund issued');
  } catch (error) {
    // Row stays 'pending'; the reconciler retries it.
    logger.error({ err: error, refundId: refund.id, orderId: request.orderId }, 'refund call failed — will retry');
  }
}

export const paymentsService = {
  available: razorpayConfigured,

  /** Start (or resume) payment for a pending online order. Returns what Razorpay Checkout needs. */
  async initiate(userId: string, orderId: string) {
    if (!razorpayConfigured()) throw new AppError('CONFLICT', 'Online payments are not available right now', { reason: 'payment_method_unavailable' });

    const { order, open, phone, name } = await db.transaction(async (tx) => {
      const current = await ordersRepository.lockForUser(tx, userId, orderId);
      if (!current) throw AppError.notFound('Order');
      if (current.paymentMethod !== 'online' || current.orderStatus !== 'pending_payment') {
        throw new AppError('CONFLICT', 'This order is not awaiting online payment', { reason: 'not_payable', status: current.orderStatus });
      }
      const now = Date.now();
      if (!current.reservationExpiresAt || current.reservationExpiresAt.getTime() <= now) {
        throw new AppError('CONFLICT', 'The payment window for this order has expired. Please place the order again.', { reason: 'payment_window_expired' });
      }
      const extended = Math.min(current.createdAt.getTime() + MAX_TOTAL_HOLD_MS, Math.max(current.reservationExpiresAt.getTime(), now + PAYMENT_SHEET_HOLD_MS));
      const updated = await ordersRepository.updateOrder(tx, orderId, { reservationExpiresAt: new Date(extended) });
      const [user] = await tx.select({ phone: users.phone, name: users.name }).from(users).where(eq(users.id, userId)).limit(1);
      return { order: updated!, open: await paymentsRepository.latestOpenAttempt(tx, orderId), phone: user?.phone ?? '', name: user?.name ?? null };
    });

    // Reuse the open gateway order when the amount still matches; otherwise create a new one (outside any DB transaction).
    let providerOrderId = open && open.amount === order.totalAmount ? open.providerOrderId : null;
    if (!providerOrderId) {
      const created = await razorpay.createOrder({
        amountPaise: toPaise(order.totalAmount),
        receipt: order.orderNumber,
        notes: { orderId: order.id, orderNumber: order.orderNumber },
      });
      await paymentsRepository.insertAttempt(db, { orderId: order.id, providerOrderId: created.id, amount: order.totalAmount });
      providerOrderId = created.id;
    }

    return {
      provider: 'razorpay' as const,
      testMode: razorpay.isTestMode(),
      keyId: razorpay.publicKeyId(),
      razorpayOrderId: providerOrderId,
      amount: toPaise(order.totalAmount), // paise, as Razorpay Checkout expects
      currency: 'INR',
      name: 'Jeya Hyper Store',
      description: `Order ${order.orderNumber}`,
      prefill: { contact: phone.startsWith('91') ? `+${phone}` : phone, name },
      expiresAt: order.reservationExpiresAt,
    };
  },

  /** App callback after Checkout success. Signature proves origin; the fetch proves money actually moved. */
  async confirm(userId: string, orderId: string, input: { razorpayOrderId: string; razorpayPaymentId: string; razorpaySignature: string }) {
    const found = await ordersRepository.findForUser(db, userId, orderId);
    if (!found) throw AppError.notFound('Order');
    const attempt = await paymentsRepository.findForOrder(db, orderId, input.razorpayOrderId);
    if (!attempt) throw new AppError('BAD_REQUEST', 'Payment does not belong to this order', { reason: 'payment_mismatch' });
    if (!razorpay.verifyPaymentSignature(input.razorpayOrderId, input.razorpayPaymentId, input.razorpaySignature)) {
      throw new AppError('BAD_REQUEST', 'Payment verification failed', { reason: 'signature_invalid' });
    }

    const payment = await razorpay.fetchPayment(input.razorpayPaymentId);
    if (payment.order_id !== input.razorpayOrderId) {
      throw new AppError('BAD_REQUEST', 'Payment does not belong to this order', { reason: 'payment_mismatch' });
    }
    if (payment.status !== 'captured') {
      // Usually captured within seconds; the webhook / reconciler will finish it.
      return { status: 'processing' as const, orderStatus: found.order.orderStatus };
    }
    const { order } = await applyCaptured(input.razorpayOrderId, payment);
    return { status: 'paid' as const, orderStatus: order?.orderStatus ?? found.order.orderStatus, paymentStatus: order?.paymentStatus };
  },

  async handleWebhook(rawBody: Buffer, signature: string | undefined, eventIdHeader: string | undefined) {
    if (!signature || !razorpay.verifyWebhookSignature(rawBody, signature)) {
      throw new AppError('BAD_REQUEST', 'Invalid webhook signature');
    }
    const event = JSON.parse(rawBody.toString('utf8')) as {
      event: string;
      payload?: { payment?: { entity?: RazorpayPayment }; order?: { entity?: { id: string } } };
      created_at?: number;
    };
    const eventId = eventIdHeader ?? `${event.event}:${event.payload?.payment?.entity?.id ?? event.payload?.order?.entity?.id}:${event.created_at}`;
    const record = await paymentsRepository.recordWebhookEvent(db, eventId, event.event, event);
    if (record.processedAt) return { duplicate: true };

    try {
      const payment = event.payload?.payment?.entity;
      if ((event.event === 'payment.captured' || event.event === 'order.paid') && payment?.order_id) {
        await applyCaptured(payment.order_id, payment.status === 'captured' ? payment : await razorpay.fetchPayment(payment.id));
      } else if (event.event === 'payment.failed' && payment?.order_id) {
        await paymentsRepository.recordFailure(db, payment.order_id, payment.error_code, payment.error_description);
      }
      await paymentsRepository.finishWebhookEvent(db, record.id, null);
      return { duplicate: false };
    } catch (error) {
      await paymentsRepository.finishWebhookEvent(db, record.id, error instanceof Error ? error.message : String(error));
      throw error; // 5xx → Razorpay retries; the event row lets the retry run again
    }
  },

  /** Sweeper hook: catch captures whose webhook never arrived, and retry stuck refunds. */
  async reconcile(): Promise<{ captured: number; refundsRetried: number }> {
    if (!razorpayConfigured()) return { captured: 0, refundsRetried: 0 };
    let captured = 0;
    for (const { providerOrderId } of await paymentsRepository.attemptsToReconcile(db, 20)) {
      try {
        const paid = (await razorpay.fetchOrderPayments(providerOrderId)).find((p) => p.status === 'captured');
        if (paid) {
          await applyCaptured(providerOrderId, paid);
          captured++;
        }
      } catch (error) {
        logger.warn({ err: error, providerOrderId }, 'reconcile check failed');
      }
    }
    let refundsRetried = 0;
    for (const { refund, providerPaymentId } of await paymentsRepository.pendingRefunds(db, 10)) {
      if (!providerPaymentId) continue;
      await issueRefund({ paymentId: refund.paymentId, providerPaymentId, amountPaise: toPaise(refund.amount), orderId: refund.orderId, reason: refund.reason });
      refundsRetried++;
    }
    return { captured, refundsRetried };
  },

  /** Customer cancelled a paid order before the store started on it. */
  async refundOrder(orderId: string, reason: string) {
    const [paid] = await paymentsRepository.capturedForOrder(db, orderId);
    if (!paid?.providerPaymentId) return;
    await issueRefund({ paymentId: paid.id, providerPaymentId: paid.providerPaymentId, amountPaise: toPaise(paid.amount), orderId, reason });
  },

  /** Exposed for tests / admin tools. */
  applyCaptured,
};
