import { createHash } from 'node:crypto';
import { createGzip, gunzipSync } from 'node:zlib';
import { sql, type SQL } from 'drizzle-orm';
import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { db, type DbExecutor } from '../../db/client';
import { syncState } from '../../db/schema';
import { r2 } from '../../infra/r2';
import { appConfigService } from '../app-config/app-config.service';
import { syncStateRepository } from '../sync/sync-state.repository';
import { BACKUP_TABLES, type BackupTable } from './backup.tables';

/**
 * Nightly database backup to a private R2 bucket (Supabase Free has no backups).
 *
 * Layout: db/<YYYY-MM>/<full|incremental>-<YYYYMMDD-HHMMSS IST>/<table>.ndjson.gz + manifest.json
 * One gzip'd JSON row per line. The manifest is written last, so a set without one never
 * finished and is ignored. The first run of each month is full; the others hold only rows
 * changed since the previous run (10 min overlap). Restoring = that month's full set, then each
 * later incremental, upserting by primary key. R2 deletes sets after 100 days (bucket rule).
 */
const STATE_CHAIN = 'backup_chain'; // watermark = DB time the last successful backup started
const STATE_FULL = 'backup_full'; // watermark = DB time the last successful FULL backup started
const OVERLAP_MS = 10 * 60 * 1000;
const PAGE_ROWS = 2000;
const RESTORE_BATCH = 500;
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
export const LAST_BACKUP_KEY = 'backup.last';

export type BackupKind = 'full' | 'incremental';
export type Manifest = {
  format: 1;
  kind: BackupKind;
  createdAt: string;
  since: string | null;
  migration: { id: number; hash: string } | null;
  tables: Record<string, { rows: number; bytes: number; sha256: string }>;
};

const ist = (at: Date) => new Date(at.getTime() + IST_OFFSET_MS).toISOString();
const monthOf = (at: Date) => ist(at).slice(0, 7);
const stampOf = (at: Date) => ist(at).slice(0, 19).replace(/[-:]/g, '').replace('T', '-');

export function backupsConfigured(): boolean {
  return Boolean(env.R2_BACKUP_BUCKET) && r2.isConfigured();
}

function bucket() {
  if (!backupsConfigured()) throw new Error('Backups are not configured (R2_BACKUP_BUCKET + R2 keys)');
  return r2.bucket(env.R2_BACKUP_BUCKET!);
}

async function dbNow(executor: DbExecutor = db): Promise<Date> {
  const [row] = await executor.execute<{ now: string }>(sql`select to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') as now`);
  return new Date(row!.now);
}

/** One table → gzip'd NDJSON, paged by primary key so memory stays flat on the 512 MB server. */
async function dumpTable(spec: BackupTable, filter: SQL | null) {
  const gzip = createGzip({ level: 9 });
  const chunks: Buffer[] = [];
  gzip.on('data', (chunk: Buffer) => chunks.push(chunk));
  const finished = new Promise<void>((resolve, reject) => {
    gzip.on('end', resolve);
    gzip.on('error', reject);
  });

  const table = sql.identifier(spec.table);
  const pk = sql.identifier(spec.pk);
  const json = spec.exclude?.length
    ? sql`(to_jsonb(t) - ${sql.raw(`array[${spec.exclude.map((column) => `'${column}'`).join(', ')}]`)}::text[])::text`
    : sql`to_jsonb(t)::text`;
  let last: string | null = null;
  let rows = 0;
  for (;;) {
    const conditions: SQL[] = [];
    if (filter) conditions.push(sql`(${filter})`);
    if (spec.skipRows) conditions.push(sql`not (${spec.skipRows})`);
    if (last !== null) conditions.push(sql`t.${pk} > ${last}::${sql.raw(spec.pkType)}`);
    const where = conditions.length ? sql`where ${sql.join(conditions, sql` and `)}` : sql``;
    const page = await db.execute<{ k: string; r: string }>(
      sql`select t.${pk}::text as k, ${json} as r from ${table} t ${where} order by t.${pk} limit ${PAGE_ROWS}`,
    );
    for (const row of page) {
      if (!gzip.write(`${row.r}\n`)) await new Promise((resolve) => gzip.once('drain', resolve));
    }
    rows += page.length;
    if (page.length < PAGE_ROWS) break;
    last = page.at(-1)!.k;
  }
  gzip.end();
  await finished;
  const body = Buffer.concat(chunks);
  return { body, rows, sha256: createHash('sha256').update(body).digest('hex') };
}

async function latestMigration(): Promise<Manifest['migration']> {
  try {
    const [row] = await db.execute<{ id: number; hash: string }>(sql`select id, hash from drizzle.__drizzle_migrations order by created_at desc limit 1`);
    return row ? { id: Number(row.id), hash: row.hash } : null;
  } catch {
    return null;
  }
}

async function ensureState(key: string) {
  await db.insert(syncState).values({ key }).onConflictDoNothing({ target: syncState.key });
}

export const backupService = {
  /** `auto`: full on the first run of a month (or when no chain exists), otherwise incremental. */
  async run(requested: 'auto' | BackupKind = 'auto') {
    if (!backupsConfigured()) {
      logger.warn('backup skipped: not configured');
      return { status: 'skipped' as const, reason: 'not_configured' };
    }
    const lease = await syncStateRepository.acquireLease(db, STATE_CHAIN);
    if (!lease) return { status: 'skipped' as const, reason: 'already_running' };

    try {
      const startedAt = await dbNow();
      await ensureState(STATE_FULL);
      const full = await syncStateRepository.get(db, STATE_FULL);
      const chainWatermark = lease.watermark;
      const needsFull = !chainWatermark || !full?.watermark || monthOf(full.watermark) !== monthOf(startedAt);
      const kind: BackupKind = requested === 'full' || needsFull ? 'full' : 'incremental';
      const since = kind === 'incremental' ? new Date(chainWatermark!.getTime() - OVERLAP_MS) : null;
      const setKey = `db/${monthOf(startedAt)}/${kind}-${stampOf(startedAt)}`;
      const target = bucket();

      const manifest: Manifest = { format: 1, kind, createdAt: startedAt.toISOString(), since: since?.toISOString() ?? null, migration: await latestMigration(), tables: {} };
      let totalRows = 0;
      let totalBytes = 0;
      for (const spec of BACKUP_TABLES) {
        if (kind === 'incremental' && spec.changed === 'full-only') continue;
        const filter = kind === 'full' || spec.changed === null || spec.changed === 'full-only' ? null : spec.changed(sql`${since!.toISOString()}::timestamptz`);
        const dump = await dumpTable(spec, filter);
        await target.put(`${setKey}/${spec.table}.ndjson.gz`, dump.body, { contentType: 'application/gzip', metadata: { rows: String(dump.rows) } });
        manifest.tables[spec.table] = { rows: dump.rows, bytes: dump.body.length, sha256: dump.sha256 };
        totalRows += dump.rows;
        totalBytes += dump.body.length;
      }
      await target.put(`${setKey}/manifest.json`, Buffer.from(JSON.stringify(manifest, null, 1)), { contentType: 'application/json' });

      await syncStateRepository.markSuccess(db, STATE_CHAIN, { watermark: startedAt, itemsProcessed: totalRows });
      if (kind === 'full') await syncStateRepository.markSuccess(db, STATE_FULL, { watermark: startedAt, itemsProcessed: totalRows });
      const summary = { key: setKey, kind, at: startedAt.toISOString(), rows: totalRows, bytes: totalBytes };
      await appConfigService.set(LAST_BACKUP_KEY, summary, { isPublic: false, description: 'Most recent database backup (written by the backup job).' });
      logger.info(summary, 'backup finished');
      return { status: 'success' as const, ...summary };
    } catch (error) {
      const message = error instanceof Error ? `${error.name}: ${error.message}` : String(error);
      await syncStateRepository.markFailure(db, STATE_CHAIN, message);
      logger.error({ err: error }, 'backup failed');
      throw error;
    }
  },

  /** Complete sets (with a manifest), newest first. */
  async listSets(prefix = 'db/') {
    const objects = await bucket().list(prefix);
    const sets = new Map<string, { key: string; bytes: number; complete: boolean; at: Date | null }>();
    for (const object of objects) {
      const setKey = object.key.slice(0, object.key.lastIndexOf('/'));
      const set = sets.get(setKey) ?? { key: setKey, bytes: 0, complete: false, at: object.lastModified };
      set.bytes += object.size;
      if (object.key.endsWith('/manifest.json')) set.complete = true;
      sets.set(setKey, set);
    }
    return [...sets.values()].filter((set) => set.complete).sort((a, b) => (a.key < b.key ? 1 : -1));
  },

  /** The sets needed to rebuild the latest state of `month` (default: newest month with a full set). */
  async restoreChain(month?: string) {
    const sets = await backupService.listSets(month ? `db/${month}/` : 'db/');
    const byMonth = new Map<string, string[]>();
    for (const set of sets) {
      const m = set.key.split('/')[1]!;
      byMonth.set(m, [...(byMonth.get(m) ?? []), set.key]);
    }
    for (const m of [...byMonth.keys()].sort().reverse()) {
      // set names end in -YYYYMMDD-HHMMSS, so sorting on that suffix orders them in time
      const keys = byMonth.get(m)!.sort((a, b) => (a.slice(-15) < b.slice(-15) ? -1 : 1));
      const fullIndex = keys.findLastIndex((key) => key.split('/')[2]!.startsWith('full-'));
      if (fullIndex >= 0) return keys.slice(fullIndex);
    }
    return [];
  },

  /**
   * Replays a chain into `schema` (tables must already exist there), upserting by primary key.
   * Used by `npm run backup:verify` (scratch schema) and for a real restore into a fresh database.
   */
  async restore(chain: string[], schema: string, executor: DbExecutor = db) {
    const source = bucket();
    const restored: Record<string, Set<string>> = {};
    for (const setKey of chain) {
      const manifest = JSON.parse((await source.get(`${setKey}/manifest.json`)).toString('utf8')) as Manifest;
      for (const spec of BACKUP_TABLES) {
        const meta = manifest.tables[spec.table];
        if (!meta) continue;
        const gz = await source.get(`${setKey}/${spec.table}.ndjson.gz`);
        if (createHash('sha256').update(gz).digest('hex') !== meta.sha256) throw new Error(`checksum mismatch: ${setKey}/${spec.table}`);
        const lines = gunzipSync(gz).toString('utf8').split('\n').filter(Boolean);
        if (lines.length !== meta.rows) throw new Error(`row count mismatch: ${setKey}/${spec.table} (${lines.length} vs ${meta.rows})`);

        const columns = await executor.execute<{ column_name: string; is_identity: string }>(sql`
          select column_name, is_identity from information_schema.columns
           where table_schema = ${schema} and table_name = ${spec.table} and is_generated = 'NEVER'
           order by ordinal_position`);
        const names = columns.map((column) => column.column_name);
        const identity = columns.some((column) => column.is_identity === 'YES');
        const qualified = sql.raw(`"${schema}"."${spec.table}"`);
        const list = sql.raw(names.map((name) => `"${name}"`).join(', '));
        const updates = sql.raw(names.filter((name) => name !== spec.pk).map((name) => `"${name}" = excluded."${name}"`).join(', '));
        const keys = (restored[spec.table] ??= new Set<string>());
        for (let i = 0; i < lines.length; i += RESTORE_BATCH) {
          const batch = lines.slice(i, i + RESTORE_BATCH);
          await executor.execute(sql`
            insert into ${qualified} (${list}) ${identity ? sql`overriding system value` : sql``}
            select ${list} from jsonb_populate_recordset(null::${qualified}, ${`[${batch.join(',')}]`}::jsonb)
            on conflict ("${sql.raw(spec.pk)}") do update set ${updates}`);
          for (const line of batch) keys.add(String((JSON.parse(line) as Record<string, unknown>)[spec.pk]));
        }
        if (identity) {
          await executor.execute(sql`select setval(pg_get_serial_sequence(${`"${schema}"."${spec.table}"`}, ${spec.pk}), coalesce((select max(${sql.identifier(spec.pk)}) from ${qualified}), 1))`);
        }
      }
    }
    return Object.fromEntries(Object.entries(restored).map(([table, keys]) => [table, keys.size]));
  },

  async status() {
    const [chain, last] = await Promise.all([syncStateRepository.get(db, STATE_CHAIN), appConfigService.getRaw(LAST_BACKUP_KEY)]);
    return {
      configured: backupsConfigured(),
      lastSuccessAt: chain?.lastSuccessAt ?? null,
      lastRunAt: chain?.lastRunFinishedAt ?? null,
      consecutiveFailures: chain?.consecutiveFailures ?? 0,
      lastError: chain?.status === 'failed' ? chain.lastError : null,
      last: (last as { key: string; kind: BackupKind; at: string; rows: number; bytes: number } | undefined) ?? null,
    };
  },
};
