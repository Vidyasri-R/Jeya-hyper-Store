import { and, asc, desc, eq, inArray, sql, type SQL } from 'drizzle-orm';
import type { Cursor } from '../../common/cursor';
import { db, type DbExecutor } from '../../db/client';
import { categories, products, type ProductOptions } from '../../db/schema';
import type { AnyPgColumn } from 'drizzle-orm/pg-core';
import type { ParsedSearch } from './search-query';

/** Below this length trigram matching is noise ("sam" ≈ "Sakthi"); prefix full-text handles it. */
const MIN_FUZZY_LENGTH = 4;
const SHORT_FUZZY_LENGTH = 5;
const SHORT_FUZZY_MIN = 0.5;

/**
 * Sets the `<%` threshold for this statement only. As an uncorrelated subquery it
 * becomes a One-Time Filter that Postgres evaluates before the scan starts, so it
 * applies on every pooled backend (the DB-level default from migration 0003 only
 * reaches connections opened after it). One round trip, no transaction needed.
 * "poni rise" → "Ponni Raw Rice" scores 0.42.
 */
const FUZZY_THRESHOLD_GATE = sql`(SELECT set_config('pg_trgm.word_similarity_threshold', '0.4', true)) IS NOT NULL`;

export const available = sql<string>`(${products.stockQuantity} - ${products.reservedQuantity} - ${products.safetyStock})`;

export const productCardColumns = {
  id: products.id,
  slug: products.slug,
  name: products.name,
  nameTa: products.nameTa,
  brand: products.brand,
  categoryId: products.categoryId,
  mrp: products.mrp,
  sellingPrice: products.sellingPrice,
  unit: products.unit,
  packSize: products.packSize,
  isLoose: products.isLoose,
  minOrderQty: products.minOrderQty,
  qtyStep: products.qtyStep,
  maxOrderQty: products.maxOrderQty,
  imageUrl: products.imageUrl,
  available,
  sortRank: products.sortRank,
  variantGroup: products.variantGroup,
  variantLabel: products.variantLabel,
  options: products.options,
};

export type ProductCardRow = {
  id: number;
  slug: string;
  name: string;
  nameTa: string | null;
  brand: string | null;
  categoryId: number | null;
  mrp: string;
  sellingPrice: string;
  unit: (typeof products.unit.enumValues)[number];
  packSize: string | null;
  isLoose: boolean;
  minOrderQty: string;
  qtyStep: string;
  maxOrderQty: string | null;
  imageUrl: string | null;
  available: string;
  sortRank: number;
  variantGroup: string | null;
  variantLabel: string | null;
  options: ProductOptions | null;
};

export type ListingSort = 'popular' | 'price_asc' | 'price_desc' | 'name_asc';

const SORTS: Record<ListingSort, { column: AnyPgColumn; dir: 'asc' | 'desc'; cast: string }> = {
  popular: { column: products.sortRank, dir: 'desc', cast: 'int' },
  price_asc: { column: products.sellingPrice, dir: 'asc', cast: 'numeric' },
  price_desc: { column: products.sellingPrice, dir: 'desc', cast: 'numeric' },
  name_asc: { column: products.name, dir: 'asc', cast: 'text' },
};

export function sortValue(row: ProductCardRow, sort: ListingSort): string | number {
  if (sort === 'popular') return row.sortRank;
  if (sort === 'name_asc') return row.name;
  return row.sellingPrice;
}

function baseFilters(categoryIds: number[] | null, inStockOnly: boolean): SQL[] {
  const filters: SQL[] = [eq(products.isActive, true)];
  if (categoryIds) filters.push(inArray(products.categoryId, categoryIds.length > 0 ? categoryIds : [-1]));
  if (inStockOnly) filters.push(sql`${available} > 0`);
  return filters;
}

export const catalogRepository = {
  async listActiveCategories(executor: DbExecutor = db) {
    return executor
      .select({
        id: categories.id,
        name: categories.name,
        slug: categories.slug,
        parentId: categories.parentId,
        imageUrl: categories.imageUrl,
        tileImageUrl: categories.tileImageUrl,
        sortOrder: categories.sortOrder,
      })
      .from(categories)
      .where(eq(categories.isActive, true))
      .orderBy(asc(categories.sortOrder), asc(categories.name));
  },

  async activeProductCountsByCategory(executor: DbExecutor = db) {
    return executor
      .select({ categoryId: products.categoryId, count: sql<number>`count(*)::int` })
      .from(products)
      .where(and(eq(products.isActive, true), eq(products.isVariantLeader, true))) // one per product, all sizes together
      .groupBy(products.categoryId);
  },

  /** Keyset page: ORDER BY <sort col> <dir>, id ASC. Fetches limit+1 to detect a next page. */
  async listProducts(params: {
    categoryIds: number[] | null;
    inStockOnly: boolean;
    sort: ListingSort;
    cursor: Cursor | null;
    limit: number;
  }): Promise<ProductCardRow[]> {
    const { column, dir, cast } = SORTS[params.sort];
    // One card per product: other sizes come along as its variants.
    const filters = [...baseFilters(params.categoryIds, params.inStockOnly), eq(products.isVariantLeader, true)];

    if (params.cursor) {
      const value = sql`${params.cursor.v}::${sql.raw(cast)}`;
      const beyond = dir === 'asc' ? sql`${column} > ${value}` : sql`${column} < ${value}`;
      filters.push(sql`(${beyond} OR (${column} = ${value} AND ${products.id} > ${params.cursor.id}))`);
    }

    return db
      .select(productCardColumns)
      .from(products)
      .where(and(...filters))
      .orderBy(dir === 'asc' ? asc(column) : desc(column), asc(products.id))
      .limit(params.limit + 1) as Promise<ProductCardRow[]>;
  },

  /**
   * Ranked search: prefix full-text (English + Tamil tokens) OR typo-tolerant
   * trigram OR exact barcode/item code — one round trip, GIN-indexed.
   */
  async searchProducts(params: {
    search: ParsedSearch;
    categoryIds: number[] | null;
    inStockOnly: boolean;
    sort: 'relevance' | 'price_asc' | 'price_desc';
    offset: number;
    limit: number;
  }): Promise<ProductCardRow[]> {
    const { search } = params;
    const tsq = search.tsquery ? sql`to_tsquery('simple', ${search.tsquery})` : null;

    const fuzzy = search.text.length >= MIN_FUZZY_LENGTH;
    // A few typed letters match too much by chance ("webf" ≈ "Set Wet"): short queries need a closer match.
    const shortFuzzy = search.text.length <= SHORT_FUZZY_LENGTH;
    const matchers: SQL[] = fuzzy
      ? [shortFuzzy ? sql`(${search.text} <% ${products.name} AND word_similarity(${search.text}, ${products.name}) >= ${SHORT_FUZZY_MIN})` : sql`${search.text} <% ${products.name}`]
      : [];
    if (tsq) matchers.push(sql`${products.searchVector} @@ ${tsq}`);
    if (search.code) {
      matchers.push(sql`${products.barcode} = ${search.code}`, sql`upper(${products.itemCode}) = ${search.code}`);
    }

    const exactCode = search.code
      ? sql`CASE WHEN ${products.barcode} = ${search.code} OR upper(${products.itemCode}) = ${search.code} THEN 10 ELSE 0 END`
      : sql`0`;
    const rank = sql`(
      ${tsq ? sql`ts_rank(${products.searchVector}, ${tsq}) * 2` : sql`0`}
      + ${fuzzy ? sql`word_similarity(${search.text}, ${products.name})` : sql`0`}
      + ${exactCode}
      + CASE WHEN ${available} > 0 THEN 0.5 ELSE 0 END
      + ${products.sortRank} * 0.001
    )`;

    const orderBy =
      params.sort === 'price_asc'
        ? [asc(products.sellingPrice), asc(products.id)]
        : params.sort === 'price_desc'
          ? [desc(products.sellingPrice), asc(products.id)]
          : [desc(rank), asc(products.id)];

    if (matchers.length === 0) return [];
    return db
      .select(productCardColumns)
      .from(products)
      .where(
        and(
          ...(fuzzy ? [FUZZY_THRESHOLD_GATE] : []),
          ...baseFilters(params.categoryIds, params.inStockOnly),
          sql`(${sql.join(matchers, sql` OR `)})`,
        ),
      )
      .orderBy(...orderBy)
      .offset(params.offset)
      .limit(params.limit + 1) as Promise<ProductCardRow[]>;
  },

  /** Every size on sale in these groups (for the size picker). */
  async variantsOf(groups: string[]): Promise<ProductCardRow[]> {
    if (groups.length === 0) return [];
    return db
      .select(productCardColumns)
      .from(products)
      .where(and(eq(products.isActive, true), inArray(products.variantGroup, groups)))
      .orderBy(asc(products.sellingPrice), asc(products.id)) as Promise<ProductCardRow[]>;
  },

  async findActiveProductBySlug(slug: string) {
    const [row] = await db
      .select({
        ...productCardColumns,
        description: products.description,
        barcode: products.barcode,
        hsnCode: products.hsnCode,
        gstRate: products.gstRate,
      })
      .from(products)
      .where(and(eq(products.slug, slug), eq(products.isActive, true)))
      .limit(1);
    return row ?? null;
  },
};
