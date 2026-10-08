import { describe, expect, it } from 'vitest';
import { clampChoices, describeChoices, validChoices } from './choices';

const flavours = { label: 'Flavour', values: ['Vanilla', 'Chocolate', 'Strawberry'] };

describe('flavour choices', () => {
  it('accepts a split that adds up to the quantity, dropping zeros', () => {
    expect(validChoices({ Vanilla: '2', Chocolate: '1', Strawberry: '0' }, flavours, 3000)).toEqual({ Vanilla: '2', Chocolate: '1' });
  });

  it('rejects unknown flavours, wrong totals, missing splits and products without options', () => {
    expect(validChoices({ Mango: '1' }, flavours, 1000)).toBeNull();
    expect(validChoices({ Vanilla: '1' }, flavours, 2000)).toBeNull();
    expect(validChoices(null, flavours, 1000)).toBeNull();
    expect(validChoices({ Vanilla: '1' }, null, 1000)).toBeNull();
  });

  it('takes a stock shortfall off the last choices', () => {
    expect(clampChoices({ Vanilla: '2', Chocolate: '2' }, 3000)).toEqual({ Vanilla: '2', Chocolate: '1' });
    expect(clampChoices({ Vanilla: '2' }, 0)).toBeNull();
  });

  it('reads well on the packing screen', () => {
    expect(describeChoices({ Vanilla: '2', Chocolate: '1' })).toBe('Vanilla × 2, Chocolate × 1');
  });
});
