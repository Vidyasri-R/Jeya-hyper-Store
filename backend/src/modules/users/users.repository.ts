import { and, eq, inArray, isNull, sql } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { addresses, cartItems, orders, users, type OrderStatus } from '../../db/schema';

/** Orders the store is still fulfilling — account can't be deleted mid-delivery. */
const IN_FLIGHT_STATUSES: OrderStatus[] = [
  'placed',
  'confirmed',
  'packing',
  'ready_for_delivery',
  'out_for_delivery',
];

export const usersRepository = {
  async findActiveById(db: DbExecutor, id: string) {
    const [row] = await db
      .select()
      .from(users)
      .where(and(eq(users.id, id), isNull(users.deletedAt)))
      .limit(1);
    return row ?? null;
  },

  async updateProfile(db: DbExecutor, id: string, patch: { name?: string | undefined; email?: string | null | undefined }) {
    const [row] = await db
      .update(users)
      .set(patch)
      .where(and(eq(users.id, id), isNull(users.deletedAt)))
      .returning();
    return row ?? null;
  },

  async countInFlightOrders(db: DbExecutor, userId: string): Promise<number> {
    const [row] = await db
      .select({ count: sql<number>`count(*)::int` })
      .from(orders)
      .where(and(eq(orders.userId, userId), inArray(orders.orderStatus, IN_FLIGHT_STATUSES)));
    return Number(row?.count ?? 0);
  },

  /**
   * Soft-delete + PII scrub. The phone number stays on the (now inactive) row
   * because past orders/GST invoices must remain attributable for tax-record
   * retention; the partial unique index lets the same number sign up afresh.
   */
  async softDeleteAndScrub(db: DbExecutor, userId: string) {
    await db
      .update(users)
      .set({ deletedAt: sql`now()`, name: null, email: null, fcmToken: null })
      .where(and(eq(users.id, userId), isNull(users.deletedAt)));

    await db
      .update(addresses)
      .set({ deletedAt: sql`now()`, isDefault: false })
      .where(and(eq(addresses.userId, userId), isNull(addresses.deletedAt)));

    await db.delete(cartItems).where(eq(cartItems.userId, userId));
  },
};
