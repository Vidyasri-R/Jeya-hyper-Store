/**
 * "Same product, new code?" — the store gives a product a new JHS code when its EAN changes (new
 * packaging), and the stock file rarely has a usable EAN to connect them. So match on what stays the
 * same: brand, pack size and the name (spaces, dots and price tags ignored), with a believable price.
 */

export type CodeCandidate = {
  id: number;
  itemCode: string;
  name: string;
  brand: string | null;
  packSize: string | null;
  mrp: string;
  isActive: boolean;
  hasPhoto: boolean;
  /** Latest purchase in the stock file (the code being bought now is the "new" one). */
  lastPurchaseAt: Date | null;
};

export type CodePair = { old: CodeCandidate; new: CodeCandidate };

const PRICE_TAG = /\b(M\.?R\.?P|RS|RATE)\s*[.:]?\s*(\d+(?:\.\d+)?)\s*(?:\/-)?/gi;

/** "A2B  Madras Mixture MRP 10" and "A2B MADRAS MIXTURE MRP10" → "A2BMADRASMIXTURE". "XL+" ≠ "XL". */
export function baseName(name: string): string {
  return name.toUpperCase().replace(PRICE_TAG, ' ').replace(/\+/g, 'PLUS').replace(/[^A-Z0-9]+/g, '');
}

/** The price written in the name ("MRP 10" → "10"), if any. */
export function priceTag(name: string): string | null {
  const m = new RegExp(PRICE_TAG.source, 'i').exec(name);
  return m ? String(Number(m[2])) : null;
}

const squash = (s: string | null) => (s ?? '').toUpperCase().replace(/[^A-Z0-9]+/g, '');

/** Normal price moves between an old and a new pack: −20% … +30%. */
const MIN_RATIO = 0.8;
const MAX_RATIO = 1.3;

/**
 * Pairs (older code → newer code) that look like one product. [decided] = "oldId:newId" pairs the
 * admin already answered. The newer code must be on sale; the older one may already be gone.
 * Most useful first: the old code has a photo and the new one doesn't.
 */
export function sameProductPairs(products: CodeCandidate[], decided: Set<string>): CodePair[] {
  const groups = new Map<string, CodeCandidate[]>();
  for (const p of products) {
    const base = baseName(p.name);
    if (base.length < 4) continue;
    const key = `${base}|${squash(p.packSize)}|${squash(p.brand)}`;
    const list = groups.get(key);
    if (list) list.push(p);
    else groups.set(key, [p]);
  }
  const pairs: CodePair[] = [];
  for (const list of groups.values()) {
    if (list.length < 2) continue;
    // Oldest purchase first; same day → the lower (earlier) JHS code first.
    const sorted = [...list].sort(
      (a, b) => (a.lastPurchaseAt?.getTime() ?? 0) - (b.lastPurchaseAt?.getTime() ?? 0) || Number(a.itemCode) - Number(b.itemCode) || a.itemCode.localeCompare(b.itemCode),
    );
    for (let i = 1; i < sorted.length; i++) {
      const older = sorted[i - 1]!;
      const newer = sorted[i]!;
      if (!newer.isActive || decided.has(`${older.id}:${newer.id}`)) continue;
      const ratio = Number(newer.mrp) / Number(older.mrp);
      if (!(ratio >= MIN_RATIO && ratio <= MAX_RATIO)) continue;
      // "Agal Vizhakku Rs 15" and "Rs 20" are two products, not one repacked.
      const a = priceTag(older.name);
      const b = priceTag(newer.name);
      if (a && b && a !== b) continue;
      pairs.push({ old: older, new: newer });
    }
  }
  const useful = (p: CodePair) => (p.old.hasPhoto && !p.new.hasPhoto ? 0 : 1);
  return pairs.sort((x, y) => useful(x) - useful(y) || (y.new.lastPurchaseAt?.getTime() ?? 0) - (x.new.lastPurchaseAt?.getTime() ?? 0));
}
