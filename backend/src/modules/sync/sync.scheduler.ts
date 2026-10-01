import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { catalogSyncService, SYNC_KEYS, type SyncMode } from './catalog-sync.service';
import { syncStateRepository } from './sync-state.repository';

const FULL_SYNC_EVERY_MS = 20 * 60 * 60 * 1000;
/** Full resync in the quiet hours (IST) when the store is closed. */
const FULL_SYNC_WINDOW_IST = { fromHour: 2, toHour: 5 };
const FIRST_RUN_DELAY_MS = 30_000;

function istHour(now: Date): number {
  return Number(new Intl.DateTimeFormat('en-GB', { hour: 'numeric', hour12: false, timeZone: 'Asia/Kolkata' }).format(now));
}

async function pickMode(now: Date): Promise<SyncMode> {
  const full = await syncStateRepository.get(db, SYNC_KEYS.ITEMS_FULL);
  const lastFull = full?.lastSuccessAt?.getTime() ?? 0;
  const hour = istHour(now);
  const inWindow = hour >= FULL_SYNC_WINDOW_IST.fromHour && hour < FULL_SYNC_WINDOW_IST.toHour;
  return inWindow && now.getTime() - lastFull > FULL_SYNC_EVERY_MS ? 'full' : 'delta';
}

let timer: NodeJS.Timeout | null = null;
let running: Promise<unknown> | null = null;

async function tick(): Promise<void> {
  if (running) return; // previous tick still going in this process
  running = (async () => {
    try {
      await catalogSyncService.run(await pickMode(new Date()));
    } catch {
      // already logged + recorded in sync_state by the service; keep the scheduler alive
    }
  })().finally(() => {
    running = null;
  });
  await running;
}

/**
 * In-process scheduler — fine for one Render instance (the DB lease also prevents
 * overlap if a second instance ever runs). Moves to a BullMQ repeatable job with Redis in Step 5.
 */
export const syncScheduler = {
  start(): void {
    if (!env.CATALOG_SYNC_ENABLED || timer) return;
    const intervalMs = env.CATALOG_SYNC_INTERVAL_MIN * 60 * 1000;
    logger.info({ intervalMin: env.CATALOG_SYNC_INTERVAL_MIN }, 'catalog sync scheduler started');
    setTimeout(() => void tick(), FIRST_RUN_DELAY_MS).unref();
    timer = setInterval(() => void tick(), intervalMs);
    timer.unref();
  },

  /** Lets an in-flight run finish (bounded by the caller's shutdown timeout). */
  async stop(): Promise<void> {
    if (timer) clearInterval(timer);
    timer = null;
    await running;
  },
};
