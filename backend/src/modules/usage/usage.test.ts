import net from 'node:net';
import { describe, expect, it } from 'vitest';
import { traffic } from '../../infra/traffic';
import { DEFAULT_USAGE_LIMITS } from './usage.limits';
import { buildMetric, formatBytes, istDay } from './usage.service';

const GB = 1_000_000_000;
const base = { id: 'render.bandwidth', label: 'Outbound bandwidth', unit: 'bytes' as const, limit: 5 * GB, cumulative: true, daysInMonth: 30, note: '' };

describe('usage metrics', () => {
  it('is ok well inside the free tier', () => {
    const m = buildMetric(DEFAULT_USAGE_LIMITS, { ...base, used: 1 * GB, daysElapsed: 15 });
    expect(m).toMatchObject({ percent: 20, projected: 2 * GB, projectedPercent: 40, level: 'ok' });
  });

  it('warns when the month-end projection crosses the limit', () => {
    // 2 GB in 10 days → 6 GB by month end (120%)
    expect(buildMetric(DEFAULT_USAGE_LIMITS, { ...base, used: 2 * GB, daysElapsed: 10 }).level).toBe('warning');
  });

  it('goes critical at 90% used or a 150% projection', () => {
    expect(buildMetric(DEFAULT_USAGE_LIMITS, { ...base, used: 4.6 * GB, daysElapsed: 29 }).level).toBe('critical');
    expect(buildMetric(DEFAULT_USAGE_LIMITS, { ...base, used: 2 * GB, daysElapsed: 5 }).level).toBe('critical');
  });

  it('ignores projections in the first days of the month (too noisy)', () => {
    expect(buildMetric(DEFAULT_USAGE_LIMITS, { ...base, used: 0.5 * GB, daysElapsed: 1 }).level).toBe('ok');
  });

  it('uses the current value for point-in-time metrics like database size', () => {
    const m = buildMetric(DEFAULT_USAGE_LIMITS, { ...base, id: 'supabase.db_size', limit: 500_000_000, cumulative: false, used: 360_000_000, daysElapsed: 2 });
    expect(m).toMatchObject({ percent: 72, projected: null, level: 'warning' });
  });

  it('reports unmeasured metrics as unknown, not zero', () => {
    expect(buildMetric(DEFAULT_USAGE_LIMITS, { ...base, used: null, daysElapsed: 10 })).toMatchObject({ used: null, percent: null, level: 'ok' });
  });

  it('formats sizes and IST days', () => {
    expect(formatBytes(4_560_000_000)).toBe('4.56 GB');
    expect(formatBytes(12_300_000)).toBe('12.3 MB');
    expect(istDay(new Date('2026-10-02T19:00:00Z'))).toBe('2026-10-03'); // 00:30 IST
  });
});

describe('traffic meter', () => {
  it('counts bytes both ways on observed database sockets', async () => {
    const server = net.createServer((socket) => socket.on('data', (data) => socket.end(Buffer.concat([data, data]))));
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
    const { port } = server.address() as net.AddressInfo;
    traffic.drain();

    traffic.observeDbPort(port);
    const socket = net.connect({ host: '127.0.0.1', port });
    await new Promise<void>((resolve) => {
      socket.on('connect', () => socket.write(Buffer.alloc(1000, 1)));
      socket.on('data', () => undefined);
      socket.on('close', () => resolve());
    });
    server.close();

    const delta = traffic.drain();
    expect(delta.dbOut).toBe(1000);
    expect(delta.dbIn).toBe(2000);
    expect(traffic.drain().dbIn).toBe(0);
  });
});
