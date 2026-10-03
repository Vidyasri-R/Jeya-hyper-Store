import { and, asc, desc, eq, inArray, sql, type SQL } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import {
  orderItems,
  orderStatusHistory,
  orders,
  payments,
  products,
  refunds,
  users,
  type NewOrder,
  type OrderStatus,
} from '../../db/schema';

export type StaffListFilter = {
  statuses: OrderStatus[] | null;
  search: string | null;
  direction: 'asc' | 'desc';
  cursor: { createdAt: string; id: string } | null;
  limit: number;
};

/** Only what the board's order cards show — keeps each poll/page small on the wire. */
const listColumns = {
  id: orders.id,
  orderNumber: orders.orderNumber,
  status: orders.orderStatus,
  paymentMethod: orders.paymentMethod,
  paymentStatus: orders.paymentStatus,
  totalAmount: orders.totalAmount,
  finalAmount: orders.finalAmount,
  recipientName: sql<string>`${orders.deliveryAddress}->>'recipientName'`,
  phone: sql<string>`${orders.deliveryAddress}->>'phone'`,
  area: sql<string>`concat_ws(', ', ${orders.deliveryAddress}->>'line1', ${orders.deliveryAddress}->>'pincode')`,
  hasNote: sql<boolean>`${orders.customerNote} is not null`,
  itemCount: sql<number>`(select count(*)::int from "order_items" oi where oi."order_id" = "orders"."id")`,
  placedAt: orders.placedAt,
  createdAt: orders.createdAt,
  updatedAt: orders.updatedAt,
  /** Exact (µs) creation time for the keyset cursor — a JS Date would drop the microseconds. */
  cursorTs: sql<string>`to_char(${orders.createdAt} at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')`,
};

function searchFilter(raw: string): SQL {
  const q = raw.trim();
  const digits = q.replace(/\D/g, '');
  const parts: SQL[] = [];
  if (/^jhs-/i.test(q)) parts.push(sql`${orders.orderNumber} = ${q.toUpperCase()}`);
  if (digits.length >= 3) {
    // "1011" → order JHS-yymmdd-1011; "98765" → phone ending
    parts.push(sql`${orders.orderNumber} like ${`%-${digits}`}`);
    parts.push(sql`(${orders.deliveryAddress}->>'phone') like ${`%${digits}`}`);
  }
  if (/[a-z]/i.test(q) && !/^jhs-/i.test(q)) {
    parts.push(sql`(${orders.deliveryAddress}->>'recipientName') ilike ${`%${q.replace(/[%_\\]/g, '\\$&')}%`}`);
  }
  return parts.length > 0 ? sql`(${sql.join(parts, sql` or `)})` : sql`false`;
}

export const staffOrdersRepository = {
  async list(db: DbExecutor, filter: StaffListFilter) {
    const where: SQL[] = [];
    if (filter.statuses) where.push(inArray(orders.orderStatus, filter.statuses));
    if (filter.search) where.push(searchFilter(filter.search));
    if (filter.cursor) {
      const { createdAt, id } = filter.cursor;
      where.push(
        filter.direction === 'asc'
          ? sql`(${orders.createdAt}, ${orders.id}) > (${createdAt}::timestamptz, ${id}::uuid)`
          : sql`(${orders.createdAt}, ${orders.id}) < (${createdAt}::timestamptz, ${id}::uuid)`,
      );
    }
    const order = filter.direction === 'asc' ? [asc(orders.createdAt), asc(orders.id)] : [desc(orders.createdAt), desc(orders.id)];
    return db
      .select(listColumns)
      .from(orders)
      .where(where.length > 0 ? and(...where) : undefined)
      .orderBy(...order)
      .limit(filter.limit + 1);
  },

  /** Board badges in one scan of the status index. */
  async counts(db: DbExecutor) {
    const [row] = await db
      .select({
        placed: sql<number>`count(*) filter (where ${orders.orderStatus} = 'placed')::int`,
        packing: sql<number>`count(*) filter (where ${orders.orderStatus} in ('confirmed', 'packing'))::int`,
        ready: sql<number>`count(*) filter (where ${orders.orderStatus} = 'ready_for_delivery')::int`,
        out: sql<number>`count(*) filter (where ${orders.orderStatus} = 'out_for_delivery')::int`,
        unpaid: sql<number>`count(*) filter (where ${orders.orderStatus} = 'pending_payment')::int`,
        deliveredToday: sql<number>`count(*) filter (where ${orders.orderStatus} = 'delivered'
          and ${orders.deliveredAt} >= date_trunc('day', now() at time zone 'Asia/Kolkata') at time zone 'Asia/Kolkata')::int`,
        latestPlacedAt: sql<string | null>`max(${orders.placedAt})`,
      })
      .from(orders)
      .where(
        sql`${orders.orderStatus} in ('pending_payment', 'placed', 'confirmed', 'packing', 'ready_for_delivery', 'out_for_delivery')
            or (${orders.orderStatus} = 'delivered' and ${orders.deliveredAt} > now() - interval '1 day')`,
      );
    return row!;
  },

  async lock(db: DbExecutor, orderId: string) {
    const [row] = await db.select().from(orders).where(eq(orders.id, orderId)).for('update').limit(1);
    return row ?? null;
  },

  async update(db: DbExecutor, orderId: string, patch: Partial<NewOrder>) {
    const [row] = await db.update(orders).set(patch).where(eq(orders.id, orderId)).returning();
    return row!;
  },

  async items(db: DbExecutor, orderId: string) {
    return db.select().from(orderItems).where(eq(orderItems.orderId, orderId)).orderBy(asc(orderItems.id));
  },

  async setPackedQuantities(db: DbExecutor, rows: { id: number; packedQuantity: string }[]) {
    if (rows.length === 0) return;
    const values = rows.map((row) => sql`(${row.id}::bigint, ${row.packedQuantity}::numeric)`);
    await db.execute(sql`
      update ${orderItems} as oi set packed_quantity = v.qty
        from (values ${sql.join(values, sql`, `)}) as v(id, qty)
       where oi.id = v.id`);
  },

  async detail(db: DbExecutor, orderId: string) {
    const [order] = await db.select().from(orders).where(eq(orders.id, orderId)).limit(1);
    if (!order) return null;
    const [items, history, customer, paid, refundRows] = await Promise.all([
      db
        .select({
          item: orderItems,
          barcode: products.barcode,
          packSize: products.packSize,
          isLoose: products.isLoose,
          imageUrl: products.imageUrl,
        })
        .from(orderItems)
        .innerJoin(products, eq(products.id, orderItems.productId))
        .where(eq(orderItems.orderId, orderId))
        .orderBy(asc(orderItems.id)),
      db
        .select()
        .from(orderStatusHistory)
        .where(eq(orderStatusHistory.orderId, orderId))
        .orderBy(asc(orderStatusHistory.createdAt), asc(orderStatusHistory.id)),
      db.select({ id: users.id, name: users.name, phone: users.phone }).from(users).where(eq(users.id, order.userId)).limit(1),
      db
        .select({
          amount: payments.amount,
          method: payments.method,
          providerPaymentId: payments.providerPaymentId,
          capturedAt: payments.capturedAt,
        })
        .from(payments)
        .where(and(eq(payments.orderId, orderId), eq(payments.status, 'captured')))
        .orderBy(asc(payments.capturedAt)),
      db
        .select({ amount: refunds.amount, status: refunds.status, reason: refunds.reason, createdAt: refunds.createdAt })
        .from(refunds)
        .where(eq(refunds.orderId, orderId))
        .orderBy(asc(refunds.createdAt)),
    ]);
    return { order, items, history, customer: customer[0] ?? null, payments: paid, refunds: refundRows };
  },
};
