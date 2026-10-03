import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { syncState } from '../../db/schema';
import { backupService } from '../backup/backup.service';
import { syncStateRepository } from '../sync/sync-state.repository';
import { runHousekeeping } from './housekeeping';
import { traffic } from '../../infra/traffic';
import { istDay, unfinishedReportQueries, usageService } from './usage.service';

const TICK_MS = 5 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;
const R2_SAMPLE_EVERY_MS = 12 * HOUR_MS;
const FIRST_RUN_DELAY_MS = 2 * 60 * 1000;

const MINUTE_MS = 60 * 1000;
/** Last outcome of every tick (sync_state row) — lets us check the monitor without server logs. */
const TICK_STATE = 'monitor_tick';

/** Daily jobs at fixed IST hours; the DB lease + last-success day make them run once per day. */
const DAILY_JOBS = [
  { key: 'job_backup', istHour: 2, limitMs: 10 * MINUTE_MS, run: async () => void (await backupService.run('auto')) },
  { key: 'job_housekeeping', istHour: 3, limitMs: 2 * MINUTE_MS, run: async () => void (await runHousekeeping()) },
  { key: 'job_usage_digest', istHour: 9, limitMs: 2 * MINUTE_MS, run: async () => void (await usageService.sendDigest()) },
] as const;

/** A stuck step must never freeze the monitor: it would block every later tick (as a stalled R2 call once did). */
function withTimeout<T>(work: Promise<T>, ms: number, label: string): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const deadline = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${Math.round(ms / 1000)}s`)), ms);
    timer.unref();
  });
  return Promise.race([work, deadline]).finally(() => clearTimeout(timer));
}

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
    // After a failure, retry hourly rather than on every 5-minute tick.
    if (state?.status === 'failed' && state.lastRunFinishedAt && now.getTime() - state.lastRunFinishedAt.getTime() < HOUR_MS) continue;
    if (!(await syncStateRepository.acquireLease(db, job.key))) continue;
    try {
      await withTimeout(job.run(), job.limitMs, job.key);
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
    const problems: string[] = [];
    const step = async (label: string, ms: number, work: () => Promise<unknown>) => {
      try {
        await withTimeout(work(), ms, label);
      } catch (error) {
        const stuck = unfinishedReportQueries();
        const sockets = traffic.openSockets();
        problems.push(
          `${error instanceof Error ? error.message : String(error)}${stuck.length ? ` [unfinished: ${stuck.join(', ')}]` : ''} [db sockets: ${sockets.db}]`,
        );
        logger.error({ err: error, step: label, stuck, sockets }, 'usage monitor step failed');
      }
    };
    await step('traffic flush', 30_000, () => usageService.flushTraffic());
    if (now.getTime() - lastR2 >= R2_SAMPLE_EVERY_MS) {
      lastR2 = now.getTime();
      await step('R2 sample', 90_000, () => usageService.sampleR2());
    }
    // The hourly query also keeps the Free project from being paused for inactivity.
    if (now.getTime() - lastHourly >= HOUR_MS) {
      lastHourly = now.getTime();
      await step('database size', 30_000, () => usageService.sampleDatabaseSize());
      await step('alerts', 2 * MINUTE_MS, () => usageService.evaluate());
    }
    await step('daily jobs', 15 * MINUTE_MS, () => runDaily(now));
    try {
      await db.insert(syncState).values({ key: TICK_STATE }).onConflictDoNothing({ target: syncState.key });
      if (problems.length === 0) await syncStateRepository.markSuccess(db, TICK_STATE, { watermark: null, itemsProcessed: 0 });
      else await syncStateRepository.markFailure(db, TICK_STATE, problems.join(' | '));
    } catch (error) {
      logger.warn({ err: error }, 'could not record monitor tick');
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
