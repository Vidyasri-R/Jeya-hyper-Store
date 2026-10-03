/**
 * Applies pending migrations from ./drizzle using the DIRECT (session pooler) URL.
 *
 *   npm run db:migrate          (local, via tsx)
 *   npm run db:migrate:prod     (Render pre-deploy command, from dist/)
 *
 * Takes a session-level advisory lock so two deploys running at once can't
 * apply the same migration twice. That's why this must NOT use the 6543 pooler.
 */
import path from 'node:path';
import { drizzle } from 'drizzle-orm/postgres-js';
import { migrate } from 'drizzle-orm/postgres-js/migrator';
import postgres from 'postgres';
import { env } from '../config/env';
import { logger } from '../config/logger';

const MIGRATION_LOCK_ID = 727_001; // arbitrary constant, unique to this app
const migrationsFolder = path.resolve(__dirname, '../../drizzle');

async function run(): Promise<void> {
  const port = new URL(env.DIRECT_DATABASE_URL).port;
  if (port === '6543') {
    throw new Error('DIRECT_DATABASE_URL points at the transaction pooler (6543); use the session pooler (5432).');
  }

  const client = postgres(env.DIRECT_DATABASE_URL, {
    max: 1,
    ssl: 'require',
    connect_timeout: 15,
    onnotice: () => {},
    connection: { application_name: 'jeya-migrate', lock_timeout: 10_000 },
  });

  const startedAt = Date.now();
  try {
    logger.info({ migrationsFolder }, 'acquiring migration lock');
    await client`select pg_advisory_lock(${MIGRATION_LOCK_ID})`;

    await migrate(drizzle(client), { migrationsFolder });

    logger.info({ ms: Date.now() - startedAt }, '✅ migrations applied');
  } finally {
    await client`select pg_advisory_unlock(${MIGRATION_LOCK_ID})`.catch(() => undefined);
    await client.end({ timeout: 5 });
  }
}

// Render pre-deploy step: always finish (see scripts/seed.ts), and never sit on a stuck lock forever.
setTimeout(() => {
  logger.fatal('❌ migration still running after 5 minutes — exiting');
  logger.flush?.();
  process.exit(1);
}, 300_000).unref();

run()
  .catch((error: unknown) => {
    logger.fatal({ err: error }, '❌ migration failed');
    process.exitCode = 1;
  })
  .finally(() => {
    logger.flush?.();
    process.exit(Number(process.exitCode ?? 0));
  });
