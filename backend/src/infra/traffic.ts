import net from 'node:net';

/**
 * Wire-level byte counters (TLS + protocol overhead included) for the free-tier budget.
 *
 *  - db:   traffic with the Supabase pooler. `in` is what Supabase counts as egress
 *          (Free plan: 5 GB/month); `out` (our SQL) counts toward Render's outbound bandwidth.
 *  - http: traffic with clients via Render's proxy. `out` ≈ Render outbound bandwidth
 *          (Hobby workspace: 5 GB/month included, then $0.15/GB).
 *  - r2:   bytes we upload to Cloudflare R2 (also Render outbound) and the Class A ops we make.
 *
 * Counters are process-local; the usage collector drains them into usage_daily every few minutes.
 */
type Channel = 'db' | 'http';
type Tracked = { socket: net.Socket; channel: Channel; read: number; written: number };

export type TrafficDelta = {
  dbIn: number;
  dbOut: number;
  httpIn: number;
  httpOut: number;
  httpRequests: number;
  r2UploadBytes: number;
  r2ClassAOps: number;
};

const live = new Set<Tracked>();
let pending: TrafficDelta = empty();

function empty(): TrafficDelta {
  return { dbIn: 0, dbOut: 0, httpIn: 0, httpOut: 0, httpRequests: 0, r2UploadBytes: 0, r2ClassAOps: 0 };
}

/**
 * Fold socket counters into `pending`. A TLS-wrapped socket may only report its read
 * total when it closes, so deltas are clamped at zero and settle on close.
 */
function sample(): void {
  for (const tracked of live) {
    const read = tracked.socket.bytesRead;
    const written = tracked.socket.bytesWritten;
    const readDelta = Math.max(0, read - tracked.read);
    const writtenDelta = Math.max(0, written - tracked.written);
    tracked.read = Math.max(tracked.read, read);
    tracked.written = Math.max(tracked.written, written);
    if (tracked.channel === 'db') {
      pending.dbIn += readDelta;
      pending.dbOut += writtenDelta;
    } else {
      pending.httpIn += readDelta;
      pending.httpOut += writtenDelta;
    }
    if (tracked.socket.destroyed) live.delete(tracked);
  }
}

export const traffic = {
  /**
   * postgres.js `socket` factory: same TCP connection it would open itself, but counted.
   * postgres.js still does the SSLRequest + TLS upgrade on top (it reads `socket.host` for SNI).
   */
  dbSocket(options: { host: string[]; port: number[] }): net.Socket {
    const host = options.host[0]!;
    const port = options.port[0]!;
    const socket = net.connect({ host, port });
    Object.assign(socket, { host, port });
    live.add({ socket, channel: 'db', read: 0, written: 0 });
    return socket;
  },

  /** server.on('connection', traffic.trackHttp) */
  trackHttp(socket: net.Socket): void {
    live.add({ socket, channel: 'http', read: 0, written: 0 });
  },

  countRequest(): void {
    pending.httpRequests++;
  },

  countR2(op: { uploadBytes?: number; classAOps?: number }): void {
    pending.r2UploadBytes += op.uploadBytes ?? 0;
    pending.r2ClassAOps += op.classAOps ?? 0;
  },

  /** Returns everything counted since the last drain and resets. */
  drain(): TrafficDelta {
    sample();
    const delta = pending;
    pending = empty();
    return delta;
  },

  /** Put a drained delta back (the flush to the DB failed). */
  restore(delta: TrafficDelta): void {
    for (const key of Object.keys(delta) as (keyof TrafficDelta)[]) pending[key] += delta[key];
  },

  openSockets(): { db: number; http: number } {
    let db = 0;
    for (const tracked of live) if (tracked.channel === 'db' && !tracked.socket.destroyed) db++;
    return { db, http: live.size - db };
  },
};
