import { and, desc, eq, gt, isNull, sql } from 'drizzle-orm';
import type { DbExecutor, Transaction } from '../../db/client';
import { otpRequests, userSessions, users } from '../../db/schema';

export const authRepository = {
  /**
   * Serialises OTP issuance per phone for the rest of the transaction, so two
   * concurrent requests can't both slip past the cooldown. Transaction-scoped,
   * so it's safe on the Supavisor transaction pooler.
   */
  async lockPhone(tx: Transaction, phone: string): Promise<void> {
    await tx.execute(sql`select pg_advisory_xact_lock(hashtext(${`otp:${phone}`}))`);
  },

  async otpIssueStats(db: DbExecutor, phone: string, ipAddress: string | null, since: Date) {
    const [row] = await db
      .select({
        phoneCount: sql<number>`count(*) filter (where ${otpRequests.phone} = ${phone})::int`,
        ipCount: ipAddress
          ? sql<number>`count(*) filter (where ${otpRequests.ipAddress} = ${ipAddress})::int`
          : sql<number>`0`,
        lastForPhone: sql<Date | null>`max(${otpRequests.createdAt}) filter (where ${otpRequests.phone} = ${phone})`,
      })
      .from(otpRequests)
      .where(
        and(
          gt(otpRequests.createdAt, since),
          ipAddress
            ? sql`(${otpRequests.phone} = ${phone} or ${otpRequests.ipAddress} = ${ipAddress})`
            : eq(otpRequests.phone, phone),
        ),
      );
    return {
      phoneCount: Number(row?.phoneCount ?? 0),
      ipCount: Number(row?.ipCount ?? 0),
      lastForPhone: row?.lastForPhone ? new Date(row.lastForPhone) : null,
    };
  },

  /** Only the newest OTP for a phone is ever valid — older unused codes die on resend. */
  async expireActiveOtpsForPhone(db: DbExecutor, phone: string) {
    await db
      .update(otpRequests)
      .set({ expiresAt: sql`now()` })
      .where(
        and(eq(otpRequests.phone, phone), isNull(otpRequests.consumedAt), gt(otpRequests.expiresAt, sql`now()`)),
      );
  },

  async insertOtp(db: DbExecutor, values: typeof otpRequests.$inferInsert) {
    const [row] = await db.insert(otpRequests).values(values).returning({ id: otpRequests.id });
    if (!row) throw new Error('otp insert returned no row');
    return row;
  },

  async setOtpProviderMessageId(db: DbExecutor, id: string, providerMessageId: string | null) {
    await db.update(otpRequests).set({ providerMessageId }).where(eq(otpRequests.id, id));
  },

  /** Expire an OTP immediately (delivery failed, so it can't be used). */
  async expireOtp(db: DbExecutor, id: string) {
    await db.update(otpRequests).set({ expiresAt: sql`now()` }).where(eq(otpRequests.id, id));
  },

  async findLatestActiveOtp(db: DbExecutor, phone: string) {
    const [row] = await db
      .select()
      .from(otpRequests)
      .where(
        and(eq(otpRequests.phone, phone), isNull(otpRequests.consumedAt), gt(otpRequests.expiresAt, sql`now()`)),
      )
      .orderBy(desc(otpRequests.createdAt))
      .limit(1);
    return row ?? null;
  },

  /** Atomic increment; returns the new attempt count. */
  async incrementOtpAttempts(db: DbExecutor, id: string): Promise<number> {
    const [row] = await db
      .update(otpRequests)
      .set({ attempts: sql`${otpRequests.attempts} + 1` })
      .where(eq(otpRequests.id, id))
      .returning({ attempts: otpRequests.attempts });
    return row?.attempts ?? Number.MAX_SAFE_INTEGER;
  },

  /** Single-use guarantee: only one concurrent verify can flip consumed_at. */
  async consumeOtp(db: DbExecutor, id: string): Promise<boolean> {
    const rows = await db
      .update(otpRequests)
      .set({ consumedAt: sql`now()` })
      .where(and(eq(otpRequests.id, id), isNull(otpRequests.consumedAt)))
      .returning({ id: otpRequests.id });
    return rows.length === 1;
  },

  async findActiveUserByPhone(db: DbExecutor, phone: string) {
    const [row] = await db
      .select()
      .from(users)
      .where(and(eq(users.phone, phone), isNull(users.deletedAt)))
      .limit(1);
    return row ?? null;
  },

  async findActiveUserById(db: DbExecutor, id: string) {
    const [row] = await db
      .select()
      .from(users)
      .where(and(eq(users.id, id), isNull(users.deletedAt)))
      .limit(1);
    return row ?? null;
  },

  /** Race-safe "get or create" on the partial unique index users_phone_active_uq. */
  async findOrCreateUserByPhone(db: DbExecutor, phone: string) {
    const [created] = await db
      .insert(users)
      .values({ phone })
      .onConflictDoNothing({ target: users.phone, where: sql`${users.deletedAt} IS NULL` })
      .returning();
    if (created) return { user: created, isNewUser: true };

    const existing = await authRepository.findActiveUserByPhone(db, phone);
    if (!existing) throw new Error('user upsert found neither inserted nor existing row');
    return { user: existing, isNewUser: false };
  },

  async touchLastLogin(db: DbExecutor, userId: string) {
    await db.update(users).set({ lastLoginAt: sql`now()` }).where(eq(users.id, userId));
  },

  async createSession(db: DbExecutor, values: typeof userSessions.$inferInsert) {
    const [row] = await db.insert(userSessions).values(values).returning();
    if (!row) throw new Error('session insert returned no row');
    return row;
  },

  /**
   * Refresh-token rotation in one statement: swaps the hash only if the presented
   * token is current, unrevoked and unexpired, and the user is still active.
   * A replayed (already-rotated) token matches nothing.
   */
  async rotateSession(db: DbExecutor, currentHash: string, nextHash: string, nextExpiresAt: Date) {
    const [row] = await db
      .update(userSessions)
      .set({ refreshTokenHash: nextHash, expiresAt: nextExpiresAt, lastUsedAt: sql`now()` })
      .where(
        and(
          eq(userSessions.refreshTokenHash, currentHash),
          isNull(userSessions.revokedAt),
          gt(userSessions.expiresAt, sql`now()`),
          sql`exists (select 1 from ${users} where ${users.id} = ${userSessions.userId}
                      and ${users.deletedAt} is null and ${users.isBlocked} = false)`,
        ),
      )
      .returning({ id: userSessions.id, userId: userSessions.userId });
    return row ?? null;
  },

  async revokeSessionByHash(db: DbExecutor, hash: string) {
    await db
      .update(userSessions)
      .set({ revokedAt: sql`now()` })
      .where(and(eq(userSessions.refreshTokenHash, hash), isNull(userSessions.revokedAt)));
  },

  async revokeAllSessionsForUser(db: DbExecutor, userId: string) {
    await db
      .update(userSessions)
      .set({ revokedAt: sql`now()` })
      .where(and(eq(userSessions.userId, userId), isNull(userSessions.revokedAt)));
  },
};
