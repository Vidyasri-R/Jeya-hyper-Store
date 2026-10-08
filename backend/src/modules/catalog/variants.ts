import { eq, sql } from 'drizzle-orm';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { products } from '../../db/schema';
import { catalogCache } from './catalog.cache';

/**
 * Sizes of one product ("Bru Instant 50g / 100g / 200g", or the POS's price points "Arun ₹10 / ₹20")
 * are separate POS items with their own price and stock. The shop shows them as ONE card with a
 * size picker: products with the same name-without-size in the same category share a variant
 * group, and one of them (the leader) stands for the group in listings.
 */

/** Size / pack words that differ between sizes of the same product. */
const SIZE_WORDS =
  /\b\d+(?:\.\d+)?\s*(?:kg|kgs|g|gm|gms|gram|grams|mg|ml|l|lt|ltr|ltrs|litre|litres|liter|pcs|pc|n|nos|no|s|x\s*\d+)\b|\b(?:loose|bulk|pouch|jar|bot|bottle|btl|pkt|packet|pack|refill|tin|can|box|combo)\b/gi;
/** Pack words worth showing next to the size ("200 g Jar" vs "200 g Pouch"). */
const PACK_WORDS = /\b(loose|pouch|jar|bottle|refill|tin|can|box|combo)\b/i;

export function variantKey(name: string, categoryId: number | null): string | null {
  const base = name.toLowerCase().replace(SIZE_WORDS, ' ').replace(/[^a-z0-9]+/g, ' ').trim();
  if (base.length < 2) return null;
  return `${categoryId ?? 0}:${base}`.slice(0, 160);
}

type Member = { id: number; name: string; packSize: string | null; sellingPrice: string };

const rupees = (price: string) => `₹${Number(price) % 1 === 0 ? Number(price).toFixed(0) : Number(price).toFixed(2)}`;

/** What the size picker shows for each member: "500 g", "200 g Jar", or "₹10" when there's no size. */
export function variantLabels(members: Member[]): Map<number, string> {
  const raw = members.map((m) => {
    const pack = m.name.match(PACK_WORDS)?.[1];
    const size = m.packSize ?? '';
    const label = [size, pack ? pack[0]!.toUpperCase() + pack.slice(1).toLowerCase() : ''].filter(Boolean).join(' ');
    return { m, label: label || rupees(m.sellingPrice) };
  });
  const count = new Map<string, number>();
  for (const r of raw) count.set(r.label, (count.get(r.label) ?? 0) + 1);
  // Same size twice (two batches / MRPs in the POS): tell them apart by price.
  return new Map(raw.map((r) => [r.m.id, (count.get(r.label) ?? 0) > 1 && !r.label.startsWith('₹') ? `${r.label} · ${rupees(r.m.sellingPrice)}` : r.label]));
}

type Row = Member & { categoryId: number | null; available: number; sortRank: number; photoPriority: number };

/** Which member stands for the group: in stock first, then featured, then the fastest mover. */
export function pickLeader(members: Row[]): number {
  return [...members].sort(
    (a, b) =>
      Number(b.available > 0) - Number(a.available > 0) ||
      b.sortRank - a.sortRank ||
      b.photoPriority - a.photoPriority ||
      Number(a.sellingPrice) - Number(b.sellingPrice) ||
      a.id - b.id,
  )[0]!.id;
}

/** Recompute groups, labels and leaders for every product on sale (after each stock import). */
export async function regroupVariants() {
  const rows = (await db
    .select({
      id: products.id,
      name: products.name,
      packSize: products.packSize,
      sellingPrice: products.sellingPrice,
      categoryId: products.categoryId,
      available: sql<number>`(${products.stockQuantity} - ${products.reservedQuantity} - ${products.safetyStock})::float`,
      sortRank: products.sortRank,
      photoPriority: products.photoPriority,
      group: products.variantGroup,
      label: products.variantLabel,
      leader: products.isVariantLeader,
    })
    .from(products)
    .where(eq(products.isActive, true))) as (Row & { group: string | null; label: string | null; leader: boolean })[];

  const groups = new Map<string, typeof rows>();
  for (const r of rows) {
    const key = variantKey(r.name, r.categoryId);
    if (key) groups.set(key, [...(groups.get(key) ?? []), r]);
  }
  const want = new Map<number, { group: string | null; label: string | null; leader: boolean }>();
  for (const r of rows) want.set(r.id, { group: null, label: null, leader: true });
  let grouped = 0;
  for (const [key, members] of groups) {
    if (members.length < 2) continue;
    grouped++;
    const labels = variantLabels(members);
    const leader = pickLeader(members);
    for (const m of members) want.set(m.id, { group: key, label: labels.get(m.id) ?? null, leader: m.id === leader });
  }
  const changed = rows.filter((r) => {
    const w = want.get(r.id)!;
    return w.group !== r.group || w.label !== r.label || w.leader !== r.leader;
  });
  for (let k = 0; k < changed.length; k += 500) {
    const values = changed.slice(k, k + 500).map((r) => {
      const w = want.get(r.id)!;
      return sql`(${r.id}::bigint, ${w.group}::varchar, ${w.label}::varchar, ${w.leader}::boolean)`;
    });
    await db.execute(sql`
      UPDATE ${products} AS p SET variant_group = v.g, variant_label = v.l, is_variant_leader = v.leader
      FROM (VALUES ${sql.join(values, sql`, `)}) AS v(id, g, l, leader) WHERE p.id = v.id`);
  }
  // Products no longer on sale lead nothing (a group's other sizes take over).
  await db.execute(sql`UPDATE ${products} SET is_variant_leader = true, variant_group = NULL, variant_label = NULL WHERE NOT is_active AND variant_group IS NOT NULL`);
  catalogCache.invalidate();
  logger.info({ groups: grouped, changed: changed.length }, 'product sizes regrouped');
  return { groups: grouped, changed: changed.length };
}
