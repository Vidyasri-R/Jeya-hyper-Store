import { describe, expect, it } from 'vitest';
import { haversineKm } from '../../common/geo';
import { DEFAULT_DELIVERY_RULES, deliveryService, expectedDeliveryBy, quoteByDistance } from './delivery.service';

const shop = DEFAULT_DELIVERY_RULES.storeLocation;
/** Point `km` straight-line km due north of the shop (1° latitude ≈ 111.2 km). */
const north = (km: number) => ({ lat: shop.lat + km / 111.195, lng: shop.lng });

describe('haversine', () => {
  it('measures known distances', () => {
    expect(haversineKm(shop, shop)).toBe(0);
    // Trichy shop → Chennai Central ≈ 309 km straight line
    const chennai = haversineKm(shop, { lat: 13.0827, lng: 80.2707 });
    expect(chennai).toBeGreaterThan(300);
    expect(chennai).toBeLessThan(320);
  });
});

describe('distance bands (straight line × 1.3 road factor)', () => {
  it.each([
    [1, 1.3, '20.00'],
    [2.3, 3, '20.00'],
    [3, 3.9, '40.00'],
    [7, 9.1, '60.00'],
  ])('%s km straight → %s road km → ₹%s', (straight, road, fee) => {
    const p = north(straight);
    const quote = quoteByDistance(DEFAULT_DELIVERY_RULES, p.lat, p.lng);
    expect(quote.serviceable).toBe(true);
    if (quote.serviceable) {
      expect(quote.distanceKm).toBeCloseTo(road, 1);
      expect(quote.baseFeePaise).toBe(Number(fee) * 100);
    }
  });

  it('refuses beyond the max radius', () => {
    const p = north(8); // 10.4 road km > 10
    const quote = quoteByDistance(DEFAULT_DELIVERY_RULES, p.lat, p.lng);
    expect(quote).toMatchObject({ serviceable: false, reason: 'out_of_range' });
  });
});

describe('free delivery threshold', () => {
  const p = north(4); // 5.2 road km → ₹40 band
  const quote = quoteByDistance(DEFAULT_DELIVERY_RULES, p.lat, p.lng);
  if (!quote.serviceable) throw new Error('expected serviceable');

  it('charges below ₹999', () => {
    expect(deliveryService.charge(quote, 99_899)).toEqual({ feePaise: 4000, freeDeliveryApplied: false });
  });
  it('is free at exactly ₹999 and above', () => {
    expect(deliveryService.charge(quote, 99_900)).toEqual({ feePaise: 0, freeDeliveryApplied: true });
    expect(deliveryService.charge(quote, 150_000).feePaise).toBe(0);
  });
});

describe('delivery promise (IST days)', () => {
  it('"by tomorrow" ends at 23:59 IST the next day', () => {
    // 12:00 IST on 3 Oct → end of 4 Oct IST (18:29:59.999 UTC)
    expect(expectedDeliveryBy(new Date('2026-10-03T06:30:00Z'), 1).toISOString()).toBe('2026-10-04T18:29:59.999Z');
  });

  it('uses the Indian date, not UTC, just after midnight IST', () => {
    // 00:30 IST on 4 Oct is still 3 Oct in UTC — tomorrow means 5 Oct
    expect(expectedDeliveryBy(new Date('2026-10-03T19:00:00Z'), 1).toISOString()).toBe('2026-10-05T18:29:59.999Z');
  });

  it('same day when days = 0, and handles month ends', () => {
    expect(expectedDeliveryBy(new Date('2026-10-03T06:30:00Z'), 0).toISOString()).toBe('2026-10-03T18:29:59.999Z');
    expect(expectedDeliveryBy(new Date('2026-10-31T10:00:00Z'), 1).toISOString()).toBe('2026-11-01T18:29:59.999Z');
  });
});

