import { decodeCursor, encodeCursor } from '../../common/cursor';
import { AppError } from '../../common/errors';
import { catalogCache } from './catalog.cache';
import { catalogRepository, sortValue, type ListingSort, type ProductCardRow } from './catalog.repository';
import type { ProductListQuery } from './catalog.schemas';
import { parseSearch } from './search-query';

const TREE_TTL_MS = 5 * 60 * 1000;
const MAX_SEARCH_OFFSET = 1000;
/** Shown as "Only a few left" below this many purchasable units. */
const LOW_STOCK_UNITS = 5;
/** Cap on qty per line when the product has no explicit max. */
const DEFAULT_MAX_PER_LINE = 50;

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

export type StockStatus = 'in_stock' | 'low_stock' | 'out_of_stock';

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

/** Decimal-safe-enough helpers: inputs are numeric(12,2/3) strings, outputs re-stringified at fixed scale. */
function toQty(value: number): string {
  return Math.max(0, value).toFixed(3).replace(/\.?0+$/, '') || '0';
}

export function toProductCard(row: ProductCardRow): ProductCard {
  const mrp = Number(row.mrp);
  const price = Number(row.sellingPrice);
  const available = Number(row.available);
  const step = Number(row.qtyStep) || 1;
  const min = Number(row.minOrderQty) || step;
  const ruleMax = row.maxOrderQty !== null ? Number(row.maxOrderQty) : row.isLoose ? 10 : DEFAULT_MAX_PER_LINE;

  // Round down to a whole number of steps so the app never offers an unsellable qty.
  const rawMax = Math.min(available, ruleMax);
  const steppedMax = rawMax >= min ? Math.floor((rawMax + 1e-9) / step) * step : 0;

  const stockStatus: StockStatus =
    steppedMax <= 0 ? 'out_of_stock' : available < LOW_STOCK_UNITS * step ? 'low_stock' : 'in_stock';

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
    minOrderQty: toQty(min),
    qtyStep: toQty(step),
    maxPurchasableQty: toQty(steppedMax),
    stockStatus,
    imageUrl: row.imageUrl,
  };
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

  async listProducts(query: ProductListQuery) {
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
        items: rows.slice(0, query.limit).map(toProductCard),
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
      items: page.map(toProductCard),
      nextCursor: rows.length > query.limit && last ? encodeCursor({ v: sortValue(last, sort), id: last.id }) : null,
      sort,
    };
  },

  async suggest(q: string) {
    const rows = await catalogRepository.searchProducts({
      search: parseSearch(q),
      categoryIds: null,
      inStockOnly: false,
      sort: 'relevance',
      offset: 0,
      limit: 8,
    });
    return rows.slice(0, 8).map((row) => ({ slug: row.slug, name: row.name, imageUrl: row.imageUrl }));
  },

  async productDetail(slug: string) {
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

    return {
      ...toProductCard(row),
      description: row.description,
      barcode: row.barcode,
      hsnCode: row.hsnCode,
      gstRate: row.gstRate,
      breadcrumb,
    };
  },
};
