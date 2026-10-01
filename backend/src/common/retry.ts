import { logger } from '../config/logger';

export type RetryOptions = {
  attempts?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  /** Return false to fail fast (e.g. 4xx validation errors from an upstream). */
  shouldRetry?: (error: unknown) => boolean;
  label?: string;
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** Exponential backoff with full jitter. */
export async function withRetry<T>(fn: (attempt: number) => Promise<T>, options: RetryOptions = {}): Promise<T> {
  const { attempts = 3, baseDelayMs = 1000, maxDelayMs = 15_000, shouldRetry = () => true, label = 'operation' } = options;
  let lastError: unknown;
  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await fn(attempt);
    } catch (error) {
      lastError = error;
      if (attempt === attempts || !shouldRetry(error)) break;
      const delay = Math.round(Math.random() * Math.min(maxDelayMs, baseDelayMs * 3 ** (attempt - 1)));
      logger.warn({ err: error, attempt, delayMs: delay, label }, 'retrying after failure');
      await sleep(delay);
    }
  }
  throw lastError;
}
