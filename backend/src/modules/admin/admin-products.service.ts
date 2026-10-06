import { createHash } from 'node:crypto';
import { and, asc, eq, ilike, isNotNull, isNull, or, sql, type SQL } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { categories, products } from '../../db/schema';
import { r2 } from '../../infra/r2';
import { catalogCache } from '../catalog/catalog.cache';
import { available } from '../catalog/catalog.repository';

/** Product photos: 800 px on the long side, WebP — ~30–60 KB each, so 30k fit well inside R2's free 10 GB. */
const MAX_SIDE = 800;
const MAX_INPUT_PIXELS = 40_000_000;

export type AdminProductFilter = 'all' | 'no_image' | 'with_image' | 'inactive';

const columns = {
  id: products.id,
  name: products.name,
  nameTa: products.nameTa,
  itemCode: products.itemCode,
  barcode: products.barcode,
  brand: products.brand,
  category: categories.name,
  packSize: products.packSize,
  mrp: products.mrp,
  sellingPrice: products.sellingPrice,
  available,
  imageUrl: products.imageUrl,
  description: products.description,
  sortRank: products.sortRank,
  safetyStock: products.safetyStock,
  isActive: products.isActive,
};

function cursorOf(row: { name: string; id: number }) {
  return Buffer.from(JSON.stringify([row.name, row.id])).toString('base64url');
}

function parseCursor(raw: string): { name: string; id: number } {
  try {
    const [name, id] = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as [unknown, unknown];
    if (typeof name === 'string' && typeof id === 'number' && Number.isSafeInteger(id)) return { name, id };
  } catch {
    // fall through
  }
  throw new AppError('BAD_REQUEST', 'Invalid pagination cursor', { reason: 'cursor_invalid' });
}

/** sharp is loaded on first use, so its native library doesn't sit in the 512 MB server's memory otherwise. */
type Sharp = typeof import('sharp');
let sharpModule: Promise<Sharp> | null = null;
export function loadSharp(): Promise<Sharp> {
  sharpModule ??= import('sharp').then((module) => {
    // CommonJS interop: the function is either the module itself or its default export.
    const sharp = ((module as unknown as { default?: Sharp }).default ?? module) as Sharp;
    sharp.cache(false);
    sharp.concurrency(1);
    return sharp;
  });
  return sharpModule;
}

export const adminProductsService = {
  async list(params: { q?: string | undefined; filter: AdminProductFilter; cursor?: string | undefined; limit: number }) {
    const where: SQL[] = [];
    if (params.filter === 'inactive') where.push(eq(products.isActive, false));
    else where.push(eq(products.isActive, true));
    if (params.filter === 'no_image') where.push(isNull(products.imageUrl));
    if (params.filter === 'with_image') where.push(isNotNull(products.imageUrl));
    const q = params.q?.trim();
    if (q) {
      const pattern = `%${q.replace(/[%_\\]/g, '\\$&')}%`;
      where.push(or(ilike(products.name, pattern), eq(products.itemCode, q), eq(products.barcode, q), ilike(products.brand, pattern))!);
    }
    if (params.cursor) {
      const cursor = parseCursor(params.cursor);
      where.push(sql`(${products.name}, ${products.id}) > (${cursor.name}, ${cursor.id})`);
    }
    const rows = await db
      .select(columns)
      .from(products)
      .leftJoin(categories, eq(categories.id, products.categoryId))
      .where(and(...where))
      .orderBy(asc(products.name), asc(products.id))
      .limit(params.limit + 1);
    const page = rows.slice(0, params.limit);
    const last = page.at(-1);
    const [counts] = await db
      .select({
        active: sql<number>`count(*) filter (where ${products.isActive})::int`,
        withImage: sql<number>`count(*) filter (where ${products.isActive} and ${products.imageUrl} is not null)::int`,
      })
      .from(products);
    return {
      products: page,
      nextCursor: rows.length > params.limit && last ? cursorOf(last) : null,
      counts: { active: Number(counts?.active ?? 0), withImage: Number(counts?.withImage ?? 0) },
    };
  },

  /** Fields the store owns (the POS sync never overwrites them). */
  async update(productId: number, patch: { nameTa?: string | null | undefined; description?: string | null | undefined; sortRank?: number | undefined; safetyStock?: string | undefined }) {
    const [row] = await db
      .update(products)
      .set({
        ...(patch.nameTa !== undefined ? { nameTa: patch.nameTa } : {}),
        ...(patch.description !== undefined ? { description: patch.description } : {}),
        ...(patch.sortRank !== undefined ? { sortRank: patch.sortRank } : {}),
        ...(patch.safetyStock !== undefined ? { safetyStock: patch.safetyStock } : {}),
      })
      .where(eq(products.id, productId))
      .returning({ id: products.id });
    if (!row) throw AppError.notFound('Product');
    catalogCache.invalidate();
    return row;
  },

  async setImage(productId: number, input: Buffer) {
    if (!r2.isConfigured()) throw new AppError('UPSTREAM_UNAVAILABLE', 'Image storage is not configured');
    const [product] = await db.select({ id: products.id, itemCode: products.itemCode, imageUrl: products.imageUrl }).from(products).where(eq(products.id, productId)).limit(1);
    if (!product) throw AppError.notFound('Product');

    const sharp = await loadSharp();
    let output: Buffer;
    try {
      output = await sharp(input, { limitInputPixels: MAX_INPUT_PIXELS, failOn: 'error' })
        .rotate() // honour the phone camera's EXIF orientation
        .resize(MAX_SIDE, MAX_SIDE, { fit: 'inside', withoutEnlargement: true })
        .flatten({ background: '#ffffff' })
        .webp({ quality: 80, effort: 4 })
        .toBuffer();
    } catch (error) {
      logger.warn({ err: error, productId }, 'product photo could not be processed');
      throw new AppError('BAD_REQUEST', 'This file is not a supported photo (use JPG, PNG or WebP)', { reason: 'image_invalid' });
    }

    const hash = createHash('sha1').update(output).digest('hex').slice(0, 16);
    const safeCode = product.itemCode.toLowerCase().replace(/[^a-z0-9_-]+/g, '-').replace(/^-+|-+$/g, '') || String(product.id);
    const key = `products/${safeCode}/${hash}.webp`;
    const stored = await r2.put(key, output, { contentType: 'image/webp', metadata: { product: String(product.id) } });
    await db.update(products).set({ imageUrl: stored.url }).where(eq(products.id, productId));
    catalogCache.invalidate();

    // The old photo is no longer referenced; free its storage (DeleteObject is free on R2).
    const oldKey = product.imageUrl ? r2.keyFromUrl(product.imageUrl) : null;
    if (oldKey && oldKey !== key) await r2.remove(oldKey).catch((error: unknown) => logger.warn({ err: error, oldKey }, 'old product photo not deleted'));

    logger.info({ productId, bytesIn: input.length, bytesOut: output.length }, 'product photo updated');
    return { imageUrl: stored.url, bytes: output.length };
  },

  async removeImage(productId: number) {
    const [product] = await db.select({ imageUrl: products.imageUrl }).from(products).where(eq(products.id, productId)).limit(1);
    if (!product) throw AppError.notFound('Product');
    await db.update(products).set({ imageUrl: null }).where(eq(products.id, productId));
    catalogCache.invalidate();
    const key = product.imageUrl ? r2.keyFromUrl(product.imageUrl) : null;
    if (key) await r2.remove(key).catch((error: unknown) => logger.warn({ err: error, key }, 'product photo not deleted'));
  },
};
