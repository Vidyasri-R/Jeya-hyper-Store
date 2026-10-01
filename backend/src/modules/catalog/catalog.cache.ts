/**
 * Process-local cache for small, read-heavy catalogue data (category tree).
 * The sync engine calls invalidate() after every run; TTL is the safety net.
 * Single Render instance today — move to Redis pub/sub invalidation if we scale out.
 */
type Entry<T> = { value: T; expiresAt: number };

const entries = new Map<string, Entry<unknown>>();
const inflight = new Map<string, Promise<unknown>>();

export const catalogCache = {
  async get<T>(key: string, ttlMs: number, load: () => Promise<T>): Promise<T> {
    const hit = entries.get(key);
    if (hit && hit.expiresAt > Date.now()) return hit.value as T;

    const pending = inflight.get(key);
    if (pending) return pending as Promise<T>;

    const promise = load()
      .then((value) => {
        entries.set(key, { value, expiresAt: Date.now() + ttlMs });
        return value;
      })
      .finally(() => inflight.delete(key));
    inflight.set(key, promise);
    return promise;
  },

  invalidate(): void {
    entries.clear();
  },
};
