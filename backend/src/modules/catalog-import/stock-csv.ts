/**
 * GoFrugal "Current Stock Detail" export → one record per product (see docs/gofrugal-stock-export.md).
 * The file has three title rows, a header, a totals row, then one row per purchase batch.
 */

/** RFC 4180 CSV: quoted fields may hold commas, quotes ("") and newlines. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  const s = text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (quoted) {
      if (c === '"') {
        if (s[i + 1] === '"') {
          field += '"';
          i++;
        } else quoted = false;
      } else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && s[i + 1] === '\n') i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else field += c;
  }
  if (field !== '' || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows;
}

export type StockItem = {
  itemCode: string;
  /** Display name: POS name with "MRP.10" / "RS.80" price tags removed, in title case. */
  name: string;
  posName: string;
  department: string;
  type: string;
  brand: string | null;
  mrp: string;
  sellingPrice: string;
  gstRate: string;
  hsnCode: string | null;
  stock: string;
  isLoose: boolean;
  packSize: string | null;
  ean: string | null;
  /** Barcodes printed on the store's own labels (one per batch). */
  labelBarcodes: string[];
  isActive: boolean;
  /** Latest inward date (the batch whose prices we use). */
  updatedAt: Date;
  /** Open purchase batches — restocked often = sells fast. */
  batches: number;
  /**
   * What one unit cost the store (latest batch's Landing Cost, else Purchase Price) — for the admin's
   * margin report only; never shown to customers. Null when the file has no cost for it.
   */
  costPrice: string | null;
};

export type ParsedStockFile = {
  items: StockItem[];
  rows: number;
  departments: Record<string, number>;
  problems: { itemCode: string; name: string; reason: string }[];
};

const REQUIRED = ['DEPT', 'TYPE', 'Item Code', 'Item Name', 'Selling', 'MRP', 'Current Stock'];

export class StockFileError extends Error {}

export const normDept = (d: string) => d.replace(/\s+/g, '').toUpperCase();

/** A believable unit cost: positive and not wildly above the selling price (typos, case costs). */
function costOf(landing: number, purchase: number, selling: number): string | null {
  for (const c of [landing, purchase]) if (c > 0 && c <= selling * 3) return c.toFixed(2);
  return null;
}

const num = (v: string | undefined) => {
  const n = Number(String(v ?? '').replace(/,/g, '').trim());
  return Number.isFinite(n) ? n : NaN;
};

/** "03/24/26" (MM/DD/YY, as GoFrugal writes it) → Date; unknown → epoch. */
function parseDate(v: string | undefined): Date {
  const m = /^(\d{1,2})\/(\d{1,2})\/(\d{2,4})$/.exec(String(v ?? '').trim());
  if (!m) return new Date(0);
  const year = m[3]!.length === 2 ? 2000 + Number(m[3]) : Number(m[3]);
  const d = new Date(Date.UTC(year, Number(m[1]) - 1, Number(m[2])));
  return Number.isNaN(d.getTime()) ? new Date(0) : d;
}

const UNIT_WORDS: Record<string, string> = { KG: 'kg', KGS: 'kg', G: 'g', GM: 'g', GMS: 'g', GRM: 'g', GRAM: 'g', GRAMS: 'g', L: 'L', LTR: 'L', LT: 'L', LITRE: 'L', ML: 'ml', PCS: 'pcs', PC: 'pc', N: 'pcs', NOS: 'pcs' };

/** "AASHIRVAAD ATTA 5KG" → "5 kg". */
export function packSizeOf(name: string): string | null {
  const m = /(\d+(?:\.\d+)?)\s*(KGS?|GMS?|GRM|GRAMS?|G|LTR|LT|LITRE|L|ML|PCS|PC|NOS)\b/i.exec(name);
  if (!m) return null;
  const qty = String(Number(m[1]));
  return `${qty} ${UNIT_WORDS[m[2]!.toUpperCase()] ?? m[2]!.toLowerCase()}`;
}

const SMALL_WORDS = new Set(['OF', 'AND', 'WITH', 'IN', 'FOR']);

/**
 * Tidy capitals and price tags, keeping the tag (the store names items by it, e.g. "Arun MRP 10"):
 * "BRU INSTANT JAR 100G MRP.180/-" → "Bru Instant Jar 100g MRP 180", "RS.90/-" → "Rs 90".
 */
export function displayName(posName: string): string {
  const cleaned = posName
    .replace(/\(?\s*\b(M\.?R\.?P|RS|RATE)\s*[.:]?\s*(\d+(?:\.\d+)?)\s*(?:\/-|\/|-)?\s*\)?/gi, (_m, tag: string, amount: string) => {
      const word = /^m/i.test(tag) ? 'MRP' : /^rs$/i.test(tag) ? 'Rs' : 'Rate';
      return ` ${word}\u2063${amount.replace(/\.0+$/, '')} `; // kept as one word until the end
    })
    .replace(/\s+/g, ' ')
    .replace(/[\s,.\-/(]+$/, '')
    .trim();
  return cleaned
    .split(' ')
    .map((w, i) => {
      if (w.includes('\u2063')) return w; // "MRP 10" / "Rs 90", already written as wanted
      if (/^\d+(\.\d+)?(KGS?|GMS?|G|ML|L|LTR|PCS?)$/i.test(w)) return w.replace(/[A-Z]+$/i, (u) => (u.toUpperCase() === 'L' || u.toUpperCase() === 'LTR' ? 'L' : u.toLowerCase()));
      if (/\d/.test(w) || w.length <= 2 || !/[AEIOU]/i.test(w)) return w.toUpperCase();
      if (i > 0 && SMALL_WORDS.has(w.toUpperCase())) return w.toLowerCase();
      return w.charAt(0).toUpperCase() + w.slice(1).toLowerCase();
    })
    .join(' ')
    .replace(/\u2063/g, ' ');
}

/**
 * Parse the export and merge batches into products. [departments] (normalised, e.g. "SUPERMARKET")
 * limits which products are returned; null = all.
 */
export function readStockFile(text: string, departments: Set<string> | null): ParsedStockFile {
  const rows = parseCsv(text);
  const headerAt = rows.findIndex((r) => r[0]?.trim() === 'DEPT' && r.includes('Item Code'));
  if (headerAt < 0) throw new StockFileError('This is not GoFrugal\'s "Current Stock Detail" export (no DEPT / Item Code header).');
  const header = rows[headerAt]!.map((h) => h.trim());
  const missing = REQUIRED.filter((c) => !header.includes(c));
  if (missing.length > 0) throw new StockFileError(`The file is missing columns: ${missing.join(', ')}`);
  const col = (name: string) => header.indexOf(name);
  const C = Object.fromEntries(
    ['DEPT', 'TYPE', 'BRAND', 'Item Code', 'Item Name', 'Selling', 'MRP', 'Current Stock', 'Sales Tax %', 'HSN_SAC Code', 'HSN_SAC Code (Transaction)', 'EAN Code', 'Barcode Value', 'Status', 'Transaction Date', 'Landing Cost', 'Purchase Price'].map((n) => [n, col(n)]),
  ) as Record<string, number>;
  const get = (r: string[], name: string) => (C[name]! >= 0 ? (r[C[name]!] ?? '').trim() : '');

  const byCode = new Map<string, string[][]>();
  const deptCount: Record<string, number> = {};
  let dataRows = 0;
  for (const r of rows.slice(headerAt + 1)) {
    const code = get(r, 'Item Code');
    if (!code) continue; // totals row, blank lines
    dataRows++;
    const dept = get(r, 'DEPT');
    deptCount[dept || '(blank)'] = (deptCount[dept || '(blank)'] ?? 0) + 1;
    if (departments && !departments.has(normDept(dept))) continue;
    const list = byCode.get(code);
    if (list) list.push(r);
    else byCode.set(code, [r]);
  }
  if (dataRows === 0) throw new StockFileError('The file has no product rows.');

  const items: StockItem[] = [];
  const problems: ParsedStockFile['problems'] = [];
  for (const [itemCode, batches] of byCode) {
    let latest = batches[0]!;
    let latestAt = parseDate(get(latest, 'Transaction Date'));
    let stock = 0;
    const barcodes = new Set<string>();
    let ean: string | null = null;
    let anyActive = false;
    for (const b of batches) {
      const at = parseDate(get(b, 'Transaction Date'));
      const qty = num(get(b, 'Current Stock'));
      // LIFO: prices come from the newest purchase. Same day (one invoice, two prices — the file
      // has no time or usable batch number): the batch with more units on the shelf.
      const sameDay = at.getTime() === latestAt.getTime();
      if (at.getTime() > latestAt.getTime() || (sameDay && b !== latest && (Number.isFinite(qty) ? qty : 0) > (num(get(latest, 'Current Stock')) || 0))) {
        latest = b;
        latestAt = at;
      }
      if (Number.isFinite(qty)) stock += qty;
      const bc = get(b, 'Barcode Value');
      if (/^\d{4,20}$/.test(bc)) barcodes.add(bc);
      const e = get(b, 'EAN Code');
      if (/^\d{8,14}$/.test(e)) ean = e; // scientific notation (Excel) is skipped
      if (get(b, 'Status').toLowerCase() !== 'inactive') anyActive = true;
    }
    const posName = get(latest, 'Item Name');
    const mrp = num(get(latest, 'MRP'));
    const selling = num(get(latest, 'Selling'));
    const gst = num(get(latest, 'Sales Tax %'));
    const reason = !posName
      ? 'no name'
      : /FREE GIFT/i.test(get(latest, 'TYPE')) || /^FREE GIFT/i.test(posName) || selling < 1
        ? 'free gift / not for sale'
      : !(selling > 0)
        ? 'selling price missing'
        : mrp > 0 && selling > mrp
          ? `selling ₹${selling} is above MRP ₹${mrp}`
          : !(gst >= 0 && gst <= 40)
            ? `GST ${get(latest, 'Sales Tax %')}% is not valid`
            : null;
    if (reason) {
      problems.push({ itemCode, name: posName, reason });
      continue;
    }
    const isLoose = /\b(BULK|LOOSE)\b/i.test(posName) || stock % 1 !== 0;
    const hsn = (get(latest, 'HSN_SAC Code') || get(latest, 'HSN_SAC Code (Transaction)')).replace(/\D/g, '').slice(0, 10);
    const brand = get(latest, 'BRAND');
    items.push({
      itemCode,
      name: displayName(posName),
      posName,
      department: get(latest, 'DEPT'),
      type: get(latest, 'TYPE'),
      brand: brand && !/^(NA|N\/A|NIL|NILL|0)$/i.test(brand) ? displayName(brand) : null,
      mrp: (mrp > 0 ? mrp : selling).toFixed(2),
      sellingPrice: selling.toFixed(2),
      gstRate: gst.toFixed(2),
      hsnCode: hsn || null,
      stock: Math.max(0, stock).toFixed(3),
      isLoose,
      packSize: isLoose ? null : packSizeOf(posName),
      ean,
      labelBarcodes: [...barcodes],
      isActive: anyActive,
      updatedAt: latestAt.getTime() > 0 ? latestAt : new Date(),
      batches: batches.length,
      costPrice: costOf(num(get(latest, 'Landing Cost')), num(get(latest, 'Purchase Price')), selling),
    });
  }
  return { items, rows: dataRows, departments: deptCount, problems };
}
