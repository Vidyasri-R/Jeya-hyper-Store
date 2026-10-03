import { and, asc, eq, gt, inArray, isNull, ne, or, sql } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { staffSessions, staffUsers, type NewStaffUser, type StaffUser } from '../../db/schema';

/** How long a just-replaced refresh token still works (the app may close before saving the new one). */
const REFRESH_GRACE = '2 minutes';

export type StaffSessionState = {
  sessionId: string;
  staffId: string;
  role: StaffUser['role'];
  isActive: boolean;
  mustChangePassword: boolean;
};

export const staffRepository = {
  async findByUsername(db: DbExecutor, username: string) {
    const [row] = await db.select().from(staffUsers).where(eq(staffUsers.username, username)).limit(1);
    return row ?? null;
  },

  async findById(db: DbExecutor, id: string) {
    const [row] = await db.select().from(staffUsers).where(eq(staffUsers.id, id)).limit(1);
    return row ?? null;
  },

  async list(db: DbExecutor) {
    return db.select().from(staffUsers).orderBy(asc(staffUsers.role), asc(staffUsers.name));
  },

  async insert(db: DbExecutor, values: NewStaffUser) {
    const [row] = await db.insert(staffUsers).values(values).returning();
    if (!row) throw new Error('staff insert returned no row');
    return row;
  },

  async update(db: DbExecutor, id: string, patch: Partial<NewStaffUser>) {
    const [row] = await db.update(staffUsers).set(patch).where(eq(staffUsers.id, id)).returning();
    return row ?? null;
  },

  async countActiveAdmins(db: DbExecutor, excludeId?: string): Promise<number> {
    const [row] = await db
      .select({ count: sql<number>`count(*)::int` })
      .from(staffUsers)
      .where(
        and(
          eq(staffUsers.role, 'admin'),
          eq(staffUsers.isActive, true),
          excludeId ? ne(staffUsers.id, excludeId) : undefined,
        ),
      );
    return Number(row?.count ?? 0);
  },

  /**
   * One atomic statement: count the failure and, on reaching the limit, lock the account
   * and start counting afresh — so parallel guesses can't slip past the limit.
   */
  async recordFailedLogin(db: DbExecutor, id: string, maxFailures: number, lockMinutes: number) {
    const [row] = await db
      .update(staffUsers)
      .set({
        failedLoginCount: sql`case when ${staffUsers.failedLoginCount} + 1 >= ${maxFailures} then 0 else ${staffUsers.failedLoginCount} + 1 end`,
        lockedUntil: sql`case when ${staffUsers.failedLoginCount} + 1 >= ${maxFailures}
                              then now() + make_interval(mins => ${lockMinutes}) else ${staffUsers.lockedUntil} end`,
      })
      .where(eq(staffUsers.id, id))
      .returning({ lockedUntil: staffUsers.lockedUntil });
    return { lockedUntil: row?.lockedUntil ?? null };
  },

  async recordSuccessfulLogin(db: DbExecutor, id: string) {
    await db
      .update(staffUsers)
      .set({ failedLoginCount: 0, lockedUntil: null, lastLoginAt: sql`now()` })
      .where(eq(staffUsers.id, id));
  },

  async createSession(db: DbExecutor, values: typeof staffSessions.$inferInsert) {
    const [row] = await db.insert(staffSessions).values(values).returning();
    if (!row) throw new Error('staff session insert returned no row');
    return row;
  },

  /** Refresh-token rotation in one statement (same contract as the customer sessions, grace window included). */
  async rotateSession(db: DbExecutor, currentHash: string, nextHash: string, nextExpiresAt: Date) {
    const isCurrent = sql`${staffSessions.refreshTokenHash} = ${currentHash}`;
    const [row] = await db
      .update(staffSessions)
      .set({
        previousRefreshTokenHash: sql`case when ${isCurrent} then ${currentHash} else ${staffSessions.previousRefreshTokenHash} end`,
        rotatedAt: sql`case when ${isCurrent} then now() else ${staffSessions.rotatedAt} end`,
        refreshTokenHash: nextHash,
        expiresAt: nextExpiresAt,
        lastUsedAt: sql`now()`,
      })
      .where(
        and(
          or(
            eq(staffSessions.refreshTokenHash, currentHash),
            and(eq(staffSessions.previousRefreshTokenHash, currentHash), gt(staffSessions.rotatedAt, sql`now() - ${REFRESH_GRACE}::interval`)),
          ),
          isNull(staffSessions.revokedAt),
          gt(staffSessions.expiresAt, sql`now()`),
          sql`exists (select 1 from ${staffUsers} where ${staffUsers.id} = ${staffSessions.staffId} and ${staffUsers.isActive})`,
        ),
      )
      .returning({ id: staffSessions.id, staffId: staffSessions.staffId });
    return row ?? null;
  },

  async revokeSessionByHash(db: DbExecutor, hash: string) {
    const [row] = await db
      .update(staffSessions)
      .set({ revokedAt: sql`now()` })
      .where(and(eq(staffSessions.refreshTokenHash, hash), isNull(staffSessions.revokedAt)))
      .returning({ id: staffSessions.id });
    return row?.id ?? null;
  },

  async revokeAllSessions(db: DbExecutor, staffId: string) {
    await db
      .update(staffSessions)
      .set({ revokedAt: sql`now()` })
      .where(and(eq(staffSessions.staffId, staffId), isNull(staffSessions.revokedAt)));
  },

  /** What every staff request is authorised against: the live session + account state. */
  async sessionState(db: DbExecutor, sessionId: string): Promise<StaffSessionState | null> {
    const [row] = await db
      .select({
        sessionId: staffSessions.id,
        staffId: staffUsers.id,
        role: staffUsers.role,
        isActive: staffUsers.isActive,
        mustChangePassword: staffUsers.mustChangePassword,
      })
      .from(staffSessions)
      .innerJoin(staffUsers, eq(staffUsers.id, staffSessions.staffId))
      .where(and(eq(staffSessions.id, sessionId), isNull(staffSessions.revokedAt), gt(staffSessions.expiresAt, sql`now()`)))
      .limit(1);
    return row ?? null;
  },

  async names(db: DbExecutor, ids: string[]) {
    if (ids.length === 0) return new Map<string, string>();
    const rows = await db
      .select({ id: staffUsers.id, name: staffUsers.name })
      .from(staffUsers)
      .where(inArray(staffUsers.id, ids));
    return new Map(rows.map((row) => [row.id, row.name]));
  },
};
