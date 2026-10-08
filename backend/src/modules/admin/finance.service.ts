import { and, desc, eq, gte, lt, sql } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { fromPaise, toPaise } from '../../common/money';
import { db } from '../../db/client';
import { expenses } from '../../db/schema';

/**
 * Admin → Finance: what the online shop earned and spent over a period (IST days, [from, to]).
 *
 * - Sales = orders the store accepted (cancelled / unpaid excluded), at their final billed amount,
 *   so short-packs and cancellations are already out — refunds are shown for information only.
 * - Cost of goods = each line's cost when ordered (the stock file's Landing Cost) × packed qty.
 *   Lines without a cost are estimated at the cost ratio of the lines that have one.
 * - Prices and costs include GST; the report shows the GST inside sales separately.
 */

const SOLD = sql`o.order_status not in ('pending_payment', 'payment_failed', 'cancelled')`;
const BILLED = sql`coalesce(o.final_amount, o.total_amount)`;
const QTY = sql`coalesce(oi.packed_quantity, oi.quantity)`;
const LINE = sql`round(oi.unit_price * ${QTY}, 2)`;

export const EXPENSE_CATEGORIES = ['Delivery staff', 'Fuel & vehicle', 'Packing material', 'Marketing', 'Software & hosting', 'Rent & electricity', 'Other'] as const;

/** "2026-10-08" (IST day) → that day's start as a UTC instant. */
function istStart(day: string): string {
  return new Date(`${day}T00:00:00+05:30`).toISOString();
}

function nextDay(day: string): string {
  const d = new Date(`${day}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

const n = (v: unknown) => Number(v ?? 0);
const money = (v: unknown) => fromPaise(Math.round(n(v) * 100));

export const financeService = {
  async report(fromDay: string, toDay: string) {
    if (toDay < fromDay) throw new AppError('BAD_REQUEST', 'The end date is before the start date', { reason: 'range_invalid' });
    const from = sql`${istStart(fromDay)}::timestamptz`;
    const to = sql`${istStart(nextDay(toDay))}::timestamptz`;
    const inRange = sql`o.placed_at >= ${from} and o.placed_at < ${to} and ${SOLD}`;

    const [orders] = await db.execute<Record<string, string | number>>(sql`
      select count(*)::int as orders,
             count(distinct o.user_id)::int as customers,
             coalesce(sum(${BILLED}), 0) as billed,
             coalesce(sum(o.delivery_fee), 0) as delivery_fees,
             coalesce(sum(o.discount_amount), 0) as member_discounts,
             count(*) filter (where o.delivery_fee = 0)::int as free_delivery_orders,
             count(*) filter (where o.member_free_delivery or coalesce(o.member_discount_percent, 0) > 0)::int as member_orders,
             coalesce(sum(${BILLED}) filter (where o.payment_method = 'cod'), 0) as cod_sales,
             coalesce(sum(${BILLED}) filter (where o.payment_method <> 'cod'), 0) as online_sales,
             count(*) filter (where o.order_status = 'delivered')::int as delivered
        from orders o
       where ${inRange}`);

    const [lines] = await db.execute<Record<string, string | number>>(sql`
      select coalesce(sum(${LINE}), 0) as item_value,
             coalesce(sum(${LINE}) filter (where oi.unit_cost is not null), 0) as costed_value,
             coalesce(sum(round(oi.unit_cost * ${QTY}, 2)) filter (where oi.unit_cost is not null), 0) as costed_cost,
             coalesce(sum(${LINE} * oi.gst_rate / (100 + oi.gst_rate)), 0) as gst_in_sales
        from order_items oi join orders o on o.id = oi.order_id
       where ${inRange}`);

    const [fees] = await db.execute<Record<string, string>>(sql`
      select coalesce(sum(coalesce(p.gateway_fee, 0) + coalesce(p.gateway_tax, 0)), 0) as gateway
        from payments p join orders o on o.id = p.order_id
       where p.status = 'captured' and ${inRange}`);

    const [refunds] = await db.execute<Record<string, string>>(sql`
      select coalesce(sum(r.amount), 0) as refunded, count(*)::int as count
        from refunds r
       where r.status = 'processed' and r.created_at >= ${from} and r.created_at < ${to}`);

    const spent = await db
      .select({ category: expenses.category, amount: sql<string>`sum(${expenses.amount})` })
      .from(expenses)
      .where(and(gte(expenses.spentOn, fromDay), lt(expenses.spentOn, nextDay(toDay))))
      .groupBy(expenses.category);

    const byCategory = await db.execute<Record<string, string | number>>(sql`
      select coalesce(parent.name, c.name, 'Other') as category,
             sum(${LINE}) as sales,
             sum(${LINE}) filter (where oi.unit_cost is not null) as costed_value,
             sum(round(oi.unit_cost * ${QTY}, 2)) filter (where oi.unit_cost is not null) as cost,
             count(distinct o.id)::int as orders
        from order_items oi
        join orders o on o.id = oi.order_id
        left join products p on p.id = oi.product_id
        left join categories c on c.id = p.category_id
        left join categories parent on parent.id = c.parent_id
       where ${inRange}
       group by 1 order by 2 desc`);

    const products = await db.execute<Record<string, string | number>>(sql`
      select oi.product_id as id, max(oi.product_name) as name,
             sum(${QTY}) as qty, sum(${LINE}) as sales,
             sum(round(oi.unit_cost * ${QTY}, 2)) as cost
        from order_items oi join orders o on o.id = oi.order_id
       where ${inRange} and oi.unit_cost is not null
       group by oi.product_id`);

    const daily = await db.execute<Record<string, string | number>>(sql`
      select to_char(o.placed_at at time zone 'Asia/Kolkata', 'YYYY-MM-DD') as day,
             count(*)::int as orders, sum(${BILLED}) as sales
        from orders o where ${inRange} group by 1 order by 1`);

    const [catalog] = await db.execute<Record<string, number>>(sql`
      select count(*) filter (where is_active)::int as active,
             count(*) filter (where is_active and cost_price is not null)::int as with_cost
        from products`);

    // ── totals (paise, so sums stay exact) ──
    const billed = toPaise(money(orders?.billed));
    const deliveryFees = toPaise(money(orders?.delivery_fees));
    const itemsNet = billed - deliveryFees; // items after member discounts and short-packs
    const itemValue = toPaise(money(lines?.item_value));
    const costedValue = toPaise(money(lines?.costed_value));
    const costedCost = toPaise(money(lines?.costed_cost));
    const costRatio = costedValue > 0 ? costedCost / costedValue : null;
    // Lines without a cost: estimated at the ratio of those with one (none at all → unknown).
    const cogs = costRatio === null ? null : Math.round(costedCost + (itemValue - costedValue) * costRatio);
    const gateway = toPaise(money(fees?.gateway));
    const expenseTotal = spent.reduce((s, e) => s + toPaise(money(e.amount)), 0);
    const grossMargin = cogs === null ? null : itemsNet - cogs;
    const netProfit = grossMargin === null ? null : grossMargin + deliveryFees - gateway - expenseTotal;
    const pct = (part: number | null, whole: number) => (part === null || whole <= 0 ? null : Math.round((part / whole) * 1000) / 10);

    const productRows = products.map((p) => {
      const sales = toPaise(money(p.sales));
      const cost = toPaise(money(p.cost));
      return { id: n(p.id), name: String(p.name), qty: String(Number(p.qty)), sales: fromPaise(sales), margin: fromPaise(sales - cost), marginPercent: pct(sales - cost, sales) };
    });

    return {
      period: { from: fromDay, to: toDay },
      orders: {
        count: n(orders?.orders),
        customers: n(orders?.customers),
        delivered: n(orders?.delivered),
        averageOrder: n(orders?.orders) > 0 ? fromPaise(Math.round(billed / n(orders?.orders))) : '0.00',
        freeDeliveryOrders: n(orders?.free_delivery_orders),
        memberOrders: n(orders?.member_orders),
      },
      income: {
        sales: fromPaise(billed),
        items: fromPaise(itemsNet),
        deliveryFees: fromPaise(deliveryFees),
        cod: money(orders?.cod_sales),
        online: money(orders?.online_sales),
        memberDiscounts: money(orders?.member_discounts),
        gstInSales: money(lines?.gst_in_sales),
        refunded: money(refunds?.refunded),
        refunds: n(refunds?.count),
      },
      costs: {
        goods: cogs === null ? null : fromPaise(cogs),
        /** Share of item sales that had a real cost (the rest is estimated). */
        costCoveragePercent: pct(costedValue, itemValue),
        gatewayFees: fromPaise(gateway),
        expenses: fromPaise(expenseTotal),
        expensesByCategory: spent.map((e) => ({ category: e.category, amount: money(e.amount) })).sort((a, b) => toPaise(b.amount) - toPaise(a.amount)),
      },
      profit: {
        grossMargin: grossMargin === null ? null : fromPaise(grossMargin),
        grossMarginPercent: pct(grossMargin, itemsNet),
        net: netProfit === null ? null : fromPaise(netProfit),
        netPercent: pct(netProfit, billed),
      },
      byCategory: byCategory.map((c) => {
        const sales = toPaise(money(c.sales));
        const value = toPaise(money(c.costed_value));
        const cost = toPaise(money(c.cost));
        return { category: String(c.category), sales: fromPaise(sales), orders: n(c.orders), marginPercent: value > 0 ? pct(value - cost, value) : null };
      }),
      topProducts: [...productRows].sort((a, b) => toPaise(b.margin) - toPaise(a.margin)).slice(0, 10),
      /** Sold at a loss or under 5% margin: check the price or the cost in GoFrugal. */
      lowMargin: productRows.filter((p) => p.marginPercent !== null && p.marginPercent < 5).sort((a, b) => (a.marginPercent ?? 0) - (b.marginPercent ?? 0)).slice(0, 10),
      daily: daily.map((d) => ({ day: String(d.day), orders: n(d.orders), sales: money(d.sales) })),
      catalog: { active: n(catalog?.active), withCost: n(catalog?.with_cost) },
    };
  },

  async listExpenses(fromDay: string, toDay: string) {
    return db
      .select()
      .from(expenses)
      .where(and(gte(expenses.spentOn, fromDay), lt(expenses.spentOn, nextDay(toDay))))
      .orderBy(desc(expenses.spentOn), desc(expenses.id));
  },

  async addExpense(staffId: string, input: { spentOn: string; category: string; amount: string; note?: string | null | undefined }) {
    const [row] = await db
      .insert(expenses)
      .values({ spentOn: input.spentOn, category: input.category, amount: input.amount, note: input.note?.trim() || null, createdBy: staffId })
      .returning();
    return row!;
  },

  async removeExpense(id: number) {
    const rows = await db.delete(expenses).where(eq(expenses.id, id)).returning({ id: expenses.id });
    if (rows.length === 0) throw AppError.notFound('Expense');
  },
};
