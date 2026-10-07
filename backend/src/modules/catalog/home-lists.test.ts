import { describe, expect, it } from 'vitest';
import { homeListsSchema } from './home-lists';

describe('home lists setting', () => {
  it('keeps the admin order of product ids', () => {
    expect(homeListsSchema.parse({ offers: [9, 3, 7], popular: [] })).toEqual({ offers: [9, 3, 7], popular: [] });
  });

  it('rejects a product twice in one list, unknown keys and oversized lists', () => {
    expect(homeListsSchema.safeParse({ offers: [1, 1], popular: [] }).success).toBe(false);
    expect(homeListsSchema.safeParse({ offers: [], popular: [], extra: [] }).success).toBe(false);
    expect(homeListsSchema.safeParse({ offers: Array.from({ length: 31 }, (_, i) => i + 1), popular: [] }).success).toBe(false);
  });

  it('allows the same product in both lists', () => {
    expect(homeListsSchema.safeParse({ offers: [5], popular: [5] }).success).toBe(true);
  });
});
