import { describe, expect, it } from 'vitest';
import { pickLeader, variantKey, variantLabels } from './variants';

describe('product size groups', () => {
  it('groups sizes of one product in one category, not across categories', () => {
    const k = (n: string, c = 7) => variantKey(n, c);
    expect(k('Bru Instant 50 G')).toBe(k('Bru Instant 200gm'));
    expect(k('Boost 200g Jar')).toBe(k('Boost 500g Pouch'));
    expect(k('3 Roses 500g Loose')).toBe(k('3 Roses 100g'));
    expect(k('Bru Instant 50 G')).not.toBe(k('Bru Gold 50 G'));
    expect(k('Bru 100g', 7)).not.toBe(k('Bru 100g', 8));
    expect(k('100g')).toBeNull();
  });

  it('labels by size (+ pack), by price when there is no size, and splits same-size twins by price', () => {
    const labels = variantLabels([
      { id: 1, name: 'Boost 200g Jar', packSize: '200 g', sellingPrice: '109.00' },
      { id: 2, name: 'Boost 200g Pouch', packSize: '200 g', sellingPrice: '98.00' },
      { id: 3, name: 'Boost 500 GM', packSize: '500 g', sellingPrice: '238.00' },
      { id: 4, name: 'Boost 500g', packSize: '500 g', sellingPrice: '234.00' },
      { id: 5, name: 'Boost', packSize: null, sellingPrice: '10.00' },
    ]);
    expect([...labels.values()]).toEqual(['200 g Jar', '200 g Pouch', '500 g · ₹238', '500 g · ₹234', '₹10']);
    expect([...variantLabels([
      { id: 1, name: 'Arun', packSize: null, sellingPrice: '10.00' },
      { id: 2, name: 'Arun', packSize: null, sellingPrice: '20.00' },
    ]).values()]).toEqual(['₹10', '₹20']);
  });

  it('leads with an in-stock, featured, fast-moving size', () => {
    const base = { name: 'X', packSize: null, categoryId: 1, sortRank: 0, photoPriority: 0, sellingPrice: '10' };
    expect(pickLeader([{ ...base, id: 1, available: 0, photoPriority: 99 }, { ...base, id: 2, available: 3 }])).toBe(2);
    expect(pickLeader([{ ...base, id: 1, available: 3 }, { ...base, id: 2, available: 3, sortRank: 5 }])).toBe(2);
    expect(pickLeader([{ ...base, id: 1, available: 3, photoPriority: 10 }, { ...base, id: 2, available: 3, photoPriority: 40 }])).toBe(2);
  });
});
