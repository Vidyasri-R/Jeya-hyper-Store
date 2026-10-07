import { and, desc, eq, inArray, sql } from 'drizzle-orm';
import { z } from 'zod';
import { db } from '../../db/client';
import { products } from '../../db/schema';
import { appConfigService } from '../app-config/app-config.service';
import { catalogCache } from './catalog.cache';
import { available, productCardColumns, type ProductCardRow } from './catalog.repository';
import { toProductCard, withPlaceholders } from './catalog.service';

/** Admin → Home lists: products the store picks for the customer home screen, in order. */
export const HOME_LISTS_KEY = 'home.lists';

export const homeListsSchema = z
  .object({
    offers: z.array(z.number().int().positive()).max(30),
    popular: z.array(z.number().int().positive()).max(60),
  })
  .strict()
  .refine((v) => new Set(v.offers).size === v.offers.length && new Set(v.popular).size === v.popular.length, 'A product is in a list twice');

export type HomeLists = z.infer<typeof homeListsSchema>;
export const DEFAULT_HOME_LISTS: HomeLists = { offers: [], popular: [] };

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

async function load() {
  const stored = homeListsSchema.safeParse(await appConfigService.getRaw(HOME_LISTS_KEY));
  const lists = stored.success ? stored.data : DEFAULT_HOME_LISTS;
  let [offers, popular] = await Promise.all([picked(lists.offers), picked(lists.popular)]);
  // Empty list (or everything chosen sold out): fall back to the automatic one.
  if (offers.length === 0) {
    offers = (await db
      .select(productCardColumns)
      .from(products)
      .where(and(eq(products.isActive, true), inStock, sql`${products.sellingPrice} < ${products.mrp}`))
      .orderBy(desc(discount), desc(products.sortRank), desc(products.photoPriority), products.id)
      .limit(AUTO_OFFERS)) as ProductCardRow[];
  }
  if (popular.length === 0) {
    popular = (await db
      .select(productCardColumns)
      .from(products)
      .where(and(eq(products.isActive, true), inStock))
      // Featured first, then fast movers (photo priority = how often and how recently it was restocked).
      .orderBy(desc(products.sortRank), desc(products.photoPriority), products.id)
      .limit(AUTO_POPULAR)) as ProductCardRow[];
  }
  return {
    offers: await withPlaceholders(offers.map(toProductCard)),
    popular: await withPlaceholders(popular.map(toProductCard)),
    /** True when the admin chose the list (the app may label it differently). */
    curated: { offers: lists.offers.length > 0, popular: lists.popular.length > 0 },
  };
}

export const homeListsService = {
  /** Customer home: "Today's offers" and "Popular in your store". */
  home: () => catalogCache.get('home-lists', TTL_MS, load),
};
