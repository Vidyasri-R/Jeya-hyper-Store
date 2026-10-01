import 'dotenv/config';
import { z } from 'zod';

/**
 * Prisma-only URL params that postgres.js would otherwise forward to the server
 * as startup parameters (Supavisor rejects unknown ones).
 */
const PRISMA_ONLY_PARAMS = ['pgbouncer', 'connection_limit', 'pool_timeout', 'schema'];

function sanitizePostgresUrl(raw: string): string {
  const url = new URL(raw);
  for (const param of PRISMA_ONLY_PARAMS) url.searchParams.delete(param);
  return url.toString();
}

const postgresUrl = z
  .string()
  .min(1)
  .refine((value) => {
    try {
      const { protocol } = new URL(value);
      return protocol === 'postgres:' || protocol === 'postgresql:';
    } catch {
      return false;
    }
  }, 'must be a postgres:// or postgresql:// URL')
  .transform(sanitizePostgresUrl);

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(4000),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  CORS_ORIGINS: z
    .string()
    .default('')
    .transform((value) =>
      value
        .split(',')
        .map((origin) => origin.trim())
        .filter(Boolean),
    ),

  DATABASE_URL: postgresUrl.refine(
    (value) => new URL(value).port === '6543',
    'DATABASE_URL must point at the Supavisor transaction pooler (port 6543)',
  ),
  DIRECT_DATABASE_URL: postgresUrl,
  DB_POOL_MAX: z.coerce.number().int().min(1).max(50).default(10),
});

export type Env = z.infer<typeof envSchema>;

function loadEnv(): Env {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((issue) => `  • ${issue.path.join('.') || '(root)'}: ${issue.message}`)
      .join('\n');
    // Logger depends on env, so fail loudly on stderr before anything else boots.
    process.stderr.write(`\n❌ Invalid environment configuration:\n${issues}\n\n`);
    process.exit(1);
  }
  return Object.freeze(parsed.data);
}

export const env = loadEnv();
export const isProduction = env.NODE_ENV === 'production';
