import { eq } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { appConfig } from '../../db/schema';

export const appConfigRepository = {
  async findAll(db: DbExecutor) {
    return db.select().from(appConfig);
  },

  async findPublic(db: DbExecutor) {
    return db
      .select({ key: appConfig.key, value: appConfig.value })
      .from(appConfig)
      .where(eq(appConfig.isPublic, true));
  },
};
