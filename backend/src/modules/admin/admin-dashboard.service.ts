import { sql } from 'drizzle-orm';
import { displayQty, toMilli } from '../../common/money';
import { db } from '../../db/client';

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

/** Start of the IST day `daysAgo` days back, as a UTC instant. */
function istDayStart(daysAgo: number, now = new Date()): Date {
  const ist = new Date(now.getTime() + IST_OFFSET_MS);
  const midnight = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()) - IST_OFFSET_MS;
  return new Date(midnight - daysAgo * DAY_MS);
}

/** "Sales" = orders the store accepted (placed onwards), at their final billed amount; cancelled ones excluded. */
const SOLD = sql`order_status not in ('pending_payment', 'payment_failed', 'cancelled')`;
const AMOUNT = sql`coalesce(final_amount, total_amount)`;

export const adminDashboardService = {
  async summary(days: number) {
    const fromDate = istDayStart(days - 1);
    // Raw-SQL params must be strings: drizzle's postgres-js driver passes Date objects through unencoded.
    const from = sql`${fromDate.toISOString()}::timestamptz`;
    const previousFrom = sql`${istDayStart(2 * days - 1).toISOString()}::timestamptz`;
    const [totals] = await db.execute<{
      orders: number; sales: string; cod_sales: string; online_sales: string; delivered: number; cancelled: number;
      customers: number; prev_orders: number; prev_sales: string;
    }>(sql`
      select count(*) filter (where ${SOLD} and placed_at >= ${from})::int as orders,
             coalesce(sum(${AMOUNT}) filter (where ${SOLD} and placed_at >= ${from}), 0)::numeric(14,2) as sales,
             coalesce(sum(${AMOUNT}) filter (where ${SOLD} and placed_at >= ${from} and payment_method = 'cod'), 0)::numeric(14,2) as cod_sales,
             coalesce(sum(${AMOUNT}) filter (where ${SOLD} and placed_at >= ${from} and payment_method <> 'cod'), 0)::numeric(14,2) as online_sales,
             count(*) filter (where order_status = 'delivered' and delivered_at >= ${from})::int as delivered,
             count(*) filter (where order_status = 'cancelled' and cancelled_at >= ${from})::int as cancelled,
             count(distinct user_id) filter (where ${SOLD} and placed_at >= ${from})::int as customers,
             count(*) filter (where ${SOLD} and placed_at >= ${previousFrom} and placed_at < ${from})::int as prev_orders,
             coalesce(sum(${AMOUNT}) filter (where ${SOLD} and placed_at >= ${previousFrom} and placed_at < ${from}), 0)::numeric(14,2) as prev_sales
        from orders
       where coalesce(placed_at, created_at) >= ${previousFrom} or cancelled_at >= ${from} or delivered_at >= ${from}`);

    const daily = await db.execute<{ day: string; orders: number; sales: string }>(sql`
      select to_char((placed_at at time zone 'Asia/Kolkata')::date, 'YYYY-MM-DD') as day,
             count(*)::int as orders, coalesce(sum(${AMOUNT}), 0)::numeric(14,2) as sales
        from orders
       where ${SOLD} and placed_at >= ${from}
       group by 1 order by 1`);

    const top = await db.execute<{ product_id: number; name: string; quantity: string; sales: string; orders: number }>(sql`
      select oi.product_id, oi.product_name as name,
             sum(coalesce(oi.packed_quantity, oi.quantity))::numeric(14,3) as quantity,
             sum(oi.total_price)::numeric(14,2) as sales, count(distinct oi.order_id)::int as orders
        from order_items oi join orders o on o.id = oi.order_id
       where o.order_status not in ('pending_payment', 'payment_failed', 'cancelled') and o.placed_at >= ${from}
       group by 1, 2 order by sum(oi.total_price) desc limit 10`);

    const t = totals!;
    const orders = Number(t.orders);
    return {
      days,
      from: fromDate,
      totals: {
        orders,
        sales: t.sales,
        averageOrderValue: orders > 0 ? (Number(t.sales) / orders).toFixed(2) : '0.00',
        codSales: t.cod_sales,
        onlineSales: t.online_sales,
        delivered: Number(t.delivered),
        cancelled: Number(t.cancelled),
        customers: Number(t.customers),
      },
      previous: { orders: Number(t.prev_orders), sales: t.prev_sales },
      daily: daily.map((row) => ({ day: row.day, orders: Number(row.orders), sales: row.sales })),
      topProducts: top.map((row) => ({ productId: Number(row.product_id), name: row.name, quantity: displayQty(toMilli(row.quantity)), sales: row.sales, orders: Number(row.orders) })),
    };
  },
};
