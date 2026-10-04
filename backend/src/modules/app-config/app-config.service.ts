import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { appConfigRepository } from './app-config.repository';

/** Known config keys — keep in sync with src/scripts/seed.ts. */
export const CONFIG_KEYS = {
  DEMO_LOGIN_ENABLED: 'auth.demo_login_enabled',
  MIN_APP_VERSION: 'app.min_supported_version',
  STORE_INFO: 'store.info',
  MAINTENANCE: 'app.maintenance',
  PAYMENT_METHODS: 'checkout.payment_methods',
  DELIVERY_RULES: 'delivery.rules',
  APP_THEME: 'app.theme',
  MAP_TILES: 'map.tiles',
  USAGE_LIMITS: 'usage.limits',
  USAGE_NOTIFY: 'usage.notify',
} as const;

const CACHE_TTL_MS = 30_000;

type Snapshot = { values: Map<string, unknown>; publicKeys: Set<string>; loadedAt: number };

let snapshot: Snapshot | null = null;
let inflight: Promise<Snapshot> | null = null;

async function load(): Promise<Snapshot> {
  const rows = await appConfigRepository.findAll(db);
  return {
    values: new Map(rows.map((row) => [row.key, row.value])),
    publicKeys: new Set(rows.filter((row) => row.isPublic).map((row) => row.key)),
    loadedAt: Date.now(),
  };
}

/**
 * Cached for 30 s so hot paths (every OTP request) don't hit the DB.
 * On a DB error we keep serving the last good snapshot rather than failing requests.
 */
async function getSnapshot(): Promise<Snapshot> {
  if (snapshot && Date.now() - snapshot.loadedAt < CACHE_TTL_MS) return snapshot;
  inflight ??= load()
    .then((fresh) => (snapshot = fresh))
    .catch((error: unknown) => {
      if (snapshot) {
        logger.warn({ err: error }, 'app_config refresh failed — serving stale values');
        return snapshot;
      }
      throw error;
    })
    .finally(() => {
      inflight = null;
    });
  return inflight;
}

export const appConfigService = {
  async getBoolean(key: string, fallback: boolean): Promise<boolean> {
    const value = (await getSnapshot()).values.get(key);
    return typeof value === 'boolean' ? value : fallback;
  },

  /** Object-valued key merged over a fallback, so a partially-filled row can't drop fields. */
  async getObject<T extends Record<string, unknown>>(key: string, fallback: T): Promise<T> {
    const value = (await getSnapshot()).values.get(key);
    return value && typeof value === 'object' && !Array.isArray(value) ? { ...fallback, ...(value as Partial<T>) } : fallback;
  },

  async getPublicConfig(): Promise<Record<string, unknown>> {
    const current = await getSnapshot();
    const result: Record<string, unknown> = {};
    for (const key of current.publicKeys) result[key] = current.values.get(key);
    return result;
  },

  /** Raw stored value (admin settings screen). */
  async getRaw(key: string): Promise<unknown> {
    return (await getSnapshot()).values.get(key);
  },

  /** Admin write: value replaced, visibility/description kept (or set on first write). */
  async set(key: string, value: unknown, meta: { isPublic: boolean; description: string }): Promise<void> {
    await appConfigRepository.upsert(db, key, value, meta);
    snapshot = null;
  },

  /** Tests / admin writes call this so the next read sees the change immediately. */
  invalidate(): void {
    snapshot = null;
  },
};
