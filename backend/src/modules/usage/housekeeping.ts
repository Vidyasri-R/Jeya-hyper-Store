import { sql } from 'drizzle-orm';
import { logger } from '../../config/logger';
import { db } from '../../db/client';

/**
 * Nightly clean-up so the Supabase Free database (500 MB) holds business data, not logs.
 * Orders, payments, refunds, customers and their history are never touched.
 */
const RULES: { table: string; where: ReturnType<typeof sql> }[] = [
  { table: 'otp_requests', where: sql`created_at < now() - interval '30 days'` },
  { table: 'user_sessions', where: sql`coalesce(revoked_at, expires_at) < now() - interval '30 days'` },
  { table: 'staff_sessions', where: sql`coalesce(revoked_at, expires_at) < now() - interval '30 days'` },
  // Kept 90 days for dispute look-ups; the payment/refund rows themselves stay forever.
  { table: 'payment_webhook_events', where: sql`processed_at is not null and received_at < now() - interval '90 days'` },
  { table: 'admin_alerts', where: sql`resolved_at < now() - interval '180 days'` },
  { table: 'usage_daily', where: sql`day < (now() - interval '400 days')::date` },
];

export async function runHousekeeping(): Promise<Record<string, number>> {
  const deleted: Record<string, number> = {};
  for (const rule of RULES) {
    const rows = await db.execute<{ n: number }>(
      sql`with gone as (delete from ${sql.identifier(rule.table)} where ${rule.where} returning 1) select count(*)::int as n from gone`,
    );
    deleted[rule.table] = Number(rows[0]?.n ?? 0);
  }
  logger.info({ deleted }, 'housekeeping done');
  return deleted;
}
