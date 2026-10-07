import { createHash } from 'node:crypto';
import { and, asc, eq, ilike, isNotNull, isNull, or, sql, type SQL } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { categories, productBarcodes, products } from '../../db/schema';
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

/** Product fields the admin app shows (also used by the photo work queue). */
export const adminProductColumns = columns;

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

/**
 * Light, colourless background connected to the photo's edges becomes pure white. The fill follows
 * gradual changes (light-box falloff, soft shadows) and stops at sharp edges, so the product — even
 * white parts of its label — stays as it is.
 */
export function whitenBackground(data: Buffer, width: number, height: number, channels: number) {
  const seen = new Uint8Array(width * height);
  const queue = new Int32Array(width * height);
  let head = 0;
  let tail = 0;
  const isBackground = (p: number) => {
    const i = p * channels;
    const r = data[i]!, g = data[i + 1]!, b = data[i + 2]!;
    const lo = Math.min(r, g, b), hi = Math.max(r, g, b);
    return lo >= 165 && hi - lo <= 30;
  };
  const push = (p: number) => {
    if (!seen[p] && isBackground(p)) {
      seen[p] = 1;
      queue[tail++] = p;
    }
  };
  for (let x = 0; x < width; x++) {
    push(x);
    push((height - 1) * width + x);
  }
  for (let y = 0; y < height; y++) {
    push(y * width);
    push(y * width + width - 1);
  }
  const close = (a: number, b: number) => {
    const i = a * channels, j = b * channels;
    return Math.abs(data[i]! - data[j]!) + Math.abs(data[i + 1]! - data[j + 1]!) + Math.abs(data[i + 2]! - data[j + 2]!) <= 24;
  };
  while (head < tail) {
    const p = queue[head++]!;
    const x = p % width;
    const next = [x > 0 ? p - 1 : -1, x < width - 1 ? p + 1 : -1, p - width, p + width];
    for (const q of next) {
      if (q < 0 || q >= width * height || seen[q]) continue;
      if (close(p, q) && isBackground(q)) {
        seen[q] = 1;
        queue[tail++] = q;
      }
    }
  }
  for (let p = 0; p < width * height; p++) {
    if (seen[p]) {
      const i = p * channels;
      data[i] = data[i + 1] = data[i + 2] = 255;
    }
  }
}

/**
 * Product photo → shop-ready catalogue image: EXIF-rotated, transparent or near-white background made
 * pure white, empty borders trimmed, product centred on an 800 × 800 white square, WebP.
 * Phone photos taken in a light box (or cut out on the phone) come out like brand pack shots.
 */
export async function catalogPhoto(input: Buffer): Promise<Buffer> {
  const sharp = await loadSharp();
  const base = await sharp(input, { limitInputPixels: MAX_INPUT_PIXELS, failOn: 'error' })
    .rotate() // honour the phone camera's EXIF orientation
    .resize(1600, 1600, { fit: 'inside', withoutEnlargement: true })
    .flatten({ background: '#ffffff' })
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const { data, info } = base;
  whitenBackground(data, info.width, info.height, info.channels);
  const whitened = sharp(data, { raw: { width: info.width, height: info.height, channels: info.channels } });
  let trimmed: Buffer;
  try {
    trimmed = await whitened.trim({ background: '#ffffff', threshold: 12 }).png().toBuffer();
  } catch {
    trimmed = await sharp(data, { raw: { width: info.width, height: info.height, channels: info.channels } }).png().toBuffer();
  }
  // Product fills ~88% of the square, centred, with white around it.
  const inner = Math.round(MAX_SIDE * 0.88);
  const fitted = await sharp(trimmed).resize(inner, inner, { fit: 'inside', withoutEnlargement: false }).toBuffer({ resolveWithObject: true });
  return sharp({ create: { width: MAX_SIDE, height: MAX_SIDE, channels: 3, background: '#ffffff' } })
    .composite([{ input: fitted.data, left: Math.round((MAX_SIDE - fitted.info.width) / 2), top: Math.round((MAX_SIDE - fitted.info.height) / 2) }])
    .webp({ quality: 82, effort: 4 })
    .toBuffer();
}

export const adminProductsService = {
  /** Photo mode: the product behind a scanned barcode — POS label (any batch) or the maker's EAN. */
  async findByBarcode(code: string) {
    const [row] = await db
      .select(columns)
      .from(products)
      .leftJoin(categories, eq(categories.id, products.categoryId))
      .where(or(eq(products.barcode, code), eq(products.itemCode, code), sql`${products.id} IN (SELECT ${productBarcodes.productId} FROM ${productBarcodes} WHERE ${productBarcodes.barcode} = ${code})`))
      .orderBy(sql`${products.isActive} DESC`)
      .limit(1);
    return row ?? null;
  },

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

  /** [by] = the staff member uploading (photo work tracking). */
  async setImage(productId: number, input: Buffer, by?: string) {
    if (!r2.isConfigured()) throw new AppError('UPSTREAM_UNAVAILABLE', 'Image storage is not configured');
    const [product] = await db.select({ id: products.id, itemCode: products.itemCode, imageUrl: products.imageUrl }).from(products).where(eq(products.id, productId)).limit(1);
    if (!product) throw AppError.notFound('Product');

    let output: Buffer;
    try {
      output = await catalogPhoto(input);
    } catch (error) {
      logger.warn({ err: error, productId }, 'product photo could not be processed');
      throw new AppError('BAD_REQUEST', 'This file is not a supported photo (use JPG, PNG or WebP)', { reason: 'image_invalid' });
    }

    const hash = createHash('sha1').update(output).digest('hex').slice(0, 16);
    const safeCode = product.itemCode.toLowerCase().replace(/[^a-z0-9_-]+/g, '-').replace(/^-+|-+$/g, '') || String(product.id);
    const key = `products/${safeCode}/${hash}.webp`;
    const stored = await r2.put(key, output, { contentType: 'image/webp', metadata: { product: String(product.id) } });
    await db.update(products).set({ imageUrl: stored.url, photoById: by ?? null, photoAt: sql`now()` }).where(eq(products.id, productId));
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
    await db.update(products).set({ imageUrl: null, photoById: null, photoAt: null }).where(eq(products.id, productId));
    catalogCache.invalidate();
    const key = product.imageUrl ? r2.keyFromUrl(product.imageUrl) : null;
    if (key) await r2.remove(key).catch((error: unknown) => logger.warn({ err: error, key }, 'product photo not deleted'));
  },
};
