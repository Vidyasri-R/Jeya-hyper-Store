import { describe, expect, it } from 'vitest';
import { photoPriority } from './photo-priority';

const now = new Date('2026-10-07T00:00:00Z');
const daysAgo = (d: number) => new Date(now.getTime() - d * 86_400_000);

describe('photo priority', () => {
  it('often-restocked, recent staples come before a one-off stationery item', () => {
    const rice = photoPriority({ batches: 6, updatedAt: daysAgo(5), isActive: true }, 'rice', now);
    const pen = photoPriority({ batches: 1, updatedAt: daysAgo(400), isActive: true }, 'stationery', now);
    const soap = photoPriority({ batches: 3, updatedAt: daysAgo(60), isActive: true }, 'bath', now);
    expect(rice).toBeGreaterThan(soap);
    expect(soap).toBeGreaterThan(pen);
    expect(pen).toBeGreaterThanOrEqual(1);
  });

  it('batches count is capped so one odd item cannot jump the whole queue', () => {
    const a = photoPriority({ batches: 10, updatedAt: daysAgo(5), isActive: true }, 'other', now);
    const b = photoPriority({ batches: 26, updatedAt: daysAgo(5), isActive: true }, 'other', now);
    expect(a).toBe(b);
  });

  it('inactive products are not in the photo queue', () => {
    expect(photoPriority({ batches: 9, updatedAt: daysAgo(1), isActive: false }, 'rice', now)).toBe(0);
  });
});
