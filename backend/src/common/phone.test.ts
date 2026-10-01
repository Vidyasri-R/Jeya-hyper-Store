import { describe, expect, it } from 'vitest';
import { maskPhone, normalizeIndianMobile } from './phone';

describe('normalizeIndianMobile', () => {
  it.each([
    ['9876543210', '919876543210'],
    ['09876543210', '919876543210'],
    ['919876543210', '919876543210'],
    ['+91 98765 43210', '919876543210'],
    ['+91-98765-43210', '919876543210'],
    ['(+91) 98765.43210', '919876543210'],
    ['6000000000', '916000000000'],
    ['9999999999', '919999999999'],
  ])('accepts %s', (input, expected) => {
    expect(normalizeIndianMobile(input)).toBe(expected);
  });

  it.each([
    ['5876543210', 'starts with 5'],
    ['987654321', '9 digits'],
    ['98765432101', '11 digits without leading 0'],
    ['929876543210', 'non-91 country code'],
    ['+1 415 555 0100', 'US number'],
    ['98765abcde', 'letters'],
    ['', 'empty'],
  ])('rejects %s (%s)', (input) => {
    expect(normalizeIndianMobile(input)).toBeNull();
  });
});

describe('maskPhone', () => {
  it('hides the middle digits', () => {
    expect(maskPhone('919876543210')).toBe('98765•••10');
  });
});
