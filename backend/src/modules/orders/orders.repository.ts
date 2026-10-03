import { and, asc, desc, eq, inArray, sql, type SQL } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import {
  orderItems,
  orderNumberSeq,
  orderStatusHistory,
  orders,
  products,
  type NewOrder,
  type NewOrderItem,
  type OrderStatus,
} from '../../db/schema';

export type Reservation = { productId: number; quantity: string };

export const ordersRepository = {
  async findByIdempotencyKey(db: DbExecutor, userId: string, key: string) {
    const [row] = await db
      .select()
      .from(orders)
      .where(and(eq(orders.userId, userId), eq(orders.idempotencyKey, key)))
      .limit(1);
    return row ?? null;
  },

  async nextOrderSeq(db: DbExecutor): Promise<number> {
    const [row] = await db.execute<{ seq: string }>(sql`select nextval(${sql.raw(`'${orderNumberSeq.seqName}'`)}) as seq`);
    return Number(row?.seq);
  },

  /**
   * Reserve stock for all lines in two statements:
   *  1. lock the product rows in ascending id order (consistent order ⇒ no deadlocks
   *     between concurrent checkouts that share products);
   *  2. one conditional UPDATE that only succeeds per row if enough is free.
   * Returns the product ids that could NOT be reserved (empty = all good).
   */
  async reserve(db: DbExecutor, lines: Reservation[]): Promise<number[]> {
    if (lines.length === 0) return [];
    const ids = lines.map((line) => line.productId).sort((a, b) => a - b);
    await db.execute(sql`select id from ${products} where ${inArray(products.id, ids)} order by id for update`);

    const values = lines.map((line) => sql`(${line.productId}::bigint, ${line.quantity}::numeric)`);
    const reserved = await db.execute<{ id: string }>(sql`
      update ${products} as p
         set reserved_quantity = p.reserved_quantity + v.qty, updated_at = now()
        from (values ${sql.join(values, sql`, `)}) as v(id, qty)
       where p.id = v.id
         and p.is_active
         and p.stock_quantity - p.reserved_quantity - p.safety_stock >= v.qty
      returning p.id`);
    const ok = new Set(reserved.map((row) => Number(row.id)));
    return ids.filter((id) => !ok.has(id));
  },

  /** Give back everything the given orders reserved (cancel / payment expiry). Never goes below 0. */
  async releaseForOrders(db: DbExecutor, orderIds: string[]) {
    if (orderIds.length === 0) return;
    await db.execute(sql`
      update ${products} as p
         set reserved_quantity = greatest(p.reserved_quantity - s.qty, 0), updated_at = now()
        from (select ${orderItems.productId} as product_id, sum(${orderItems.quantity}) as qty
                from ${orderItems}
               where ${inArray(orderItems.orderId, orderIds)}
               group by ${orderItems.productId}) as s
       where p.id = s.product_id`);
  },

  async insertOrder(db: DbExecutor, values: NewOrder) {
    const [row] = await db.insert(orders).values(values).returning();
    if (!row) throw new Error('order insert returned no row');
    return row;
  },

  async insertItems(db: DbExecutor, values: NewOrderItem[]) {
    await db.insert(orderItems).values(values);
  },

  async addHistory(
    db: DbExecutor,
    entries: {
      orderId: string;
      fromStatus: OrderStatus | null;
      toStatus: OrderStatus;
      changedBy: string | null;
      changedByStaff?: string | null;
      note?: string;
    }[],
  ) {
    if (entries.length === 0) return;
    await db.insert(orderStatusHistory).values(entries);
  },

  async lockForUser(db: DbExecutor, userId: string, orderId: string) {
    const [row] = await db
      .select()
      .from(orders)
      .where(and(eq(orders.id, orderId), eq(orders.userId, userId)))
      .for('update')
      .limit(1);
    return row ?? null;
  },

  async updateOrder(db: DbExecutor, orderId: string, patch: Partial<NewOrder>) {
    const [row] = await db.update(orders).set(patch).where(eq(orders.id, orderId)).returning();
    return row ?? null;
  },

  async listForUser(db: DbExecutor, userId: string, cursor: { createdAt: string; id: string } | null, limit: number) {
    const filters: SQL[] = [eq(orders.userId, userId)];
    if (cursor) {
      // String params on purpose: drizzle's postgres-js driver can't encode a raw Date inside sql``.
      filters.push(sql`(${orders.createdAt}, ${orders.id}) < (${cursor.createdAt}::timestamptz, ${cursor.id}::uuid)`);
    }
    return db
      .select({
        order: orders,
        // Explicitly qualified: inside a subquery drizzle renders bare column names, and a bare
        // "id" would bind to order_items.id instead of the outer orders.id.
        itemCount: sql<number>`(select count(*)::int from "order_items" oi where oi."order_id" = "orders"."id")`,
        /** Exact (µs) creation time for the keyset cursor — a JS Date would drop the microseconds. */
        cursorTs: sql<string>`to_char(${orders.createdAt} at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')`,
      })
      .from(orders)
      .where(and(...filters))
      .orderBy(desc(orders.createdAt), desc(orders.id))
      .limit(limit + 1);
  },

  async findForUser(db: DbExecutor, userId: string, orderId: string) {
    const [order] = await db
      .select()
      .from(orders)
      .where(and(eq(orders.id, orderId), eq(orders.userId, userId)))
      .limit(1);
    if (!order) return null;
    const [items, history] = await Promise.all([
      db.select().from(orderItems).where(eq(orderItems.orderId, orderId)).orderBy(asc(orderItems.id)),
      db
        .select()
        .from(orderStatusHistory)
        .where(eq(orderStatusHistory.orderId, orderId))
        .orderBy(asc(orderStatusHistory.createdAt), asc(orderStatusHistory.id)),
    ]);
    return { order, items, history };
  },

  /** Pending-payment orders past their hold, locked so parallel sweepers never double-release. */
  async lockExpiredPending(db: DbExecutor, limit: number) {
    return db
      .select({ id: orders.id })
      .from(orders)
      .where(and(eq(orders.orderStatus, 'pending_payment'), sql`${orders.reservationExpiresAt} < now()`))
      .orderBy(asc(orders.reservationExpiresAt))
      .limit(limit)
      .for('update', { skipLocked: true });
  },

  async markPaymentFailed(db: DbExecutor, orderIds: string[]) {
    if (orderIds.length === 0) return;
    await db
      .update(orders)
      .set({ orderStatus: 'payment_failed', paymentStatus: 'failed', gofrugalSyncStatus: 'not_required' })
      .where(inArray(orders.id, orderIds));
  },
};
