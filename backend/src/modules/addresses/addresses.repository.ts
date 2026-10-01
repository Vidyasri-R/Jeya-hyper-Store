import { and, desc, eq, isNull, ne, sql } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { addresses, users, type NewAddress } from '../../db/schema';

const active = (userId: string) => and(eq(addresses.userId, userId), isNull(addresses.deletedAt));

export const addressesRepository = {
  async listForUser(db: DbExecutor, userId: string) {
    return db
      .select()
      .from(addresses)
      .where(active(userId))
      .orderBy(desc(addresses.isDefault), desc(addresses.updatedAt));
  },

  async findForUser(db: DbExecutor, userId: string, id: string) {
    const [row] = await db
      .select()
      .from(addresses)
      .where(and(active(userId), eq(addresses.id, id)))
      .limit(1);
    return row ?? null;
  },

  /**
   * Serialises address writes per user by locking the user row (works even when the
   * user has no addresses yet), so concurrent "set default" / first-address saves can't race.
   */
  async lockUserAddresses(db: DbExecutor, userId: string) {
    await db.execute(sql`select id from ${users} where ${users.id} = ${userId} for update`);
  },

  async countForUser(db: DbExecutor, userId: string): Promise<number> {
    const [row] = await db.select({ count: sql<number>`count(*)::int` }).from(addresses).where(active(userId));
    return Number(row?.count ?? 0);
  },

  async clearDefault(db: DbExecutor, userId: string, exceptId?: string) {
    await db
      .update(addresses)
      .set({ isDefault: false })
      .where(and(active(userId), eq(addresses.isDefault, true), ...(exceptId ? [ne(addresses.id, exceptId)] : [])));
  },

  async insert(db: DbExecutor, values: NewAddress) {
    const [row] = await db.insert(addresses).values(values).returning();
    if (!row) throw new Error('address insert returned no row');
    return row;
  },

  async update(db: DbExecutor, userId: string, id: string, patch: Partial<NewAddress>) {
    const [row] = await db
      .update(addresses)
      .set(patch)
      .where(and(active(userId), eq(addresses.id, id)))
      .returning();
    return row ?? null;
  },

  async softDelete(db: DbExecutor, userId: string, id: string) {
    const [row] = await db
      .update(addresses)
      .set({ deletedAt: sql`now()`, isDefault: false })
      .where(and(active(userId), eq(addresses.id, id)))
      .returning({ id: addresses.id });
    return row ?? null;
  },

  async mostRecent(db: DbExecutor, userId: string) {
    const [row] = await db
      .select({ id: addresses.id })
      .from(addresses)
      .where(active(userId))
      .orderBy(desc(addresses.updatedAt))
      .limit(1);
    return row ?? null;
  },
};
