import { eq, sql } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { syncState } from '../../db/schema';

/** A run holding the lease longer than this is considered crashed and can be taken over. */
const LEASE_TIMEOUT = sql`interval '30 minutes'`;

export const syncStateRepository = {
  async get(db: DbExecutor, key: string) {
    const [row] = await db.select().from(syncState).where(eq(syncState.key, key)).limit(1);
    return row ?? null;
  },

  async list(db: DbExecutor) {
    return db.select().from(syncState).orderBy(syncState.key);
  },

  /**
   * Atomically claims the run. Works on the transaction pooler (no session locks):
   * the conditional UPDATE is the lock. Returns null if another run holds it.
   */
  async acquireLease(db: DbExecutor, key: string) {
    await db.insert(syncState).values({ key }).onConflictDoNothing({ target: syncState.key });
    const [row] = await db
      .update(syncState)
      .set({ status: 'running', lastRunStartedAt: sql`now()`, lastError: null })
      .where(
        sql`${syncState.key} = ${key}
            AND (${syncState.status} <> 'running' OR ${syncState.lastRunStartedAt} < now() - ${LEASE_TIMEOUT})`,
      )
      .returning();
    return row ?? null;
  },

  async markSuccess(db: DbExecutor, key: string, values: { watermark: Date | null; itemsProcessed: number }) {
    await db
      .update(syncState)
      .set({
        status: 'success',
        watermark: values.watermark,
        itemsProcessed: values.itemsProcessed,
        lastRunFinishedAt: sql`now()`,
        lastSuccessAt: sql`now()`,
        consecutiveFailures: 0,
        lastError: null,
      })
      .where(eq(syncState.key, key));
  },

  async markFailure(db: DbExecutor, key: string, error: string) {
    await db
      .update(syncState)
      .set({
        status: 'failed',
        lastError: error.slice(0, 2000),
        lastRunFinishedAt: sql`now()`,
        consecutiveFailures: sql`${syncState.consecutiveFailures} + 1`,
      })
      .where(eq(syncState.key, key));
  },
};
