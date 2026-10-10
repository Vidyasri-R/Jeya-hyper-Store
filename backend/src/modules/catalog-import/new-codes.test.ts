import { describe, expect, it } from 'vitest';
import { baseName, priceTag, sameProductPairs, type CodeCandidate } from './new-codes';

let id = 0;
const p = (o: Partial<CodeCandidate> & { name: string; itemCode: string; mrp: string; at: string }): CodeCandidate => ({
  id: ++id,
  brand: null,
  packSize: null,
  isActive: true,
  hasPhoto: false,
  lastPurchaseAt: new Date(o.at),
  ...o,
});

describe('same product, new code', () => {
  it('ignores spaces, dots and price tags in names', () => {
    expect(baseName('A2B  Madras Mixture MRP 10')).toBe(baseName('A2B MADRAS MIXTURE MRP10'));
    expect(baseName('3 Roses Natural Care Rs.10')).toBe(baseName('3 ROSES NATURAL CARE MRP.10'));
    expect(baseName('Whisper Ultra XL+ 30PADS')).not.toBe(baseName('Whisper Ultra XL 30PADS'));
    expect(priceTag('Aashirvaad Atta 2KG MRP116')).toBe('116');
    expect(priceTag('Apsara Mechano Eraser')).toBeNull();
  });

  it('pairs the older code with the newer one (same brand, size, name; believable price)', () => {
    const old = p({ name: 'Aashirvaad Atta 2KG', itemCode: '34215', mrp: '110.00', at: '2025-11-03', brand: 'Aashirvaad', packSize: '2 kg', hasPhoto: true, isActive: false });
    const neu = p({ name: 'Aashirvaad Atta 2KG MRP116', itemCode: '40017', mrp: '116.00', at: '2026-09-16', brand: 'AASHIRVAAD', packSize: '2 kg' });
    const pairs = sameProductPairs([neu, old], new Set());
    expect(pairs.map((x) => [x.old.itemCode, x.new.itemCode])).toEqual([['34215', '40017']]);
  });

  it('keeps different products apart', () => {
    const list = [
      // two price tags = two products
      p({ name: 'Agal Vizhakku Rs.15', itemCode: '39569', mrp: '20.00', at: '2025-11-26' }),
      p({ name: 'Agal Vizhakku Rs.20', itemCode: '39570', mrp: '25.00', at: '2025-11-26' }),
      // other size
      p({ name: 'Bru Instant', itemCode: '1', mrp: '98.00', at: '2026-01-01', packSize: '100 g' }),
      p({ name: 'Bru Instant', itemCode: '2', mrp: '189.00', at: '2026-02-01', packSize: '200 g' }),
      // price too far apart
      p({ name: 'Oreo Vanilla', itemCode: '3', mrp: '30.00', at: '2026-01-01' }),
      p({ name: 'Oreo Vanilla', itemCode: '4', mrp: '160.00', at: '2026-02-01' }),
    ];
    expect(sameProductPairs(list, new Set())).toEqual([]);
  });

  it('skips answered pairs and new codes that are not on sale; photo pairs first', () => {
    const a1 = p({ name: 'A2B Madras Mixture MRP 10', itemCode: '19173', mrp: '10.00', at: '2026-08-11' });
    const a2 = p({ name: 'A2B MADRAS MIXTURE MRP10', itemCode: '41968', mrp: '10.00', at: '2026-09-12' });
    const b1 = p({ name: '555 Monkey 3 T', itemCode: '37778', mrp: '170.00', at: '2026-06-24', hasPhoto: true });
    const b2 = p({ name: '555 MONKEY  3 T', itemCode: '35040', mrp: '170.00', at: '2026-09-02' });
    const c1 = p({ name: 'Apsara Avengers Kit', itemCode: '38007', mrp: '100.00', at: '2025-05-22' });
    const c2 = p({ name: 'Apsara Avengers  Kit', itemCode: '37709', mrp: '99.00', at: '2026-09-24', isActive: false });
    const pairs = sameProductPairs([a1, a2, b1, b2, c1, c2], new Set());
    expect(pairs.map((x) => x.new.itemCode)).toEqual(['35040', '41968']); // photo pair first; c2 not on sale
    expect(sameProductPairs([a1, a2], new Set([`${a1.id}:${a2.id}`]))).toEqual([]);
  });
});
