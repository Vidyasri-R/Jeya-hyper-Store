import { describe, expect, it } from 'vitest';
import { displayQty, fromMilli, fromPaise, includedGstPaise, lineTotalPaise, toMilli, toPaise } from '../../common/money';
import { purchaseLimits, validateQty } from '../catalog/purchase-rules';
import type { CartProduct } from './cart.repository';
import { fixedQtyMilli, priceLine, summarize } from './pricing';

describe('money', () => {
  it('parses decimal strings exactly (no float drift)', () => {
    expect(toPaise('68.50')).toBe(6850);
    expect(toPaise('0.1')).toBe(10);
    expect(toPaise('1234567.89')).toBe(123456789);
    expect(toPaise(19.99)).toBe(1999);
    expect(toMilli('1.250')).toBe(1250);
    expect(toMilli('-4.000')).toBe(-4000);
  });
  it('rejects garbage and excess precision', () => {
    expect(() => toPaise('12.345')).toThrow();
    expect(() => toPaise('abc')).toThrow();
    expect(toPaise('12.340')).toBe(1234); // trailing zero is fine
  });
  it('formats back', () => {
    expect(fromPaise(6850)).toBe('68.50');
    expect(fromPaise(5)).toBe('0.05');
    expect(fromMilli(1250)).toBe('1.250');
    expect(displayQty(1250)).toBe('1.25');
    expect(displayQty(2000)).toBe('2');
  });
  it('line totals round half-up to the paisa', () => {
    expect(lineTotalPaise(3200, 1250)).toBe(4000); // ₹32/kg × 1.25 kg = ₹40.00
    expect(lineTotalPaise(3333, 1500)).toBe(5000); // 49.995 → 50.00
    expect(lineTotalPaise(6850, 3000)).toBe(20550);
  });
  it('extracts included GST', () => {
    expect(includedGstPaise(11800, '18.00')).toBe(1800); // ₹118 incl. 18% → ₹18 tax
    expect(includedGstPaise(10500, '5.00')).toBe(500);
    expect(includedGstPaise(10000, '0.00')).toBe(0);
  });
  it('0.1 + 0.2 style sums stay exact', () => {
    const total = ['0.10', '0.20', '68.50', '19.99'].map(toPaise).reduce((a, b) => a + b, 0);
    expect(fromPaise(total)).toBe('88.79');
  });
});

const product = (overrides: Partial<CartProduct> = {}): CartProduct => ({
  id: 1,
  slug: 'p',
  name: 'Toor Dal 1 kg',
  nameTa: null,
  brand: null,
  categoryId: 1,
  mrp: '180.00',
  sellingPrice: '165.00',
  unit: 'pcs',
  packSize: '1 kg',
  isLoose: false,
  minOrderQty: '1.000',
  qtyStep: '1.000',
  maxOrderQty: null,
  imageUrl: null,
  available: '20.000',
  sortRank: 0,
  isActive: true,
  gstRate: '5.00',
  hsnCode: '0713',
  itemCode: 'A1',
  gofrugalItemId: 'G1',
  ...overrides,
});

describe('purchase rules', () => {
  it('validates min / step / max', () => {
    const limits = purchaseLimits(product({ isLoose: true, unit: 'kg', minOrderQty: '0.250', qtyStep: '0.250', available: '3.000' }));
    expect(validateQty(250, limits, limits.maxMilli)).toBeNull();
    expect(validateQty(100, limits, limits.maxMilli)).toBe('below_min');
    expect(validateQty(300, limits, limits.maxMilli)).toBe('not_step_multiple');
    expect(validateQty(3250, limits, limits.maxMilli)).toBe('above_max');
  });
});

describe('priceLine', () => {
  it('prices a valid line', () => {
    const line = priceLine(product(), 3000);
    expect(line.issue).toBeNull();
    expect(line.lineTotalPaise).toBe(49500);
    expect(line.lineMrpTotalPaise).toBe(54000);
  });
  it('flags inactive, out of stock, and over-stock lines', () => {
    expect(priceLine(product({ isActive: false }), 1000).issue).toBe('unavailable');
    expect(priceLine(product({ available: '0.000' }), 1000).issue).toBe('out_of_stock');
    const over = priceLine(product({ available: '2.000' }), 5000);
    expect(over.issue).toBe('exceeds_stock');
    expect(fixedQtyMilli(over)).toBe(2000);
  });
  it('fix snaps loose items to the step', () => {
    const line = priceLine(product({ isLoose: true, unit: 'kg', minOrderQty: '0.250', qtyStep: '0.250', available: '0.900' }), 2000);
    expect(line.issue).toBe('exceeds_stock');
    expect(fixedQtyMilli(line)).toBe(750);
  });
  it('summary excludes problem lines from the subtotal', () => {
    const summary = summarize([priceLine(product(), 2000), priceLine(product({ id: 2, isActive: false }), 1000)]);
    expect(summary.subtotalPaise).toBe(33000);
    expect(summary.itemCount).toBe(1);
    expect(summary.hasIssues).toBe(true);
    expect(summary.includedGstPaise).toBe(1571); // 330 × 5/105 = 15.714
  });
});
