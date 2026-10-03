import { drizzle } from 'drizzle-orm/postgres-js';
import postgres from 'postgres';
import { env } from '../config/env';
import { logger } from '../config/logger';
import { traffic } from '../infra/traffic';
import * as schema from './schema';

/**
 * App connection → Supavisor transaction pooler (port 6543).
 *
 * `prepare: false` is mandatory: in transaction mode each statement may land on a
 * different backend, so named prepared statements break. For the same reason do NOT
 * use session-level features (SET without LOCAL, LISTEN, pg_advisory_lock) on `db`;
 * use transaction-scoped variants (SET LOCAL, pg_try_advisory_xact_lock) instead.
 */
export const sqlClient = postgres(env.DATABASE_URL, {
  // Counted TCP sockets: Supabase Free bills egress (5 GB/month) — see infra/traffic.ts.
  // (`socket` is a supported postgres.js option that its type definitions don't declare.)
  ...({ socket: traffic.dbSocket } as object),
  prepare: false,
  ssl: 'require',
  max: env.DB_POOL_MAX,
  // Every new connection costs ~16 KB of TLS handshake + auth on the wire (measured), which
  // counts toward Supabase egress and Render bandwidth. Keep idle connections around instead
  // of reconnecting for each sporadic request; TCP keepalive holds them open through NAT.
  idle_timeout: 10 * 60,
  connect_timeout: 10,
  max_lifetime: 2 * 60 * 60,
  onnotice: (notice) => logger.debug({ notice: notice.message }, 'postgres notice'),
  connection: {
    application_name: 'jeya-api',
    // Guard rail so a bad query can't pin a pooler connection forever.
    statement_timeout: 15_000,
  },
});

export const db = drizzle(sqlClient, { schema, casing: 'snake_case' });

export type Database = typeof db;
export type Transaction = Parameters<Parameters<Database['transaction']>[0]>[0];
/** Accept either the root db or an open transaction in repositories. */
export type DbExecutor = Database | Transaction;

export async function pingDb(): Promise<void> {
  await sqlClient`select 1`;
}

export async function closeDb(): Promise<void> {
  await sqlClient.end({ timeout: 5 });
}
