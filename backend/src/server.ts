import { createApp } from './app';
import { env } from './config/env';
import { logger } from './config/logger';
import { closeDb } from './db/client';
import { syncScheduler } from './modules/sync/sync.scheduler';

const SHUTDOWN_TIMEOUT_MS = 10_000;

const server = createApp().listen(env.PORT, () => {
  logger.info({ port: env.PORT, env: env.NODE_ENV }, '🚀 Jeya API listening');
  syncScheduler.start();
});

// Must exceed Render's load balancer idle timeout to avoid sporadic 502s.
server.keepAliveTimeout = 65_000;
server.headersTimeout = 66_000;

let shuttingDown = false;

async function shutdown(signal: string): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'shutting down');

  const forceExit = setTimeout(() => {
    logger.error('graceful shutdown timed out, forcing exit');
    process.exit(1);
  }, SHUTDOWN_TIMEOUT_MS);
  forceExit.unref();

  server.close(async (error) => {
    if (error) logger.error({ err: error }, 'error closing HTTP server');
    await syncScheduler.stop().catch((syncError: unknown) => logger.error({ err: syncError }, 'error stopping sync'));
    await closeDb().catch((dbError: unknown) => logger.error({ err: dbError }, 'error closing DB pool'));
    process.exit(error ? 1 : 0);
  });
  server.closeIdleConnections();
}

process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('unhandledRejection', (reason) => {
  logger.error({ err: reason }, 'unhandled promise rejection');
});
process.on('uncaughtException', (error) => {
  logger.fatal({ err: error }, 'uncaught exception — exiting');
  process.exit(1);
});
