import { and, asc, eq, isNull, sql } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { normalizeIndianMobile } from '../../common/phone';
import { db, type DbExecutor } from '../../db/client';
import { customerPerks, users } from '../../db/schema';

/**
 * Premium customers (Admin → Premium customers): the store adds a phone number and gives that
 * customer free delivery on every order and/or a discount on the items. Applied at checkout.
 */
export type Perks = { freeDelivery: boolean; discountPercent: number; name: string | null };

export const perksService = {
  /** The signed-in customer's perks, or null. */
  async forUser(executor: DbExecutor, userId: string): Promise<Perks | null> {
    const [row] = await executor
      .select({ freeDelivery: customerPerks.freeDelivery, discountPercent: customerPerks.discountPercent, name: customerPerks.name })
      .from(customerPerks)
      .innerJoin(users, eq(users.phone, customerPerks.phone))
      .where(and(eq(users.id, userId), eq(customerPerks.isActive, true), isNull(users.deletedAt)))
      .limit(1);
    if (!row) return null;
    const discountPercent = Number(row.discountPercent);
    if (!row.freeDelivery && !(discountPercent > 0)) return null;
    return { freeDelivery: row.freeDelivery, discountPercent, name: row.name };
  },

  /** Every premium customer, with whether they have an account yet and how many orders they placed. */
  async list() {
    return db
      .select({
        phone: customerPerks.phone,
        name: customerPerks.name,
        freeDelivery: customerPerks.freeDelivery,
        discountPercent: customerPerks.discountPercent,
        note: customerPerks.note,
        isActive: customerPerks.isActive,
        updatedAt: customerPerks.updatedAt,
        accountName: users.name,
        hasAccount: sql<boolean>`${users.id} IS NOT NULL`,
        orders: sql<number>`(select count(*) from orders o where o.user_id = ${users.id} and o.order_status not in ('pending_payment', 'payment_failed', 'cancelled'))::int`,
      })
      .from(customerPerks)
      .leftJoin(users, and(eq(users.phone, customerPerks.phone), isNull(users.deletedAt)))
      .orderBy(asc(customerPerks.name), asc(customerPerks.phone));
  },

  async save(staffId: string, input: { phone: string; name?: string | null | undefined; freeDelivery: boolean; discountPercent: number; note?: string | null | undefined; isActive?: boolean | undefined }) {
    const phone = normalizeIndianMobile(input.phone);
    if (!phone) throw new AppError('BAD_REQUEST', 'Enter a valid 10-digit mobile number', { reason: 'phone_invalid' });
    if (!input.freeDelivery && !(input.discountPercent > 0)) {
      throw new AppError('BAD_REQUEST', 'Give free delivery or a discount (or remove the customer)', { reason: 'no_perk' });
    }
    const values = {
      phone,
      name: input.name?.trim() || null,
      freeDelivery: input.freeDelivery,
      discountPercent: input.discountPercent.toFixed(2),
      note: input.note?.trim() || null,
      isActive: input.isActive ?? true,
      updatedBy: staffId,
    };
    const [row] = await db
      .insert(customerPerks)
      .values(values)
      .onConflictDoUpdate({ target: customerPerks.phone, set: { ...values, updatedAt: sql`now()` } })
      .returning();
    return row!;
  },

  async remove(phone: string) {
    const normalized = normalizeIndianMobile(phone) ?? phone;
    const rows = await db.delete(customerPerks).where(eq(customerPerks.phone, normalized)).returning({ phone: customerPerks.phone });
    if (rows.length === 0) throw AppError.notFound('Premium customer');
  },
};

/** The member discount on the items, in paise (rounded to the nearest paisa). */
export function memberDiscountPaise(subtotalPaise: number, perks: Perks | null): number {
  if (!perks || !(perks.discountPercent > 0)) return 0;
  return Math.round((subtotalPaise * perks.discountPercent) / 100);
}
