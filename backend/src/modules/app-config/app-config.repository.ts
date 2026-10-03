import { eq, sql } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { appConfig } from '../../db/schema';

export const appConfigRepository = {
  async findAll(db: DbExecutor) {
    return db.select().from(appConfig);
  },

  async upsert(db: DbExecutor, key: string, value: unknown, meta: { isPublic: boolean; description: string }) {
    await db
      .insert(appConfig)
      .values({ key, value, isPublic: meta.isPublic, description: meta.description })
      .onConflictDoUpdate({ target: appConfig.key, set: { value: sql`excluded."value"`, updatedAt: sql`now()` } });
  },

  async findPublic(db: DbExecutor) {
    return db
      .select({ key: appConfig.key, value: appConfig.value })
      .from(appConfig)
      .where(eq(appConfig.isPublic, true));
  },
};
