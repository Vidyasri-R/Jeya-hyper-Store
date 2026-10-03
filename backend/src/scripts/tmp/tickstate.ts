import { sql } from 'drizzle-orm';
import { closeDb, db } from '../../db/client';
import { syncState, usageDaily } from '../../db/schema';
async function main() {
  const [t] = await db.select().from(syncState).where(sql`${syncState.key} = 'monitor_tick'`);
  const [u] = await db.select({ updated: usageDaily.updatedAt, r2: usageDaily.r2StorageBytes, objs: usageDaily.r2ObjectCount, size: usageDaily.dbSizeBytes }).from(usageDaily).where(sql`${usageDaily.day} = (select max(day) from usage_daily)`);
  console.log(JSON.stringify({ tick: t ? { status: t.status, finished: t.lastRunFinishedAt, err: t.lastError } : null, usage: u }));
}
main().finally(() => closeDb());
