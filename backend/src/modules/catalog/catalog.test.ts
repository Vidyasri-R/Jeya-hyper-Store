import { describe, expect, it } from 'vitest';
import { decodeCursor, encodeCursor } from '../../common/cursor';
import { AppError } from '../../common/errors';
import { slugify, slugWithId } from '../../common/slug';
import { mapPosUnit, posItemSchema } from '../../integrations/gofrugal/types';
import { buildMockCatalog } from '../../integrations/gofrugal/mock-catalog';
import type { ProductCardRow } from './catalog.repository';
import { toProductCard } from './catalog.service';
import { parseSearch } from './search-query';

describe('slugs', () => {
  it('slugifies product names', () => {
    expect(slugify("Lay's Potato Chips 52 g")).toBe('lay-s-potato-chips-52-g');
    expect(slugify('Rice & Rice Products')).toBe('rice-and-rice-products');
  });
  it('falls back to the id for Tamil-only names', () => {
    expect(slugWithId('பொன்னி அரிசி', 'GF-123')).toBe('gf-123');
    expect(slugWithId('Ponni Rice', '10234')).toBe('ponni-rice-10234');
  });
});

describe('cursor', () => {
  it('round-trips', () => {
    expect(decodeCursor(encodeCursor({ v: '68.50', id: 42 }))).toEqual({ v: '68.50', id: 42 });
  });
  it.each(['garbage', encodeCursor({ v: 1, id: 1.5 } as never), Buffer.from('{"v":{}}').toString('base64url')])(
    'rejects tampered cursor %s',
    (raw) => {
      expect(() => decodeCursor(raw)).toThrow(AppError);
    },
  );
});

describe('parseSearch', () => {
  it('builds a prefix tsquery from words', () => {
    expect(parseSearch('Ponni  RICE').tsquery).toBe('ponni:* & rice:*');
  });
  it('keeps Tamil tokens', () => {
    expect(parseSearch('பொன்னி அரிசி').tsquery).toBe('பொன்னி:* & அரிசி:*');
  });
  it('strips tsquery operators (injection-safe)', () => {
    const parsed = parseSearch("rice' & !dal | (oil):*");
    expect(parsed.tsquery).toBe('rice:* & dal:* & oil:*');
  });
  it('detects barcode / item code input', () => {
    expect(parseSearch('8901234567890').code).toBe('8901234567890');
    expect(parseSearch('mk1001').code).toBe('MK1001');
    expect(parseSearch('ponni rice').code).toBeNull();
  });
  it('returns null tsquery for punctuation-only input', () => {
    expect(parseSearch('!!!').tsquery).toBeNull();
  });
});

describe('POS item validation', () => {
  const valid = {
    externalId: 'GF1',
    itemCode: 'A1',
    barcode: '',
    name: 'Toor Dal 1 kg',
    brand: null,
    categoryExternalId: 'C1',
    mrp: 180,
    sellingPrice: '165.5',
    hsnCode: '0713',
    gstRate: 0,
    stock: '12',
    unit: 'NOS',
    packSize: '1 kg',
    isActive: true,
    isWeighable: null,
    updatedAt: '2026-10-01T10:00:00Z',
  };

  it('normalises decimals and empty strings', () => {
    const item = posItemSchema.parse(valid);
    expect(item.mrp).toBe('180.00');
    expect(item.sellingPrice).toBe('165.50');
    expect(item.stock).toBe('12.000');
    expect(item.barcode).toBeNull();
    expect(item.updatedAt).toBeInstanceOf(Date);
  });
  it('rejects selling price above MRP', () => {
    expect(posItemSchema.safeParse({ ...valid, sellingPrice: 200 }).success).toBe(false);
  });
  it('rejects zero price and bad GST', () => {
    expect(posItemSchema.safeParse({ ...valid, sellingPrice: 0 }).success).toBe(false);
    expect(posItemSchema.safeParse({ ...valid, gstRate: 40 }).success).toBe(false);
  });
  it('rejects non-numeric price', () => {
    expect(posItemSchema.safeParse({ ...valid, mrp: 'abc' }).success).toBe(false);
  });
  it('maps POS units', () => {
    expect(mapPosUnit('KGS')).toBe('kg');
    expect(mapPosUnit('nos')).toBe('pcs');
    expect(mapPosUnit('LTR')).toBe('l');
    expect(mapPosUnit('weird')).toBe('pcs');
  });
  it('mock catalogue is fully valid', () => {
    const { items } = buildMockCatalog();
    expect(items.length).toBeGreaterThan(150);
    for (const item of items) expect(posItemSchema.safeParse(item).success, item.externalId).toBe(true);
  });
});

describe('toProductCard', () => {
  const base: ProductCardRow = {
    id: 1,
    slug: 'x',
    name: 'X',
    nameTa: null,
    brand: null,
    categoryId: 1,
    mrp: '100.00',
    sellingPrice: '90.00',
    unit: 'pcs',
    packSize: null,
    isLoose: false,
    minOrderQty: '1.000',
    qtyStep: '1.000',
    maxOrderQty: null,
    imageUrl: null,
    available: '120.000',
    sortRank: 0,
  };

  it('computes discount and caps qty at the per-line default', () => {
    const card = toProductCard(base);
    expect(card.discountPercent).toBe(10);
    expect(card.maxPurchasableQty).toBe('50');
    expect(card.stockStatus).toBe('in_stock');
  });
  it('flags low and out of stock', () => {
    expect(toProductCard({ ...base, available: '3.000' }).stockStatus).toBe('low_stock');
    expect(toProductCard({ ...base, available: '0.000' }).stockStatus).toBe('out_of_stock');
    expect(toProductCard({ ...base, available: '-4.000' }).maxPurchasableQty).toBe('0');
  });
  it('rounds loose items down to whole steps', () => {
    const card = toProductCard({ ...base, isLoose: true, unit: 'kg', minOrderQty: '0.250', qtyStep: '0.250', available: '1.600' });
    expect(card.maxPurchasableQty).toBe('1.5');
    expect(card.minOrderQty).toBe('0.25');
  });
  it('treats stock below the minimum order as out of stock', () => {
    const card = toProductCard({ ...base, isLoose: true, unit: 'kg', minOrderQty: '0.250', qtyStep: '0.250', available: '0.100' });
    expect(card.stockStatus).toBe('out_of_stock');
  });
});
