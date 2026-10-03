import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { syncStateRepository } from '../sync/sync-state.repository';
import { runHousekeeping } from './housekeeping';
import { istDay, usageService } from './usage.service';

const TICK_MS = 5 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const R2_SAMPLE_EVERY_MS = 12 * HOUR_MS;
const FIRST_RUN_DELAY_MS = 2 * 60 * 1000;

/** Daily jobs at fixed IST hours; the DB lease + last-success day make them run once per day. */
const DAILY_JOBS = [
  { key: 'job_housekeeping', istHour: 3, run: async () => void (await runHousekeeping()) },
  { key: 'job_usage_digest', istHour: 9, run: async () => void (await usageService.sendDigest()) },
] as const;

let timer: NodeJS.Timeout | null = null;
let running: Promise<void> | null = null;
let lastHourly = 0;
let lastR2 = 0;

function istHour(now: Date): number {
  return Number(new Intl.DateTimeFormat('en-GB', { hour: 'numeric', hour12: false, timeZone: 'Asia/Kolkata' }).format(now));
}

async function runDaily(now: Date): Promise<void> {
  for (const job of DAILY_JOBS) {
    if (istHour(now) < job.istHour) continue;
    const state = await syncStateRepository.get(db, job.key);
    if (state?.lastSuccessAt && istDay(state.lastSuccessAt) === istDay(now)) continue;
    if (!(await syncStateRepository.acquireLease(db, job.key))) continue;
    try {
      await job.run();
      await syncStateRepository.markSuccess(db, job.key, { watermark: null, itemsProcessed: 0 });
    } catch (error) {
      logger.error({ err: error, job: job.key }, 'daily job failed');
      await syncStateRepository.markFailure(db, job.key, error instanceof Error ? error.message : String(error));
    }
  }
}

async function tick(): Promise<void> {
  if (running) return;
  running = (async () => {
    const now = new Date();
    try {
      await usageService.flushTraffic();
      if (now.getTime() - lastR2 >= R2_SAMPLE_EVERY_MS) {
        lastR2 = now.getTime();
        await usageService.sampleR2().catch((error: unknown) => logger.warn({ err: error }, 'R2 usage sample failed'));
      }
      // The hourly query also keeps the Free project from being paused for inactivity.
      if (now.getTime() - lastHourly >= HOUR_MS) {
        lastHourly = now.getTime();
        await usageService.sampleDatabaseSize();
        await usageService.evaluate();
      }
      await runDaily(now);
    } catch (error) {
      logger.error({ err: error }, 'usage monitor tick failed');
    }
  })().finally(() => {
    running = null;
  });
  await running;
}

/** Budget monitor: traffic flush every 5 min, sizes + alerts hourly, R2 twice a day, daily jobs. */
export const usageScheduler = {
  start(): void {
    if (timer) return;
    setTimeout(() => void tick(), FIRST_RUN_DELAY_MS).unref();
    timer = setInterval(() => void tick(), TICK_MS);
    timer.unref();
  },

  /** Final flush on shutdown so the last minutes of traffic aren't lost. */
  async stop(): Promise<void> {
    if (timer) clearInterval(timer);
    timer = null;
    await running;
    await usageService.flushTraffic().catch(() => undefined);
  },

  runOnce: tick,
};
