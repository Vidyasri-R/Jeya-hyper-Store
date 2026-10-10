import { describe, expect, it } from 'vitest';
import { classify } from './category-map';
import { displayName, packSizeOf, parseCsv, readStockFile } from './stock-csv';

const HEADER =
  'DEPT,TYPE,BRAND,MODEL_ST,REGIONAL ITEM NAME,Item Code,Transaction No,Item Name,Special rate,Item Alias,Selling,Purchase Price,MRP,Landing Cost,Batch No,Expiry Date,Transaction Type,Current Stock,Sales Tax %,Barcode Value,Transaction Date,EAN Code,HSN_SAC Code,Status';
const row = (o: Record<string, string>) =>
  HEADER.split(',')
    .map((h) => {
      const v = o[h] ?? '';
      return /[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v;
    })
    .join(',');

/** Same shape as GoFrugal's export: three title rows, header, totals, one row per batch. */
const file = [
  'JEYA HYPER STORE,,,',
  '"Current Stock Detail \n \n",,,',
  '"Company1:SOMERASAMPETTAI,GSTNO:33XXXXX\n",,,',
  HEADER,
  ',,,,,,,,,,,,,,,,,"233,867.35",,,,,,',
  row({ DEPT: 'SUPER MARKET', TYPE: 'TEA', BRAND: '3 ROSES', 'Item Code': '501', 'Item Name': '3 ROSES 100G', Selling: '91', MRP: '92', 'Current Stock': '3', 'Sales Tax %': '5', 'Barcode Value': '0050107241', 'Transaction Date': '07/24/26', 'EAN Code': '8.90103E+12', Status: 'Regular' }),
  row({ DEPT: 'SUPER MARKET', TYPE: 'TEA', BRAND: '3 ROSES', 'Item Code': '501', 'Item Name': '3 ROSES 100G', Selling: '94', MRP: '95', 'Current Stock': '19', 'Sales Tax %': '5', 'Barcode Value': '0050109161', 'Transaction Date': '09/16/26', 'EAN Code': '8901030123456', 'Landing Cost': '81.5', 'Purchase Price': '78', Status: 'Regular' }),
  row({ DEPT: 'SUPERMARKET', TYPE: 'GROCERY', 'Item Code': '502', 'Item Name': 'ULUNTHAM PARUPPU BULK', Selling: '160', MRP: '170', 'Current Stock': '5.25', 'Sales Tax %': '0', 'Barcode Value': '0050201011', 'Transaction Date': '01/02/26', Status: 'Regular' }),
  row({ DEPT: 'SUPER MARKET', TYPE: 'COOL DRINKS', 'Item Code': '503', 'Item Name': 'APPY FIZZ 160ML MRP.10', Selling: '10', MRP: '10', 'Current Stock': '24', 'Sales Tax %': '40', 'Transaction Date': '09/01/26', Status: 'Regular' }),
  row({ DEPT: 'SUPER MARKET', TYPE: 'FREE GIFT', 'Item Code': '504', 'Item Name': 'FREE GIFT : SS PLATE', Selling: '0.01', MRP: '0.01', 'Current Stock': '58', 'Sales Tax %': '0', Status: 'Regular' }),
  row({ DEPT: 'SUPER MARKET', TYPE: 'SOAP', 'Item Code': '505', 'Item Name': 'BAD SOAP', Selling: '50', MRP: '40', 'Current Stock': '2', 'Sales Tax %': '18', Status: 'Regular' }),
  row({ DEPT: 'SUPER MARKET', TYPE: 'SHAMPOO', 'Item Code': '506', 'Item Name': 'OLD SHAMPOO 80ML', Selling: '50', MRP: '55', 'Current Stock': '1', 'Sales Tax %': '18', Status: 'Inactive' }),
  row({ DEPT: 'FIRST FLOOR', TYPE: 'GIFT & TOYS', 'Item Code': '601', 'Item Name': 'TEDDY BEAR', Selling: '300', MRP: '350', 'Current Stock': '2', 'Sales Tax %': '12', Status: 'Regular' }),
  '',
].join('\r\n');

describe('stock file reader', () => {
  it('parses quoted fields with commas and newlines', () => {
    expect(parseCsv('a,"b,c","d\n""e"""\r\nx,y\n')).toEqual([['a', 'b,c', 'd\n"e"'], ['x', 'y']]);
  });

  it('merges batches: summed stock, latest batch price, every label barcode, intact EAN only', () => {
    const f = readStockFile(file, new Set(['SUPERMARKET', '']));
    expect(f.rows).toBe(8);
    const tea = f.items.find((i) => i.itemCode === '501')!;
    expect(tea).toMatchObject({ name: '3 Roses 100g', sellingPrice: '94.00', mrp: '95.00', stock: '22.000', packSize: '100 g', ean: '8901030123456', gstRate: '5.00', isLoose: false });
    expect(tea.labelBarcodes.sort()).toEqual(['0050107241', '0050109161']);
    expect(tea.costPrice).toBe('81.50'); // latest batch's Landing Cost
    expect(f.items.find((i) => i.itemCode === '503')?.costPrice).toBeNull(); // no cost in the file
  });

  it('LIFO: newest purchase sets the price wherever it is in the file; same day → the batch with more on the shelf', () => {
    const t = (rows: string[]) => readStockFile([HEADER, ...rows].join('\r\n'), null).items[0]!;
    const base = { DEPT: 'SUPER MARKET', TYPE: 'BISCUITS', 'Item Code': '701', 'Item Name': 'OREO 120G', 'Sales Tax %': '5', Status: 'Regular' };
    // newest first in the file
    expect(t([
      row({ ...base, Selling: '35', MRP: '35', 'Current Stock': '2', 'Transaction Date': '09/20/26' }),
      row({ ...base, Selling: '30', MRP: '30', 'Current Stock': '40', 'Transaction Date': '06/01/26' }),
    ])).toMatchObject({ sellingPrice: '35.00', mrp: '35.00', stock: '42.000' });
    // one invoice, two prices: the batch with more units wins, whichever row comes last
    for (const order of [0, 1]) {
      const rows = [
        row({ ...base, Selling: '27', MRP: '27', 'Current Stock': '1', 'Transaction Date': '09/20/26' }),
        row({ ...base, Selling: '30', MRP: '30', 'Current Stock': '6', 'Transaction Date': '09/20/26' }),
      ];
      expect(t(order ? rows.reverse() : rows)).toMatchObject({ sellingPrice: '30.00', mrp: '30.00' });
    }
  });

  it('keeps only the chosen departments (SUPER MARKET = SUPERMARKET)', () => {
    const f = readStockFile(file, new Set(['SUPERMARKET']));
    expect(f.items.map((i) => i.itemCode).sort()).toEqual(['501', '502', '503', '506']);
    expect(readStockFile(file, null).items.some((i) => i.itemCode === '601')).toBe(true);
  });

  it('loose (BULK) items, 40% GST, inactive items, and rejects', () => {
    const f = readStockFile(file, new Set(['SUPERMARKET']));
    expect(f.items.find((i) => i.itemCode === '502')).toMatchObject({ isLoose: true, packSize: null, stock: '5.250' });
    expect(f.items.find((i) => i.itemCode === '503')).toMatchObject({ name: 'Appy Fizz 160ml MRP 10', gstRate: '40.00' });
    expect(f.items.find((i) => i.itemCode === '506')?.isActive).toBe(false);
    expect(f.problems.map((p) => [p.itemCode, p.reason])).toEqual([
      ['504', 'free gift / not for sale'],
      ['505', 'selling ₹50 is above MRP ₹40'],
    ]);
  });

  it('refuses a file that is not the stock export', () => {
    expect(() => readStockFile('a,b,c\n1,2,3\n', null)).toThrow(/Current Stock Detail/);
  });
});

describe('names, pack sizes and categories', () => {
  it('cleans POS names', () => {
    expect(displayName('BRU INSTANT JAR 100G MRP.180/-')).toBe('Bru Instant Jar 100g MRP 180');
    expect(displayName('BANJARAS KASTURI TURMERIC RS.90/- (100G)')).toBe('Banjaras Kasturi Turmeric Rs 90 (100G)');
    expect(displayName('ARUN MRP.10/-')).toBe('Arun MRP 10');
    expect(displayName('PEN RATE 5')).toBe('Pen Rate 5');
    expect(displayName('LUX SOAP M.R.P 35.00')).toBe('Lux Soap MRP 35');
    expect(displayName('AASHIRVAAD ATTA 5KG')).toBe('Aashirvaad Atta 5kg');
  });

  it('reads pack sizes', () => {
    expect(packSizeOf('GOLD WINNER 1 LTR')).toBe('1 L');
    expect(packSizeOf('VIM BAR 300 GMS')).toBe('300 g');
    expect(packSizeOf('PONNI RICE 25KG')).toBe('25 kg');
    expect(packSizeOf('TEDDY BEAR')).toBeNull();
  });

  it('places TYPEs, falls back to the name for vague ones, honours overrides', () => {
    expect(classify('HAIR OIL', 'PARACHUTE 100ML')).toBe('hair');
    expect(classify('COOKING OIL', 'GOLD WINNER 1L')).toBe('oils');
    expect(classify('DIAPER PANTS', 'PAMPERS M')).toBe('baby');
    expect(classify('GROCERY', 'ULUNTHAM PARUPPU BULK')).toBe('dals');
    expect(classify('Nill', 'BRU INSTANT JAR 100G')).toBe('tea_coffee');
    expect(classify('FANCY ITEMS', 'SOMETHING ODD')).toBe('other');
    expect(classify('DRYFISH', 'NETHILI')).toBe('other');
    expect(classify('DRYFISH', 'NETHILI', { DRYFISH: 'staples' })).toBe('staples');
    expect(classify('DRYFISH', 'NETHILI', { DRYFISH: 'not-a-category' })).toBe('other');
    expect(classify('CREAM', 'ARUN MRP.10/-', {}, 'Arun')).toBe('ice_cream');
    expect(classify('FACE CREAM', 'DAIRYDAY CONE', {}, 'Dairyday')).toBe('ice_cream');
    expect(classify('FACE CREAM', 'PONDS 50G', {}, 'Ponds')).toBe('skin');
  });

  it('strong name words beat a misleading TYPE (masala mixes, flours) without breaking pet food or mixes', () => {
    expect(classify('POWDER', 'AACHI LEMON RICE POWDER 50G')).toBe('masalas');
    expect(classify('WHITE AVAL THICK', 'TATA ASAFOETIDA')).toBe('masalas');
    expect(classify('RICE', 'AAKAA PUTTU FLOUR 500 GM')).toBe('atta');
    expect(classify('RICE', 'DELTA FOODS RAGI MAAVU 400 GM')).toBe('atta');
    expect(classify('FOOD PRODUCT', 'DOUBLE H RICE PALADA 300GM')).toBe('ready_mix');
    expect(classify('GROCERY', 'VATHAL RICE 50 GM')).toBe('papad');
    expect(classify('RICE', 'DAAWAT DELIGHT BASMATI RICE 1KG')).toBe('rice'); // real rice stays
    expect(classify('PET FOODS', 'DROOLS CREAMY STAWBERRY FLOUR MRP90')).toBe('pet');
    expect(classify('READY MIX', 'ANIL ADAI DOSA FLOUR 250G')).toBe('ready_mix');
    expect(classify('HEALTH MIX', 'AASHIRVAAD SATHU MAAVU MIX 250G')).toBe('breakfast');
    expect(classify('READY MIX', 'DEETYAS VATHAL KUZHAMBU 100G')).toBe('ready_mix');
    expect(classify('HERBAL POWDER', 'NALANGU MAAVU 50G')).not.toBe('atta');
  });
});
