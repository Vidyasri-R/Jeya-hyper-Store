import { regroupVariants } from '../catalog/variants';
import { eq, inArray, sql } from 'drizzle-orm';
import { z } from 'zod';
import { AppError } from '../../common/errors';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { categories, productBarcodes, products } from '../../db/schema';
import type { PosCatalogClient } from '../../integrations/gofrugal/types';
import { appConfigService } from '../app-config/app-config.service';
import { catalogSyncService } from '../sync/catalog-sync.service';
import { classify, WEB_CATEGORIES, WEB_CATEGORY_KEYS } from './category-map';
import { photoPriority } from './photo-priority';
import { normDept, readStockFile, StockFileError, type StockItem } from './stock-csv';

export const CATALOG_IMPORT_KEY = 'catalog.import';

/** Admin-editable import settings (not public): which POS departments go online, and TYPE → category overrides. */
export const catalogImportSchema = z
  .object({
    departments: z.array(z.string().trim().max(60)).max(20),
    typeMap: z.record(z.string().trim().min(1).max(80), z.string().refine((k) => WEB_CATEGORY_KEYS.has(k), 'Unknown category')),
    /** Single items moved by the admin (Item Code → category), for groups that mix different things. */
    itemMap: z.record(z.string().trim().min(1).max(64), z.string().refine((k) => WEB_CATEGORY_KEYS.has(k), 'Unknown category')).optional(),
  })
  .strict();
export type CatalogImportSettings = z.infer<typeof catalogImportSchema>;
export const DEFAULT_CATALOG_IMPORT: CatalogImportSettings = { departments: ['SUPER MARKET', 'SUPERMARKET', ''], typeMap: {} };

/** Where an item goes: the admin's per-item move, else the TYPE rules / overrides. */
function categoryOf(i: StockItem, s: CatalogImportSettings) {
  const moved = s.itemMap?.[i.itemCode];
  return moved && WEB_CATEGORY_KEYS.has(moved) ? (moved as ReturnType<typeof classify>) : classify(i.type, i.posName, s.typeMap, i.brand);
}

async function settings(): Promise<CatalogImportSettings> {
  const raw = await appConfigService.getRaw(CATALOG_IMPORT_KEY);
  const parsed = catalogImportSchema.safeParse(raw);
  return parsed.success ? parsed.data : DEFAULT_CATALOG_IMPORT;
}

const catId = (key: string) => `WEB-${key}`;

function parse(text: string, s: CatalogImportSettings) {
  try {
    return readStockFile(text, new Set(s.departments.map(normDept)));
  } catch (error) {
    if (error instanceof StockFileError) throw new AppError('BAD_REQUEST', error.message, { reason: 'stock_file_invalid' });
    throw error;
  }
}

/** The stock file as a POS source for the existing sync engine (same validation, upserts, photo-keeping, deactivation). */
function fileClient(items: StockItem[], s: CatalogImportSettings): PosCatalogClient {
  const used = new Set<string>();
  const records = items.map((i) => {
    const key = categoryOf(i, s);
    used.add(key);
    return {
      externalId: i.itemCode,
      itemCode: i.itemCode,
      barcode: i.ean,
      name: i.name,
      brand: i.brand,
      categoryExternalId: catId(key),
      mrp: i.mrp,
      sellingPrice: i.sellingPrice,
      hsnCode: i.hsnCode,
      gstRate: i.gstRate,
      stock: i.stock,
      unit: i.isLoose ? 'KG' : 'NOS',
      packSize: i.packSize,
      isActive: i.isActive,
      isWeighable: i.isLoose,
      updatedAt: i.updatedAt.toISOString(),
    };
  });
  const PAGE = 1000;
  return {
    name: 'stock-file',
    async fetchCategories() {
      // Only categories that have products (and their parents), so the app shows no empty ones.
      const wanted = new Set<string>();
      for (const key of used) {
        wanted.add(key);
        const parent = WEB_CATEGORIES.find((c) => c.key === key)?.parent;
        if (parent) wanted.add(parent);
      }
      return WEB_CATEGORIES.filter((c) => wanted.has(c.key)).map((c, i) => ({
        externalId: catId(c.key),
        name: c.name,
        parentExternalId: c.parent ? catId(c.parent) : null,
        sortOrder: i,
      }));
    },
    async fetchItemsPage({ page }) {
      const slice = records.slice((page - 1) * PAGE, page * PAGE);
      return { items: slice, hasMore: page * PAGE < records.length };
    },
  };
}

type Existing = Map<string, { id: number; barcode: string | null; hasPhoto: boolean }>;

/** EAN / product barcode and photo of the file's products as they are now (before importing). */
async function currentBarcodes(items: StockItem[]): Promise<Existing> {
  const rows = await db
    .select({ id: products.id, code: products.gofrugalItemId, barcode: products.barcode, image: products.imageUrl })
    .from(products)
    .where(inArray(products.gofrugalItemId, items.map((i) => i.itemCode)));
  return new Map(rows.map((r) => [r.code, { id: r.id, barcode: r.barcode, hasPhoto: r.image !== null }]));
}

const gtin = (code: string) => code.replace(/\D/g, '').replace(/^0+/, '');

/** Products with a photo whose EAN changed under the same item code (repackaged), with the old EAN. */
export function packagingChanges(before: Existing, items: StockItem[]): { id: number; oldBarcode: string }[] {
  return items.flatMap((i) => {
    const was = before.get(i.itemCode);
    if (!was || !was.hasPhoto || !was.barcode || !i.ean || gtin(was.barcode) === gtin(i.ean)) return [];
    return [{ id: was.id, oldBarcode: was.barcode }];
  });
}

export const catalogImportService = {
  settings,

  /** What an upload would change — nothing is written. */
  async preview(text: string) {
    const s = await settings();
    const file = parse(text, s);
    const current = await db
      .select({ code: products.gofrugalItemId, sellingPrice: products.sellingPrice, mrp: products.mrp, isActive: products.isActive })
      .from(products);
    const byCode = new Map(current.map((p) => [p.code, p]));
    const inFile = new Set(file.items.map((i) => i.itemCode));
    let added = 0;
    let priceChanged = 0;
    let backInStock = 0;
    const byCategory: Record<string, number> = {};
    const otherTypes: Record<string, { itemCode: string; name: string; mrp: string; stock: string }[]> = {};
    const priceSamples: { name: string; from: string; to: string }[] = [];
    for (const i of file.items) {
      const key = categoryOf(i, s);
      if (i.isActive) byCategory[key] = (byCategory[key] ?? 0) + 1;
      if (key === 'other') {
        const t = i.type.trim().toUpperCase() || '(blank)';
        (otherTypes[t] ??= []).push({ itemCode: i.itemCode, name: i.name, mrp: i.mrp, stock: i.stock });
      }
      const was = byCode.get(i.itemCode);
      if (!was) added++;
      else {
        if (was.sellingPrice !== i.sellingPrice) {
          priceChanged++;
          if (priceSamples.length < 8) priceSamples.push({ name: i.name, from: was.sellingPrice, to: i.sellingPrice });
        }
        if (!was.isActive && i.isActive) backInStock++;
      }
    }
    const goingOut = current.filter((p) => p.isActive && !inFile.has(p.code)).length;
    return {
      rows: file.rows,
      products: file.items.length,
      online: file.items.filter((i) => i.isActive).length,
      departments: file.departments,
      selectedDepartments: s.departments,
      added,
      priceChanged,
      priceSamples,
      backInStock,
      goingOut,
      categories: WEB_CATEGORIES.filter((c) => byCategory[c.key]).map((c) => ({ key: c.key, name: c.name, parent: c.parent, products: byCategory[c.key] })),
      /** Groups that landed in "More Items", with their products (to see what they are before moving them). */
      otherTypes: Object.entries(otherTypes)
        .sort((a, b) => b[1].length - a[1].length)
        .map(([type, items]) => ({ type, count: items.length, items: items.sort((a, b) => a.name.localeCompare(b.name)) })),
      movedItems: Object.keys(s.itemMap ?? {}).length,
      problems: file.problems.slice(0, 50),
      problemCount: file.problems.length,
      looseItems: file.items.filter((i) => i.isLoose).length,
      /** Same item code, new EAN, and it has a photo: flagged for a new photo when imported. */
      newPackaging: packagingChanges(await currentBarcodes(file.items), file.items).length,
    };
  },

  /** Import the file: products, prices, stock and categories; missing products go out of stock. */
  async apply(text: string) {
    const s = await settings();
    const file = parse(text, s);
    if (file.items.length === 0) throw new AppError('BAD_REQUEST', 'No products in the selected departments', { reason: 'stock_file_empty' });
    const before = await currentBarcodes(file.items);
    const result = await catalogSyncService.run('full', fileClient(file.items, s));
    if (result.status !== 'success') throw new AppError('CONFLICT', 'Another catalogue update is running. Try again in a minute.', { reason: 'import_busy' });

    // Remember every label barcode for the photo mode's scanner.
    const ids = await db.select({ id: products.id, code: products.gofrugalItemId }).from(products).where(inArray(products.gofrugalItemId, file.items.map((i) => i.itemCode)));
    const idByCode = new Map(ids.map((r) => [r.code, r.id]));
    const pairs = file.items.flatMap((i) => (idByCode.has(i.itemCode) ? i.labelBarcodes.map((b) => ({ barcode: b, productId: idByCode.get(i.itemCode)! })) : []));
    for (let k = 0; k < pairs.length; k += 2000) {
      await db
        .insert(productBarcodes)
        .values(pairs.slice(k, k + 2000))
        .onConflictDoUpdate({ target: productBarcodes.barcode, set: { productId: sql`excluded."product_id"` } });
    }
    // Photo work order: fast movers and daily needs first.
    const prio = file.items.flatMap((i) => (idByCode.has(i.itemCode) ? [sql`(${idByCode.get(i.itemCode)!}::bigint, ${photoPriority(i, categoryOf(i, s))}::int)`] : []));
    for (let k = 0; k < prio.length; k += 1000) {
      await db.execute(sql`UPDATE ${products} AS p SET photo_priority = v.prio FROM (VALUES ${sql.join(prio.slice(k, k + 1000), sql`, `)}) AS v(id, prio) WHERE p.id = v.id AND p.photo_priority IS DISTINCT FROM v.prio`);
    }
    // Unit cost for the admin's margin report (kept off the product cards and the public API).
    const costs = file.items.flatMap((i) => (idByCode.has(i.itemCode) && i.costPrice ? [sql`(${idByCode.get(i.itemCode)!}::bigint, ${i.costPrice}::numeric)`] : []));
    for (let k = 0; k < costs.length; k += 1000) {
      await db.execute(sql`UPDATE ${products} AS p SET cost_price = v.cost FROM (VALUES ${sql.join(costs.slice(k, k + 1000), sql`, `)}) AS v(id, cost) WHERE p.id = v.id AND p.cost_price IS DISTINCT FROM v.cost`);
    }
    // Same item code, new EAN = new packaging: its photo may be out of date. Flag it for Photo work, and
    // keep the old EAN so packs still on the shelf scan.
    const repack = packagingChanges(before, file.items);
    if (repack.length > 0) {
      await db
        .update(products)
        .set({ photoCheckReason: 'new_barcode', photoCheckSince: sql`now()` })
        .where(inArray(products.id, repack.map((r) => r.id)));
      await db
        .insert(productBarcodes)
        .values(repack.map((r) => ({ barcode: r.oldBarcode, productId: r.id })))
        .onConflictDoNothing();
    }
    // Sizes of one product → one card with a size picker (new sizes, names and stock change daily).
    const sizes = await regroupVariants();
    logger.info({ items: result.items, barcodes: pairs.length, sizeGroups: sizes.groups, newPackaging: repack.length }, 'stock file imported');
    return { ...result, barcodes: pairs.length, sizeGroups: sizes.groups, newPackaging: repack.length };
  },

  /**
   * Admin → Upload stock file → "Move to": a whole POS group ([type]) or single items to a website
   * category. Remembered for every future import, and the products move in the shop right away.
   */
  async move(input: { category: string; itemCodes: string[]; type?: string | undefined }) {
    if (!WEB_CATEGORY_KEYS.has(input.category)) throw new AppError('BAD_REQUEST', 'Unknown category', { reason: 'category_unknown' });
    const s = await settings();
    const next: CatalogImportSettings = input.type
      ? { ...s, typeMap: { ...s.typeMap, [input.type.trim().toUpperCase()]: input.category } }
      : { ...s, itemMap: { ...(s.itemMap ?? {}), ...Object.fromEntries(input.itemCodes.map((c) => [c, input.category])) } };
    await appConfigService.set(CATALOG_IMPORT_KEY, catalogImportSchema.parse(next), { isPublic: false, description: 'Stock-file import: POS departments sold online and TYPE → website category overrides.' });
    // Move them now if the category already exists in the shop (else at the next import, which creates it).
    const [cat] = await db.select({ id: categories.id }).from(categories).where(eq(categories.gofrugalCatId, `WEB-${input.category}`)).limit(1);
    let moved = 0;
    if (cat && input.itemCodes.length > 0) {
      const rows = await db.update(products).set({ categoryId: cat.id }).where(inArray(products.gofrugalItemId, input.itemCodes)).returning({ id: products.id });
      moved = rows.length;
      await regroupVariants(); // sizes are grouped within a category
    }
    return { moved, appliesNow: Boolean(cat) };
  },

  async lastImport() {
    const states = await catalogSyncService.status();
    return states.find((st) => st.key === 'gofrugal_items_full') ?? null;
  },
};
