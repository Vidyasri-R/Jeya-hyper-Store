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

  // ─── Auth ───
  JWT_ACCESS_SECRET: z.string().min(32, 'must be at least 32 characters'),
  ACCESS_TOKEN_TTL_SEC: z.coerce.number().int().min(60).max(86_400).default(900),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).max(365).default(60),

  // ─── OTP ───
  /** Server-side secret mixed into OTP hashes so a DB leak doesn't expose codes. */
  OTP_PEPPER: z.string().min(32, 'must be at least 32 characters'),
  /** `console` logs codes (dev only — refused for real numbers in production). WhatsApp comes next. */
  OTP_PROVIDER: z.enum(['console']).default('console'),
  OTP_TTL_SEC: z.coerce.number().int().min(60).max(900).default(300),
  OTP_RESEND_COOLDOWN_SEC: z.coerce.number().int().min(10).max(300).default(30),
  OTP_MAX_PER_PHONE_PER_HOUR: z.coerce.number().int().min(1).max(20).default(5),
  OTP_MAX_PER_IP_PER_HOUR: z.coerce.number().int().min(1).max(200).default(20),
  OTP_MAX_VERIFY_ATTEMPTS: z.coerce.number().int().min(1).max(10).default(5),

  // ─── Store reviewer demo login ───
  /**
   * Fallback only — the live switch is the `auth.demo_login_enabled` row in app_config,
   * so it can be flipped off after approval without a redeploy.
   */
  DEMO_LOGIN_ENABLED: z
    .enum(['true', 'false'])
    .default('false')
    .transform((value) => value === 'true'),
  DEMO_LOGIN_PHONE: z
    .string()
    .regex(/^91[6-9][0-9]{9}$/, 'must be 91 followed by a 10-digit Indian mobile')
    .default('919999999999'),
  DEMO_LOGIN_OTP: z
    .string()
    .regex(/^[0-9]{6}$/, 'must be 6 digits')
    .default('123456'),

  // ─── POS / catalogue sync ───
  /** `mock` = built-in sample catalogue. `gofrugal` is added once API access is granted. */
  POS_PROVIDER: z.enum(['mock']).default('mock'),
  /** Run the in-process delta sync scheduler. Off locally unless you want it. */
  CATALOG_SYNC_ENABLED: z
    .enum(['true', 'false'])
    .default('false')
    .transform((value) => value === 'true'),
  CATALOG_SYNC_INTERVAL_MIN: z.coerce.number().int().min(1).max(1440).default(15),
  CATALOG_SYNC_PAGE_SIZE: z.coerce.number().int().min(10).max(2000).default(500),

  // ─── Cloudflare R2 (optional until product images are wired) ───
  R2_ACCOUNT_ID: z.string().regex(/^[a-f0-9]{32}$/, 'must be the 32-char Cloudflare account ID').optional(),
  R2_ACCESS_KEY_ID: z.string().min(16).optional(),
  R2_SECRET_ACCESS_KEY: z.string().min(32).optional(),
  R2_BUCKET: z
    .string()
    .regex(/^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$/, 'invalid bucket name')
    .default('jeya-product-images'),
  /** Public base for image URLs, e.g. https://images.jeyahyperstore.com (no trailing slash). */
  R2_PUBLIC_BASE_URL: z
    .url()
    .transform((value) => value.replace(/\/+$/, ''))
    .optional(),
});

export type Env = z.infer<typeof envSchema>;

function loadEnv(): Env {
  // Treat `KEY=` (empty) as unset so optional groups like R2_* can sit blank in .env.
  const raw = Object.fromEntries(Object.entries(process.env).filter(([, value]) => value !== ''));
  const parsed = envSchema.safeParse(raw);
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
