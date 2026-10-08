import { and, eq, isNotNull, lt, notInArray, sql } from 'drizzle-orm';
import { withRetry } from '../../common/retry';
import { slugWithId } from '../../common/slug';
import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { categories, products, type NewProduct } from '../../db/schema';
import { posClient, type PosCatalogClient } from '../../integrations/gofrugal';
import { mapPosUnit, posCategorySchema, posItemSchema, type PosCategory, type PosItem } from '../../integrations/gofrugal/types';
import { catalogCache } from '../catalog/catalog.cache';
import { syncStateRepository } from './sync-state.repository';

export const SYNC_KEYS = {
  ITEMS: 'gofrugal_items',
  ITEMS_FULL: 'gofrugal_items_full',
} as const;

/** Re-read this much before the watermark each delta run to absorb POS clock skew. */
const WATERMARK_OVERLAP_MS = 2 * 60 * 1000;
/** Full sync refuses to deactivate if it saw fewer than this share of active products. */
const MIN_FULL_SYNC_COVERAGE = 0.5;
const MAX_LOGGED_REJECTS = 10;

export type SyncMode = 'delta' | 'full';

export type SyncResult =
  | { status: 'skipped'; reason: 'already_running' }
  | {
      status: 'success';
      mode: SyncMode;
      categories: { upserted: number; rejected: number };
      items: { fetched: number; changed: number; rejected: number; deactivated: number };
      pages: number;
      watermark: string | null;
      durationMs: number;
    };

/** Columns the POS owns. Everything else (slug, images, description, Tamil name, ranking, safety stock, order qty rules) is ours. */
const POS_OWNED = [
  'item_code',
  'barcode',
  'name',
  'brand',
  'category_id',
  'mrp',
  'selling_price',
  'hsn_code',
  'gst_rate',
  'stock_quantity',
  'unit',
  'pack_size',
  'is_loose',
  'is_active',
  'gofrugal_updated_at',
] as const;

const excluded = (column: string) => sql.raw(`excluded."${column}"`);
const current = (column: string) => sql.raw(`"products"."${column}"`);

/** POS columns the admin may change by hand; a changed one stays as the admin set it (products.locked_fields). */
export const ADMIN_LOCKABLE = ['name', 'brand', 'category_id', 'pack_size', 'is_active'] as const;
export type AdminLockable = (typeof ADMIN_LOCKABLE)[number];

/** The incoming POS value, unless the admin locked this column on the product. */
const posValue = (column: string) =>
  (ADMIN_LOCKABLE as readonly string[]).includes(column)
    ? sql.raw(`CASE WHEN '${column}' = ANY("products"."locked_fields") THEN "products"."${column}" ELSE excluded."${column}" END`)
    : excluded(column);

function isWeightUnit(unit: ReturnType<typeof mapPosUnit>): boolean {
  return unit === 'kg' || unit === 'g';
}

function toProductRow(item: PosItem, categoryId: number | null, syncedAt: Date): NewProduct {
  const unit = mapPosUnit(item.unit);
  const isLoose = item.isWeighable ?? (isWeightUnit(unit) && item.packSize === null);
  return {
    gofrugalItemId: item.externalId,
    itemCode: item.itemCode,
    barcode: item.barcode,
    name: item.name,
    slug: slugWithId(item.name, item.externalId),
    brand: item.brand,
    categoryId,
    mrp: item.mrp,
    sellingPrice: item.sellingPrice,
    hsnCode: item.hsnCode,
    gstRate: item.gstRate,
    stockQuantity: item.stock,
    unit,
    packSize: item.packSize,
    isLoose,
    // Insert-only defaults; staff can tune these later without the sync overwriting them.
    minOrderQty: isLoose ? '0.250' : '1',
    qtyStep: isLoose ? '0.250' : '1',
    isActive: item.isActive,
    gofrugalUpdatedAt: item.updatedAt,
    syncedAt,
  };
}

async function syncCategories(client: PosCatalogClient) {
  const raw = await withRetry(() => client.fetchCategories(), { label: 'pos.fetchCategories' });
  const valid: PosCategory[] = [];
  let rejected = 0;
  for (const record of raw) {
    const parsed = posCategorySchema.safeParse(record);
    if (parsed.success) valid.push(parsed.data);
    else {
      rejected++;
      logger.warn({ record, issues: parsed.error.issues }, 'rejected POS category');
    }
  }

  if (valid.length > 0) {
    await db
      .insert(categories)
      .values(
        valid.map((category) => ({
          gofrugalCatId: category.externalId,
          name: category.name,
          slug: slugWithId(category.name, category.externalId),
          sortOrder: category.sortOrder,
        })),
      )
      .onConflictDoUpdate({
        target: categories.gofrugalCatId,
        set: { name: sql`excluded."name"`, sortOrder: sql`excluded."sort_order"`, isActive: true },
        setWhere: sql`("categories"."name", "categories"."sort_order", "categories"."is_active")
                      IS DISTINCT FROM (excluded."name", excluded."sort_order", true)`,
      });

    // Second pass: parents (they may arrive after their children) — one statement for all rows.
    const idByExternal = await loadCategoryIdMap();
    const links = valid.flatMap((category) => {
      const id = idByExternal.get(category.externalId);
      const parentId = category.parentExternalId ? (idByExternal.get(category.parentExternalId) ?? null) : null;
      return id === undefined || parentId === id ? [] : [sql`(${id}::int, ${parentId}::int)`];
    });
    if (links.length > 0) {
      await db.execute(sql`
        UPDATE ${categories} AS c SET parent_id = v.parent_id
        FROM (VALUES ${sql.join(links, sql`, `)}) AS v(id, parent_id)
        WHERE c.id = v.id AND c.parent_id IS DISTINCT FROM v.parent_id`);
    }

    // Categories removed in the POS disappear from the app (rows kept for history).
    await db
      .update(categories)
      .set({ isActive: false })
      .where(
        and(
          isNotNull(categories.gofrugalCatId),
          eq(categories.isActive, true),
          notInArray(
            categories.gofrugalCatId,
            valid.map((category) => category.externalId),
          ),
        ),
      );
  }

  return { upserted: valid.length, rejected };
}

async function loadCategoryIdMap(): Promise<Map<string, number>> {
  const rows = await db
    .select({ id: categories.id, externalId: categories.gofrugalCatId })
    .from(categories)
    .where(isNotNull(categories.gofrugalCatId));
  return new Map(rows.map((row) => [row.externalId as string, row.id]));
}

async function upsertProducts(rows: NewProduct[], mode: SyncMode): Promise<number> {
  if (rows.length === 0) return 0;
  const set = Object.fromEntries(POS_OWNED.map((column) => [column, posValue(column)]));
  const changed = await db
    .insert(products)
    .values(rows)
    .onConflictDoUpdate({
      target: products.gofrugalItemId,
      set: {
        itemCode: set.item_code,
        barcode: set.barcode,
        name: set.name,
        brand: set.brand,
        categoryId: set.category_id,
        mrp: set.mrp,
        sellingPrice: set.selling_price,
        hsnCode: set.hsn_code,
        gstRate: set.gst_rate,
        stockQuantity: set.stock_quantity,
        unit: set.unit,
        packSize: set.pack_size,
        isLoose: set.is_loose,
        isActive: set.is_active,
        gofrugalUpdatedAt: set.gofrugal_updated_at,
        syncedAt: excluded('synced_at'),
        updatedAt: sql`now()`,
      },
      // Delta: skip no-op writes (no WAL churn, updated_at stays meaningful).
      // Full: touch every row so synced_at proves the POS still has it.
      ...(mode === 'delta'
        ? {
            setWhere: sql`(${sql.join(
              POS_OWNED.map((column) => current(column)),
              sql`, `,
            )}) IS DISTINCT FROM (${sql.join(
              POS_OWNED.map((column) => posValue(column)),
              sql`, `,
            )})`,
          }
        : {}),
    })
    .returning({ id: products.id });
  return changed.length;
}

async function deactivateMissing(runStartedAt: Date, seenCount: number): Promise<number> {
  const [active] = await db
    .select({ count: sql<number>`count(*)::int` })
    .from(products)
    .where(eq(products.isActive, true));
  const activeCount = Number(active?.count ?? 0);
  if (activeCount > 0 && seenCount < activeCount * MIN_FULL_SYNC_COVERAGE) {
    logger.error(
      { seenCount, activeCount },
      'full sync saw too few items — skipping deactivation to protect the catalogue (POS returned partial data?)',
    );
    return 0;
  }
  const rows = await db
    .update(products)
    .set({ isActive: false, updatedAt: sql`now()` })
    .where(and(eq(products.isActive, true), lt(products.syncedAt, runStartedAt)))
    .returning({ id: products.id });
  return rows.length;
}

async function runSync(mode: SyncMode, client: PosCatalogClient): Promise<SyncResult> {
  const lease = await syncStateRepository.acquireLease(db, SYNC_KEYS.ITEMS);
  if (!lease) {
    logger.info({ mode }, 'catalog sync skipped — another run holds the lease');
    return { status: 'skipped', reason: 'already_running' };
  }

  const startedAt = new Date();
  const effectiveMode: SyncMode = mode === 'delta' && !lease.watermark ? 'full' : mode;
  const modifiedSince =
    effectiveMode === 'delta' && lease.watermark ? new Date(lease.watermark.getTime() - WATERMARK_OVERLAP_MS) : null;

  logger.info({ mode: effectiveMode, modifiedSince, client: client.name }, 'catalog sync started');

  try {
    const categoryStats = await syncCategories(client);
    const categoryIds = await loadCategoryIdMap();

    let page = 1;
    let fetched = 0;
    let changed = 0;
    let rejected = 0;
    let maxSeen = lease.watermark ? lease.watermark.getTime() : 0;

    for (;;) {
      const currentPage = page;
      const result = await withRetry(
        () => client.fetchItemsPage({ modifiedSince, page: currentPage, pageSize: env.CATALOG_SYNC_PAGE_SIZE }),
        { label: `pos.fetchItemsPage#${currentPage}` },
      );
      fetched += result.items.length;

      const rows: NewProduct[] = [];
      for (const record of result.items) {
        const parsed = posItemSchema.safeParse(record);
        if (!parsed.success) {
          rejected++;
          // Rejected rows still advance the watermark, else one bad item would be re-fetched forever.
          const updatedAt = (record as { updatedAt?: unknown }).updatedAt;
          const ts = updatedAt ? new Date(String(updatedAt)).getTime() : Number.NaN;
          if (Number.isFinite(ts)) maxSeen = Math.max(maxSeen, ts);
          if (rejected <= MAX_LOGGED_REJECTS) {
            logger.warn(
              {
                externalId: (record as { externalId?: unknown }).externalId,
                issues: parsed.error.issues.map((issue) => `${issue.path.join('.') || 'item'}: ${issue.message}`),
              },
              'rejected POS item',
            );
          }
          continue;
        }
        const item = parsed.data;
        maxSeen = Math.max(maxSeen, item.updatedAt.getTime());
        const categoryId = item.categoryExternalId ? (categoryIds.get(item.categoryExternalId) ?? null) : null;
        rows.push(toProductRow(item, categoryId, startedAt));
      }

      changed += await upsertProducts(dedupeByExternalId(rows), effectiveMode);
      if (!result.hasMore || result.items.length === 0) break;
      page++;
    }

    const deactivated = effectiveMode === 'full' ? await deactivateMissing(startedAt, fetched - rejected) : 0;
    const watermark = maxSeen > 0 ? new Date(maxSeen) : null;

    await syncStateRepository.markSuccess(db, SYNC_KEYS.ITEMS, { watermark, itemsProcessed: fetched });
    if (effectiveMode === 'full') {
      await syncStateRepository.acquireLease(db, SYNC_KEYS.ITEMS_FULL);
      await syncStateRepository.markSuccess(db, SYNC_KEYS.ITEMS_FULL, { watermark, itemsProcessed: fetched });
    }
    catalogCache.invalidate();

    const summary: SyncResult = {
      status: 'success',
      mode: effectiveMode,
      categories: categoryStats,
      items: { fetched, changed, rejected, deactivated },
      pages: page,
      watermark: watermark?.toISOString() ?? null,
      durationMs: Date.now() - startedAt.getTime(),
    };
    logger.info(summary, 'catalog sync finished');
    return summary;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    await syncStateRepository.markFailure(db, SYNC_KEYS.ITEMS, message).catch(() => undefined);
    logger.error({ err: error, mode: effectiveMode }, 'catalog sync failed');
    throw error;
  }
}

/** A POS page can repeat an item (e.g. modified mid-paging); Postgres rejects duplicate conflict targets in one INSERT. */
function dedupeByExternalId(rows: NewProduct[]): NewProduct[] {
  const latest = new Map<string, NewProduct>();
  for (const row of rows) latest.set(row.gofrugalItemId, row);
  return [...latest.values()];
}

export const catalogSyncService = {
  run: (mode: SyncMode = 'delta', client: PosCatalogClient = posClient) => runSync(mode, client),

  async status() {
    return syncStateRepository.list(db);
  },
};
