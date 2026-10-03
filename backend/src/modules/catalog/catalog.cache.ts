/**
 * Process-local cache for read-heavy catalogue data (category tree, listing pages, search,
 * product pages). Every hit is a database round trip saved — Supabase Free meters egress
 * and Render meters outbound bandwidth (our SQL), 5 GB/month each.
 * The sync engine calls invalidate() after every run; TTL is the safety net.
 * Single Render instance today — move to Redis pub/sub invalidation if we scale out.
 */
type Entry<T> = { value: T; expiresAt: number };

const entries = new Map<string, Entry<unknown>>();
/** Bounded: ~500 cached pages × ~10 KB is a few MB of the 512 MB server. */
const MAX_ENTRIES = 500;
const inflight = new Map<string, Promise<unknown>>();

export const catalogCache = {
  async get<T>(key: string, ttlMs: number, load: () => Promise<T>): Promise<T> {
    const hit = entries.get(key);
    if (hit && hit.expiresAt > Date.now()) return hit.value as T;

    const pending = inflight.get(key);
    if (pending) return pending as Promise<T>;

    const promise = load()
      .then((value) => {
        entries.delete(key); // re-insert at the end: Map order doubles as least-recently-loaded
        entries.set(key, { value, expiresAt: Date.now() + ttlMs });
        if (entries.size > MAX_ENTRIES) {
          for (const oldest of entries.keys()) {
            entries.delete(oldest);
            if (entries.size <= MAX_ENTRIES * 0.8) break;
          }
        }
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
