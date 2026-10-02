import { and, asc, desc, eq, inArray, isNotNull, sql } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { orders, paymentWebhookEvents, payments, refunds, type PaymentMethod } from '../../db/schema';

export const paymentsRepository = {
  async latestOpenAttempt(db: DbExecutor, orderId: string) {
    const [row] = await db
      .select()
      .from(payments)
      .where(and(eq(payments.orderId, orderId), eq(payments.status, 'created')))
      .orderBy(desc(payments.createdAt))
      .limit(1);
    return row ?? null;
  },

  async insertAttempt(db: DbExecutor, values: { orderId: string; providerOrderId: string; amount: string }) {
    const [row] = await db
      .insert(payments)
      .values({ ...values, provider: 'razorpay', status: 'created' })
      .returning();
    if (!row) throw new Error('payment insert returned no row');
    return row;
  },

  async lockByProviderOrderId(db: DbExecutor, providerOrderId: string) {
    const [row] = await db
      .select()
      .from(payments)
      .where(and(eq(payments.provider, 'razorpay'), eq(payments.providerOrderId, providerOrderId)))
      .for('update')
      .limit(1);
    return row ?? null;
  },

  async findForOrder(db: DbExecutor, orderId: string, providerOrderId: string) {
    const [row] = await db
      .select()
      .from(payments)
      .where(and(eq(payments.orderId, orderId), eq(payments.providerOrderId, providerOrderId)))
      .limit(1);
    return row ?? null;
  },

  async capturedForOrder(db: DbExecutor, orderId: string) {
    return db
      .select()
      .from(payments)
      .where(and(eq(payments.orderId, orderId), eq(payments.status, 'captured')))
      .orderBy(asc(payments.capturedAt));
  },

  async markCaptured(
    db: DbExecutor,
    id: string,
    values: { providerPaymentId: string; method: PaymentMethod; capturedAt: Date },
  ) {
    await db
      .update(payments)
      .set({ status: 'captured', errorCode: null, errorDescription: null, ...values })
      .where(eq(payments.id, id));
  },

  async recordFailure(db: DbExecutor, providerOrderId: string, errorCode: string | null, errorDescription: string | null) {
    await db
      .update(payments)
      .set({ errorCode, errorDescription })
      .where(and(eq(payments.provider, 'razorpay'), eq(payments.providerOrderId, providerOrderId), eq(payments.status, 'created')));
  },

  /** Pending-payment orders whose hold has (nearly) run out and that have an open gateway attempt. */
  async attemptsToReconcile(db: DbExecutor, limit: number) {
    return db
      .select({ providerOrderId: payments.providerOrderId })
      .from(payments)
      .innerJoin(orders, eq(orders.id, payments.orderId))
      .where(
        and(
          eq(payments.status, 'created'),
          eq(orders.orderStatus, 'pending_payment'),
          sql`${orders.reservationExpiresAt} < now() + interval '1 minute'`,
        ),
      )
      .orderBy(asc(orders.reservationExpiresAt))
      .limit(limit);
  },

  // ── refunds ──
  async refundForPayment(db: DbExecutor, paymentId: string) {
    const [row] = await db.select().from(refunds).where(eq(refunds.paymentId, paymentId)).limit(1);
    return row ?? null;
  },

  async insertRefund(db: DbExecutor, values: typeof refunds.$inferInsert) {
    const [row] = await db.insert(refunds).values(values).returning();
    if (!row) throw new Error('refund insert returned no row');
    return row;
  },

  async updateRefund(db: DbExecutor, id: string, patch: Partial<typeof refunds.$inferInsert>) {
    await db.update(refunds).set(patch).where(eq(refunds.id, id));
  },

  async pendingRefunds(db: DbExecutor, limit: number) {
    return db
      .select({ refund: refunds, providerPaymentId: payments.providerPaymentId })
      .from(refunds)
      .innerJoin(payments, eq(payments.id, refunds.paymentId))
      .where(and(eq(refunds.status, 'pending'), isNotNull(payments.providerPaymentId)))
      .orderBy(asc(refunds.createdAt))
      .limit(limit);
  },

  // ── webhook events ──
  /** Insert-or-get; returns whether the event was already processed successfully. */
  async recordWebhookEvent(db: DbExecutor, eventId: string, eventType: string, payload: unknown) {
    await db
      .insert(paymentWebhookEvents)
      .values({ provider: 'razorpay', eventId, eventType, payload })
      .onConflictDoNothing({ target: [paymentWebhookEvents.provider, paymentWebhookEvents.eventId] });
    const [row] = await db
      .select({ id: paymentWebhookEvents.id, processedAt: paymentWebhookEvents.processedAt })
      .from(paymentWebhookEvents)
      .where(and(eq(paymentWebhookEvents.provider, 'razorpay'), eq(paymentWebhookEvents.eventId, eventId)))
      .limit(1);
    return row!;
  },

  async finishWebhookEvent(db: DbExecutor, id: number, error: string | null) {
    await db
      .update(paymentWebhookEvents)
      .set(error ? { processingError: error.slice(0, 2000) } : { processedAt: sql`now()`, processingError: null })
      .where(eq(paymentWebhookEvents.id, id));
  },

  async ordersByIds(db: DbExecutor, ids: string[]) {
    if (ids.length === 0) return [];
    return db.select().from(orders).where(inArray(orders.id, ids));
  },
};
