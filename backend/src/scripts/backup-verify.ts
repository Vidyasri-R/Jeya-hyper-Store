/**
 * Proves the backups restore: replays the newest backup chain into a scratch schema of the same
 * database, compares row counts with the live tables, then drops the scratch schema. Live
 * tables are only read.
 *
 *   npm run backup:verify                (newest month)
 *   npm run backup:verify -- 2026-10     (a given month)
 */
import { sql } from 'drizzle-orm';
import { closeDb, db } from '../db/client';
import { backupService } from '../modules/backup/backup.service';
import { BACKUP_TABLES } from '../modules/backup/backup.tables';

async function main() {
  const month = process.argv.slice(2).find((arg) => /^\d{4}-\d{2}$/.test(arg));
  const chain = await backupService.restoreChain(month);
  if (chain.length === 0) throw new Error('No complete backup found');
  console.log(`Restoring ${chain.length} set(s):\n${chain.map((key) => `  ${key}`).join('\n')}`);

  const schema = `restore_check_${Date.now().toString(36)}`;
  await db.execute(sql.raw(`create schema "${schema}"`));
  try {
    for (const spec of BACKUP_TABLES) {
      await db.execute(sql.raw(`create table "${schema}"."${spec.table}" (like public."${spec.table}" including all)`));
    }
    const restored = await backupService.restore(chain, schema);
    let problems = 0;
    console.log('\ntable                   restored   live');
    for (const spec of BACKUP_TABLES) {
      const [live] = await db.execute<{ n: number }>(
        sql`select count(*)::int as n from ${sql.raw(`public."${spec.table}"`)} ${spec.skipRows ? sql`where not (${spec.skipRows})` : sql``}`,
      );
      const got = restored[spec.table] ?? 0;
      // products: only the referenced / store-edited ones are in incrementals; the monthly full has all
      const expectAll = spec.table !== 'products' || chain.length === 1;
      const ok = !expectAll || got >= Number(live!.n);
      if (!ok) problems++;
      console.log(`${ok ? '✔' : '✘'} ${spec.table.padEnd(22)} ${String(got).padStart(8)} ${String(live!.n).padStart(6)}`);
    }
    console.log(problems === 0 ? '\n🎉 Backup restores completely.' : `\n❌ ${problems} table(s) restored fewer rows than live (rows added after the backup are expected to be missing).`);
    process.exitCode = problems === 0 ? 0 : 1;
  } finally {
    await db.execute(sql.raw(`drop schema "${schema}" cascade`));
  }
}

main()
  .catch((error: unknown) => {
    console.error('❌ verify failed:', error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => closeDb());
