import { and, desc, eq, inArray, notInArray, sql } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '../../db/client';
import { products } from '../../db/schema';
import { appConfigService } from '../app-config/app-config.service';
import { catalogCache } from './catalog.cache';
import { available, productCardColumns, type ProductCardRow } from './catalog.repository';
import { presentProducts } from './catalog.service';

/**
 * Admin → Home lists. The automatic lists always run; the admin adds extra products on top
 * ([offers] / [popular]: pinned, shown first in this order) and hides automatic ones they don't want
 * ([hiddenOffers] / [hiddenPopular]).
 */
export const HOME_LISTS_KEY = 'home.lists';

const ids = (max: number) => z.array(z.number().int().positive()).max(max);
const unique = (a: number[] | undefined) => !a || new Set(a).size === a.length;

export const homeListsSchema = z
  .object({
    offers: ids(100),
    popular: ids(100),
    hiddenOffers: ids(500).optional(),
    hiddenPopular: ids(500).optional(),
  })
  .strict()
  .refine((v) => unique(v.offers) && unique(v.popular) && unique(v.hiddenOffers) && unique(v.hiddenPopular), 'A product is in a list twice');

export type HomeLists = z.infer<typeof homeListsSchema>;
export const DEFAULT_HOME_LISTS: HomeLists = { offers: [], popular: [], hiddenOffers: [], hiddenPopular: [] };

const TTL_MS = 60 * 1000;
const AUTO_OFFERS = 12;
const AUTO_POPULAR = 20;

const inStock = sql`${available} > 0`;
const discount = sql`(${products.mrp} - ${products.sellingPrice}) / NULLIF(${products.mrp}, 0)`;

/** The chosen products that are on sale and in stock, in the admin's order. */
async function picked(ids: number[]): Promise<ProductCardRow[]> {
  if (ids.length === 0) return [];
  const rows = (await db
    .select(productCardColumns)
    .from(products)
    .where(and(inArray(products.id, ids), eq(products.isActive, true), inStock))) as ProductCardRow[];
  const byId = new Map(rows.map((r) => [r.id, r]));
  return ids.flatMap((id) => byId.get(id) ?? []);
}

/** Automatic "Today's offers": in stock and below MRP, biggest discount first (then featured, fast movers). [skip]: hidden or pinned. */
export async function automaticOffers(skip: number[] = []): Promise<ProductCardRow[]> {
  const rows = (await db
    .select(productCardColumns)
    .from(products)
    .where(and(eq(products.isActive, true), inStock, sql`${products.sellingPrice} < ${products.mrp}`, ...(skip.length ? [notInArray(products.id, skip)] : [])))
    .orderBy(desc(discount), desc(products.sortRank), desc(products.photoPriority), products.id)
    .limit(AUTO_OFFERS * 3)) as ProductCardRow[];
  // One per product (sizes would repeat it).
  const seen = new Set<string>();
  return rows.filter((r) => !r.variantGroup || (!seen.has(r.variantGroup) && seen.add(r.variantGroup))).slice(0, AUTO_OFFERS);
}

/** Automatic "Popular in your store": featured first, then fast movers (restocked often and lately). */
export async function automaticPopular(skip: number[] = []): Promise<ProductCardRow[]> {
  return (await db
    .select(productCardColumns)
    .from(products)
    .where(and(eq(products.isActive, true), inStock, eq(products.isVariantLeader, true), ...(skip.length ? [notInArray(products.id, skip)] : [])))
    .orderBy(desc(products.sortRank), desc(products.photoPriority), products.id)
    .limit(AUTO_POPULAR)) as ProductCardRow[];
}

async function load() {
  const stored = homeListsSchema.safeParse(await appConfigService.getRaw(HOME_LISTS_KEY));
  const lists = stored.success ? stored.data : DEFAULT_HOME_LISTS;
  // Pinned extras first, then the automatic list without what the admin hid (or already pinned).
  const [pinnedOffers, pinnedPopular, autoOffers, autoPopular] = await Promise.all([
    picked(lists.offers),
    picked(lists.popular),
    automaticOffers([...(lists.hiddenOffers ?? []), ...lists.offers]),
    automaticPopular([...(lists.hiddenPopular ?? []), ...lists.popular]),
  ]);
  const offers = [...pinnedOffers, ...autoOffers];
  const popular = [...pinnedPopular, ...autoPopular];
  return {
    offers: await presentProducts(offers, { collapse: true }),
    popular: await presentProducts(popular, { collapse: true }),
    /** How many of each list the admin pinned (they come first). */
    curated: { offers: pinnedOffers.length, popular: pinnedPopular.length },
  };
}

export const homeListsService = {
  /** Customer home: "Today's offers" and "Popular in your store". */
  home: () => catalogCache.get('home-lists', TTL_MS, load),
};
