import { logger } from '../../config/logger';
import { ordersService } from './orders.service';

const SWEEP_EVERY_MS = 60_000;
const MAX_BATCHES_PER_TICK = 10;

let timer: NodeJS.Timeout | null = null;
let running: Promise<void> | null = null;

async function tick(): Promise<void> {
  if (running) return;
  running = (async () => {
    try {
      // Drain in batches so a backlog (e.g. after downtime) clears in one tick.
      for (let batch = 0; batch < MAX_BATCHES_PER_TICK; batch++) {
        if ((await ordersService.expireUnpaid()) === 0) break;
      }
    } catch (error) {
      logger.error({ err: error }, 'reservation sweep failed');
    }
  })().finally(() => {
    running = null;
  });
  await running;
}

/**
 * Releases stock held by unpaid online orders. Safe with multiple instances:
 * rows are claimed with FOR UPDATE SKIP LOCKED.
 */
export const reservationSweeper = {
  start(): void {
    if (timer) return;
    timer = setInterval(() => void tick(), SWEEP_EVERY_MS);
    timer.unref();
    void tick();
  },

  async stop(): Promise<void> {
    if (timer) clearInterval(timer);
    timer = null;
    await running;
  },

  runOnce: tick,
};
