import { and, desc, eq, gte, isNull, lte, sql } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { adminAlerts, payments, syncState, usageDaily, type AlertLevel } from '../../db/schema';
import type { TrafficDelta } from '../../infra/traffic';

export const usageRepository = {
  /** Adds the drained traffic to today's row (created on first write of the day). */
  async addTraffic(db: DbExecutor, day: string, delta: TrafficDelta, rssBytes: number) {
    await db
      .insert(usageDaily)
      .values({
        day,
        dbEgressBytes: delta.dbIn,
        dbIngressBytes: delta.dbOut,
        httpOutBytes: delta.httpOut,
        httpInBytes: delta.httpIn,
        httpRequests: delta.httpRequests,
        r2UploadBytes: delta.r2UploadBytes,
        r2ClassAOps: delta.r2ClassAOps,
        peakRssBytes: rssBytes,
      })
      .onConflictDoUpdate({
        target: usageDaily.day,
        set: {
          dbEgressBytes: sql`${usageDaily.dbEgressBytes} + excluded."db_egress_bytes"`,
          dbIngressBytes: sql`${usageDaily.dbIngressBytes} + excluded."db_ingress_bytes"`,
          httpOutBytes: sql`${usageDaily.httpOutBytes} + excluded."http_out_bytes"`,
          httpInBytes: sql`${usageDaily.httpInBytes} + excluded."http_in_bytes"`,
          httpRequests: sql`${usageDaily.httpRequests} + excluded."http_requests"`,
          r2UploadBytes: sql`${usageDaily.r2UploadBytes} + excluded."r2_upload_bytes"`,
          r2ClassAOps: sql`${usageDaily.r2ClassAOps} + excluded."r2_class_a_ops"`,
          peakRssBytes: sql`greatest(${usageDaily.peakRssBytes}, excluded."peak_rss_bytes")`,
          updatedAt: sql`now()`,
        },
      });
  },

  async setSizes(db: DbExecutor, day: string, sizes: { dbSizeBytes?: number; r2StorageBytes?: number; r2ObjectCount?: number }) {
    await db
      .insert(usageDaily)
      .values({ day, ...sizes })
      .onConflictDoUpdate({ target: usageDaily.day, set: { ...sizes, updatedAt: sql`now()` } });
  },

  async range(db: DbExecutor, fromDay: string, toDay: string) {
    return db
      .select()
      .from(usageDaily)
      .where(and(gte(usageDaily.day, fromDay), lte(usageDaily.day, toDay)))
      .orderBy(usageDaily.day);
  },

  /** Latest known sizes (they're sampled hourly/daily, so today's row may not have them yet). */
  async latestSizes(db: DbExecutor) {
    const [row] = await db.execute<{ db_size: string | null; r2_storage: string | null; r2_objects: number | null }>(sql`
      select (select db_size_bytes from usage_daily where db_size_bytes is not null order by day desc limit 1) as db_size,
             (select r2_storage_bytes from usage_daily where r2_storage_bytes is not null order by day desc limit 1) as r2_storage,
             (select r2_object_count from usage_daily where r2_object_count is not null order by day desc limit 1) as r2_objects`);
    return {
      dbSizeBytes: row?.db_size != null ? Number(row.db_size) : null,
      r2StorageBytes: row?.r2_storage != null ? Number(row.r2_storage) : null,
      r2ObjectCount: row?.r2_objects != null ? Number(row.r2_objects) : null,
    };
  },

  /** What Supabase measures for the 500 MB limit. */
  async databaseSize(db: DbExecutor): Promise<number> {
    const [row] = await db.execute<{ size: string }>(sql`select pg_database_size(current_database())::bigint as size`);
    return Number(row?.size ?? 0);
  },

  async largestTables(db: DbExecutor, limit = 8) {
    const rows = await db.execute<{ name: string; bytes: string; rows: string }>(sql`
      select c.relname as name, pg_total_relation_size(c.oid)::bigint as bytes, greatest(c.reltuples, 0)::bigint as rows
        from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind = 'r'
       order by pg_total_relation_size(c.oid) desc
       limit ${limit}`);
    return rows.map((row) => ({ name: row.name, bytes: Number(row.bytes), rows: Number(row.rows) }));
  },

  async razorpayFees(db: DbExecutor, since: Date) {
    const [row] = await db
      .select({
        payments: sql<number>`count(*)::int`,
        amount: sql<string>`coalesce(sum(${payments.amount}), 0)::numeric(14,2)`,
        fee: sql<string>`coalesce(sum(${payments.gatewayFee}), 0)::numeric(14,2)`,
        tax: sql<string>`coalesce(sum(${payments.gatewayTax}), 0)::numeric(14,2)`,
        missingFee: sql<number>`count(*) filter (where ${payments.gatewayFee} is null)::int`,
      })
      .from(payments)
      .where(and(eq(payments.status, 'captured'), gte(payments.capturedAt, since)));
    return row!;
  },

  async syncHealth(db: DbExecutor) {
    return db
      .select({ key: syncState.key, status: syncState.status, consecutiveFailures: syncState.consecutiveFailures, lastSuccessAt: syncState.lastSuccessAt, lastError: syncState.lastError })
      .from(syncState);
  },

  // ── alerts ──
  async openAlerts(db: DbExecutor) {
    return db.select().from(adminAlerts).where(isNull(adminAlerts.resolvedAt)).orderBy(desc(adminAlerts.createdAt));
  },

  async recentAlerts(db: DbExecutor, limit: number) {
    return db.select().from(adminAlerts).orderBy(desc(adminAlerts.createdAt)).limit(limit);
  },

  async insertAlert(db: DbExecutor, values: { metric: string; level: AlertLevel; title: string; message: string; data: unknown }) {
    const [row] = await db.insert(adminAlerts).values(values).onConflictDoNothing().returning();
    return row ?? null;
  },

  async updateAlert(db: DbExecutor, id: number, patch: Partial<typeof adminAlerts.$inferInsert>) {
    await db.update(adminAlerts).set(patch).where(eq(adminAlerts.id, id));
  },

  async acknowledge(db: DbExecutor, id: number, staffId: string) {
    const [row] = await db
      .update(adminAlerts)
      .set({ acknowledgedAt: sql`now()`, acknowledgedBy: staffId })
      .where(eq(adminAlerts.id, id))
      .returning({ id: adminAlerts.id });
    return row ?? null;
  },
};
