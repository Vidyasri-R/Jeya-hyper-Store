import { describe, expect, it } from 'vitest';
import { memberDiscountPaise } from './perks.service';

describe('premium customer discount', () => {
  it('takes the percentage off the items, to the paisa', () => {
    expect(memberDiscountPaise(123_450, { freeDelivery: false, discountPercent: 10, name: null })).toBe(12_345);
    expect(memberDiscountPaise(999, { freeDelivery: true, discountPercent: 2.5, name: null })).toBe(25);
  });

  it('is nothing for customers without a discount', () => {
    expect(memberDiscountPaise(50_000, null)).toBe(0);
    expect(memberDiscountPaise(50_000, { freeDelivery: true, discountPercent: 0, name: null })).toBe(0);
  });
});
