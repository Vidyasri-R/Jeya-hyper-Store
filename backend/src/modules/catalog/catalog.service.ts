import { decodeCursor, encodeCursor } from '../../common/cursor';
import { AppError } from '../../common/errors';
import { displayQty, toPaise } from '../../common/money';
import type { ProductOptions } from '../../db/schema';
import { catalogCache } from './catalog.cache';
import { catalogRepository, sortValue, type ListingSort, type ProductCardRow } from './catalog.repository';
import type { ProductListQuery } from './catalog.schemas';
import { purchaseLimits, type StockStatus } from './purchase-rules';
import { parseSearch } from './search-query';

const TREE_TTL_MS = 5 * 60 * 1000;
/** Listing / search / product pages. The sync and admin edits invalidate the cache sooner. */
const PAGE_TTL_MS = 60 * 1000;
const MAX_SEARCH_OFFSET = 1000;

export type CategoryNode = {
  id: number;
  name: string;
  slug: string;
  imageUrl: string | null;
  productCount: number;
  children: CategoryNode[];
};

type CategoryIndex = {
  roots: CategoryNode[];
  bySlug: Map<string, CategoryNode>;
  byId: Map<number, CategoryNode>;
  parentOf: Map<number, number | null>;
};


export type ProductCard = {
  id: number;
  slug: string;
  name: string;
  nameTa: string | null;
  brand: string | null;
  categoryId: number | null;
  mrp: string;
  sellingPrice: string;
  discountPercent: number;
  unit: ProductCardRow['unit'];
  packSize: string | null;
  isLoose: boolean;
  minOrderQty: string;
  qtyStep: string;
  /** Most the customer can add right now (stock- and rule-limited). "0" when out of stock. */
  maxPurchasableQty: string;
  stockStatus: StockStatus;
  imageUrl: string | null;
  /** Until the product has its own photo: a general photo of its category (or the parent's). */
  placeholderImageUrl: string | null;
  /** This size's name in the size picker ("500 g", "₹10"); null when the product has one size. */
  variantLabel: string | null;
  /** Choices the customer must pick when adding it (one POS item, several flavours/colours). */
  options: ProductOptions | null;
  /** All sizes (this one included, cheapest first) when there is more than one. */
  variants: Omit<ProductCard, 'variants'>[] | null;
};

function buildIndex(
  rows: Awaited<ReturnType<typeof catalogRepository.listActiveCategories>>,
  counts: Awaited<ReturnType<typeof catalogRepository.activeProductCountsByCategory>>,
): CategoryIndex {
  const ownCount = new Map(counts.map((row) => [row.categoryId, Number(row.count)]));
  const byId = new Map<number, CategoryNode>();
  const parentOf = new Map<number, number | null>();
  for (const row of rows) {
    byId.set(row.id, {
      id: row.id,
      name: row.name,
      slug: row.slug,
      imageUrl: row.imageUrl,
      productCount: ownCount.get(row.id) ?? 0,
      children: [],
    });
    parentOf.set(row.id, row.parentId);
  }

  const roots: CategoryNode[] = [];
  for (const row of rows) {
    const node = byId.get(row.id)!;
    const parent = row.parentId !== null ? byId.get(row.parentId) : undefined;
    // An inactive/missing parent promotes the child to the root rather than hiding it.
    if (parent) parent.children.push(node);
    else roots.push(node);
  }

  const rollUp = (node: CategoryNode, depth: number): number => {
    if (depth > 10) return node.productCount; // cycle guard against bad POS data
    node.productCount += node.children.reduce((sum, child) => sum + rollUp(child, depth + 1), 0);
    return node.productCount;
  };
  roots.forEach((root) => rollUp(root, 0));

  return { roots, byId, parentOf, bySlug: new Map([...byId.values()].map((node) => [node.slug, node])) };
}

async function categoryIndex(): Promise<CategoryIndex> {
  return catalogCache.get('category-index', TREE_TTL_MS, async () => {
    const [rows, counts] = await Promise.all([
      catalogRepository.listActiveCategories(),
      catalogRepository.activeProductCountsByCategory(),
    ]);
    return buildIndex(rows, counts);
  });
}

function descendantIds(node: CategoryNode): number[] {
  const ids: number[] = [];
  const stack = [node];
  while (stack.length > 0) {
    const current = stack.pop()!;
    ids.push(current.id);
    stack.push(...current.children);
  }
  return ids;
}

function pruneEmpty(nodes: CategoryNode[]): CategoryNode[] {
  return nodes
    .filter((node) => node.productCount > 0)
    .map((node) => ({ ...node, children: pruneEmpty(node.children) }));
}

export function toProductCard(row: ProductCardRow): ProductCard {
  const mrp = toPaise(row.mrp);
  const price = toPaise(row.sellingPrice);
  const limits = purchaseLimits(row);

  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    nameTa: row.nameTa,
    brand: row.brand,
    categoryId: row.categoryId,
    mrp: row.mrp,
    sellingPrice: row.sellingPrice,
    discountPercent: mrp > 0 && price < mrp ? Math.round(((mrp - price) / mrp) * 100) : 0,
    unit: row.unit,
    packSize: row.packSize,
    isLoose: row.isLoose,
    minOrderQty: displayQty(limits.minMilli),
    qtyStep: displayQty(limits.stepMilli),
    maxPurchasableQty: displayQty(limits.maxMilli),
    stockStatus: limits.stockStatus,
    imageUrl: row.imageUrl,
    placeholderImageUrl: null,
    variantLabel: row.variantGroup ? row.variantLabel : null,
    options: row.options && row.options.values.length > 0 ? row.options : null,
    variants: null,
  };
}

/** Keep the first row of each size group (search / home lists can match several sizes). */
function firstPerGroup(rows: ProductCardRow[]): ProductCardRow[] {
  const seen = new Set<string>();
  return rows.filter((r) => !r.variantGroup || (!seen.has(r.variantGroup) && seen.add(r.variantGroup)));
}

/**
 * Rows → cards for the apps: stand-in photos, and each card carries its other sizes. With
 * [collapse], a product shows once even if several of its sizes matched (the first one is shown).
 */
export async function presentProducts(rows: ProductCardRow[], options: { collapse?: boolean } = {}): Promise<ProductCard[]> {
  const kept = options.collapse ? firstPerGroup(rows) : rows;
  const cards = await withPlaceholders(kept.map(toProductCard));
  const groups = [...new Set(kept.flatMap((r) => (r.variantGroup ? [r.variantGroup] : [])))];
  if (groups.length === 0) return cards;
  const sizes = await catalogRepository.variantsOf(groups);
  const sizeCards = await withPlaceholders(sizes.map(toProductCard));
  const byGroup = new Map<string, Omit<ProductCard, 'variants'>[]>();
  sizes.forEach((row, i) => {
    const { variants: _drop, ...card } = sizeCards[i]!;
    byGroup.set(row.variantGroup!, [...(byGroup.get(row.variantGroup!) ?? []), card]);
  });
  return cards.map((card, i) => {
    const list = kept[i]!.variantGroup ? byGroup.get(kept[i]!.variantGroup!) : undefined;
    return list && list.length > 1 ? { ...card, variants: list } : { ...card, variantLabel: null };
  });
}

/** The category's photo, or the nearest parent's that has one. */
function categoryImage(index: CategoryIndex, categoryId: number | null): string | null {
  for (let id = categoryId, depth = 0; id !== null && depth < 10; depth++) {
    const node = index.byId.get(id);
    if (!node) return null;
    if (node.imageUrl) return node.imageUrl;
    id = index.parentOf.get(id) ?? null;
  }
  return null;
}

/** Fills placeholderImageUrl for products without a photo of their own. */
export async function withPlaceholders<T extends { imageUrl: string | null; categoryId: number | null; placeholderImageUrl?: string | null }>(cards: T[]): Promise<T[]> {
  if (cards.every((c) => c.imageUrl)) return cards;
  const index = await categoryIndex();
  return cards.map((c) => (c.imageUrl ? c : { ...c, placeholderImageUrl: categoryImage(index, c.categoryId) }));
}

/** Same, for one category id (staff order lines). */
export async function placeholderFor(categoryId: number | null): Promise<string | null> {
  return categoryImage(await categoryIndex(), categoryId);
}

async function resolveCategoryIds(slug: string | undefined): Promise<number[] | null> {
  if (!slug) return null;
  const node = (await categoryIndex()).bySlug.get(slug);
  if (!node) throw AppError.notFound('Category');
  return descendantIds(node);
}

export const catalogService = {
  async categoryTree(): Promise<CategoryNode[]> {
    return pruneEmpty((await categoryIndex()).roots);
  },

  /** Listing pages are cached briefly: stock shown may lag ≤ 1 min; cart and checkout always read live. */
  async listProducts(query: ProductListQuery) {
    const key = `list:${JSON.stringify([query.category ?? null, query.q ?? null, query.sort ?? null, query.inStock, query.cursor ?? null, query.limit])}`;
    return catalogCache.get(key, PAGE_TTL_MS, () => catalogService.loadProducts(query));
  },

  async loadProducts(query: ProductListQuery) {
    const categoryIds = await resolveCategoryIds(query.category);

    if (query.q) {
      const search = parseSearch(query.q);
      const offset = query.cursor ? Number(decodeCursor(query.cursor).v) : 0;
      if (!Number.isSafeInteger(offset) || offset < 0 || offset > MAX_SEARCH_OFFSET) {
        throw new AppError('BAD_REQUEST', 'Invalid pagination cursor', { reason: 'cursor_invalid' });
      }
      const sort = query.sort === 'price_asc' || query.sort === 'price_desc' ? query.sort : 'relevance';
      const rows = await catalogRepository.searchProducts({
        search,
        categoryIds,
        inStockOnly: query.inStock,
        sort,
        offset,
        limit: query.limit,
      });
      const hasMore = rows.length > query.limit && offset + query.limit < MAX_SEARCH_OFFSET;
      return {
        items: await presentProducts(rows.slice(0, query.limit), { collapse: true }),
        nextCursor: hasMore ? encodeCursor({ v: offset + query.limit, id: 0 }) : null,
        sort,
      };
    }

    const sort: ListingSort = query.sort && query.sort !== 'relevance' ? query.sort : 'popular';
    const rows = await catalogRepository.listProducts({
      categoryIds,
      inStockOnly: query.inStock,
      sort,
      cursor: query.cursor ? decodeCursor(query.cursor) : null,
      limit: query.limit,
    });
    const page = rows.slice(0, query.limit);
    const last = page.at(-1);
    return {
      items: await presentProducts(page),
      nextCursor: rows.length > query.limit && last ? encodeCursor({ v: sortValue(last, sort), id: last.id }) : null,
      sort,
    };
  },

  async suggest(q: string) {
    return catalogCache.get(`suggest:${q.trim().toLowerCase()}`, PAGE_TTL_MS, () => catalogService.loadSuggestions(q));
  },

  async loadSuggestions(q: string) {
    const rows = await catalogRepository.searchProducts({
      search: parseSearch(q),
      categoryIds: null,
      inStockOnly: false,
      sort: 'relevance',
      offset: 0,
      limit: 8,
    });
    return withPlaceholders(
      rows.slice(0, 8).map((row) => ({ slug: row.slug, name: row.name, imageUrl: row.imageUrl, categoryId: row.categoryId, placeholderImageUrl: null as string | null })),
    );
  },

  async productDetail(slug: string) {
    return catalogCache.get(`product:${slug}`, PAGE_TTL_MS, () => catalogService.loadProductDetail(slug));
  },

  async loadProductDetail(slug: string) {
    const row = await catalogRepository.findActiveProductBySlug(slug);
    if (!row) throw AppError.notFound('Product');

    const index = await categoryIndex();
    const breadcrumb: { id: number; name: string; slug: string }[] = [];
    for (let id = row.categoryId, depth = 0; id !== null && id !== undefined && depth < 10; depth++) {
      const node = index.byId.get(id);
      if (!node) break;
      breadcrumb.unshift({ id: node.id, name: node.name, slug: node.slug });
      id = index.parentOf.get(id) ?? null;
    }

    const [card] = await presentProducts([row]);
    return {
      ...card!,
      description: row.description,
      barcode: row.barcode,
      hsnCode: row.hsnCode,
      gstRate: row.gstRate,
      breadcrumb,
    };
  },
};
