import { describe, expect, it } from 'vitest';
import { DEFAULT_SHOP_TV_SETTINGS, dayPlan, istTime, shopTvSettingsSchema, upcomingBreaks, type PlanItem } from './plan';

const items: PlanItem[] = [
  { id: 'a-diwali', mediaType: 'video', durationMs: 20_000 },
  { id: 'b-oil', mediaType: 'image', durationMs: null },
  { id: 'c-reel', mediaType: 'video', durationMs: 45_000 },
  { id: 'd-closing', mediaType: 'audio', durationMs: 8_000 },
];
const s = DEFAULT_SHOP_TV_SETTINGS;

describe('shop TV ad breaks', () => {
  it('is the same plan on every device (TV and phone ask separately)', () => {
    expect(dayPlan('2026-10-28', s, items)).toEqual(dayPlan('2026-10-28', s, [...items].reverse()));
    expect(dayPlan('2026-10-28', s, items)).not.toEqual(dayPlan('2026-10-29', s, items));
  });

  it('keeps every gap within 3–7 minutes, inside shop hours, 1–2 items per break', () => {
    const plan = dayPlan('2026-10-28', s, items);
    expect(plan.length).toBeGreaterThan(100); // 14 h of 3–7 min gaps
    const open = istTime('2026-10-28', '08:00');
    const close = istTime('2026-10-28', '22:00');
    expect(plan[0]!.at).toBeGreaterThanOrEqual(open + 3 * 60_000);
    for (let i = 0; i < plan.length; i++) {
      const b = plan[i]!;
      expect(b.items.length).toBeGreaterThanOrEqual(1);
      expect(b.items.length).toBeLessThanOrEqual(2);
      expect(b.at + b.durationMs).toBeLessThanOrEqual(close);
      if (i > 0) {
        const prev = plan[i - 1]!;
        const gap = b.at - (prev.at + prev.durationMs);
        expect(gap).toBeGreaterThanOrEqual(3 * 60_000);
        expect(gap).toBeLessThanOrEqual(7 * 60_000);
      }
    }
  });

  it('plays every ad before repeating, never the same one twice in a row; posters last imageSeconds', () => {
    const order = dayPlan('2026-10-28', s, items).flatMap((b) => b.items.map((i) => i.id));
    for (let i = 0; i + 4 <= 40; i += 4) expect(new Set(order.slice(i, i + 4)).size).toBe(4);
    for (let i = 1; i < order.length; i++) expect(order[i]).not.toBe(order[i - 1]);
    const poster = dayPlan('2026-10-28', s, items).flatMap((b) => b.items).find((i) => i.id === 'b-oil')!;
    expect(poster.durationMs).toBe(10_000);
  });

  it('second item starts after the first ends (plus a 1 s pause)', () => {
    const two = dayPlan('2026-10-28', { ...s, itemsPerBreak: { min: 2, max: 2 } }, items)[0]!;
    expect(two.items[1]!.offsetMs).toBe(two.items[0]!.durationMs + 1000);
  });

  it('no ads → no breaks; only the next 90 minutes are sent', () => {
    expect(dayPlan('2026-10-28', s, [])).toEqual([]);
    const noon = istTime('2026-10-28', '12:00');
    const next = upcomingBreaks(noon, s, () => items);
    expect(next.length).toBeGreaterThan(8);
    expect(next.every((b) => b.at <= noon + 90 * 60_000 && b.at + b.durationMs >= noon - 2 * 60_000)).toBe(true);
    expect(upcomingBreaks(istTime('2026-10-28', '23:00'), s, () => items)).toEqual([]);
  });

  it('settings are validated', () => {
    expect(shopTvSettingsSchema.safeParse(s).success).toBe(true);
    expect(shopTvSettingsSchema.safeParse({ ...s, breakEveryMinutes: { min: 9, max: 3 } }).success).toBe(false);
    expect(shopTvSettingsSchema.safeParse({ ...s, openTime: '8am' }).success).toBe(false);
  });
});
