import { describe, expect, it } from 'vitest';
import { packagingChanges } from './catalog-import.service';
import type { StockItem } from './stock-csv';

const item = (itemCode: string, ean: string | null) => ({ itemCode, ean }) as StockItem;

describe('new packaging (same item code, new EAN)', () => {
  const before = new Map([
    ['A1', { id: 1, barcode: '8901030123456', hasPhoto: true }],
    ['A2', { id: 2, barcode: '8901030999999', hasPhoto: false }],
    ['A3', { id: 3, barcode: '0089010301234', hasPhoto: true }],
    ['A4', { id: 4, barcode: null, hasPhoto: true }],
  ]);

  it('flags products with a photo whose EAN changed, keeping the old EAN', () => {
    expect(packagingChanges(before, [item('A1', '8901030654321')])).toEqual([{ id: 1, oldBarcode: '8901030123456' }]);
  });

  it('ignores products without a photo, unchanged EANs (leading zeros too) and first-time EANs', () => {
    expect(packagingChanges(before, [item('A1', '8901030123456'), item('A2', '8901030111111'), item('A3', '89010301234'), item('A4', '8901030222222'), item('NEW', '8901030333333')])).toEqual([]);
  });

  it('ignores a file that has no EAN for the item', () => {
    expect(packagingChanges(before, [item('A1', null)])).toEqual([]);
  });
});
