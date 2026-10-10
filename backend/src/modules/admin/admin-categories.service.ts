import { createHash } from 'node:crypto';
import { and, asc, eq, inArray, sql } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { categories, products } from '../../db/schema';
import { r2 } from '../../infra/r2';
import { appConfigService } from '../app-config/app-config.service';
import { catalogCache } from '../catalog/catalog.cache';
import { withPlaceholders } from '../catalog/catalog.service';
import { automaticOffers, automaticPopular, DEFAULT_HOME_LISTS, HOME_LISTS_KEY, homeListsSchema } from '../catalog/home-lists';
import { adminProductColumns, catalogPhoto, loadSharp, oneImageAtATime } from './admin-products.service';

/** Category pictures are real photos (not pack shots): square, cover-cropped, 480 px WebP. */
const SIDE = 480;

export function categoryPhoto(input: Buffer): Promise<Buffer> {
  return oneImageAtATime(async () => {
    const sharp = await loadSharp();
    return sharp(input, { limitInputPixels: 40_000_000, failOn: 'error' })
      .rotate()
      .resize(SIDE, SIDE, { fit: 'cover', position: 'attention' })
      .flatten({ background: '#ffffff' })
      .webp({ quality: 80, effort: 4 })
      .toBuffer();
  });
}

export const adminCategoriesService = {
  /** Shop categories (only the ones with products on sale), parents first. */
  async list() {
    const rows = await db
      .select({
        id: categories.id,
        name: categories.name,
        parentId: categories.parentId,
        imageUrl: categories.imageUrl,
        tileImageUrl: categories.tileImageUrl,
        products: sql<number>`(select count(*) from ${products} p where p.category_id = ${sql.raw('"categories"."id"')} and p.is_active)::int`,
      })
      .from(categories)
      .where(eq(categories.isActive, true))
      .orderBy(asc(categories.sortOrder), asc(categories.name));
    const childCount = new Map<number, number>();
    for (const r of rows) if (r.parentId) childCount.set(r.parentId, (childCount.get(r.parentId) ?? 0) + Number(r.products));
    return rows
      .map((r) => ({ ...r, products: Number(r.products) + (childCount.get(r.id) ?? 0) }))
      .filter((r) => r.products > 0);
  },

  /** [kind]: 'tile' = the category's picture on the shop's tiles; 'photo' = stand-in for its products. */
  /** [clean]: false keeps a tile picture as it is (no white-background clean-up). */
  async setImage(categoryId: number, input: Buffer, kind: 'photo' | 'tile' = 'photo', clean = true) {
    if (!r2.isConfigured()) throw new AppError('UPSTREAM_UNAVAILABLE', 'Image storage is not configured');
    const [found] = await db.select({ id: categories.id, imageUrl: categories.imageUrl, tileImageUrl: categories.tileImageUrl }).from(categories).where(eq(categories.id, categoryId)).limit(1);
    if (!found) throw AppError.notFound('Category');
    const category = { id: found.id, imageUrl: kind === 'tile' ? found.tileImageUrl : found.imageUrl };
    let output: Buffer;
    try {
      // Tile pictures are product-style (white background, centred); stand-ins are cover-cropped photos.
      output = kind === 'tile' ? await catalogPhoto(input, { clean }) : await categoryPhoto(input);
    } catch (error) {
      logger.warn({ err: error, categoryId }, 'category photo could not be processed');
      throw new AppError('BAD_REQUEST', 'This file is not a supported photo (use JPG, PNG or WebP)', { reason: 'image_invalid' });
    }
    const hash = createHash('sha1').update(output).digest('hex').slice(0, 16);
    const key = `categories/${category.id}/${kind === 'tile' ? 'tile-' : ''}${hash}.webp`;
    const stored = await r2.put(key, output, { contentType: 'image/webp', metadata: { category: String(category.id) } });
    await db.update(categories).set(kind === 'tile' ? { tileImageUrl: stored.url } : { imageUrl: stored.url }).where(eq(categories.id, categoryId));
    catalogCache.invalidate();
    const oldKey = category.imageUrl ? r2.keyFromUrl(category.imageUrl) : null;
    if (oldKey && oldKey !== key) await r2.remove(oldKey).catch((error: unknown) => logger.warn({ err: error, oldKey }, 'old category photo not deleted'));
    return { imageUrl: stored.url };
  },

  async removeImage(categoryId: number, kind: 'photo' | 'tile' = 'photo') {
    const [found] = await db.select({ imageUrl: categories.imageUrl, tileImageUrl: categories.tileImageUrl }).from(categories).where(eq(categories.id, categoryId)).limit(1);
    if (!found) throw AppError.notFound('Category');
    const url = kind === 'tile' ? found.tileImageUrl : found.imageUrl;
    await db.update(categories).set(kind === 'tile' ? { tileImageUrl: null } : { imageUrl: null }).where(eq(categories.id, categoryId));
    catalogCache.invalidate();
    const key = url ? r2.keyFromUrl(url) : null;
    if (key) await r2.remove(key).catch((error: unknown) => logger.warn({ err: error, key }, 'category photo not deleted'));
  },

  /**
   * Home lists for the admin: what customers see — pinned extras, then the automatic products (minus
   * hidden ones) — plus the hidden ones, so they can be shown again.
   */
  async homeLists() {
    const stored = homeListsSchema.safeParse(await appConfigService.getRaw(HOME_LISTS_KEY));
    const lists = stored.success ? stored.data : DEFAULT_HOME_LISTS;
    const hiddenOffers = lists.hiddenOffers ?? [];
    const hiddenPopular = lists.hiddenPopular ?? [];
    const [autoOffers, autoPopular] = await Promise.all([automaticOffers([...hiddenOffers, ...lists.offers]), automaticPopular([...hiddenPopular, ...lists.popular])]);
    const all = [...new Set([...lists.offers, ...lists.popular, ...hiddenOffers, ...hiddenPopular, ...autoOffers.map((r) => r.id), ...autoPopular.map((r) => r.id)])];
    const rows = all.length
      ? await withPlaceholders(
          (await db.select(adminProductColumns).from(products).leftJoin(categories, eq(categories.id, products.categoryId)).where(inArray(products.id, all))).map((r) => ({
            ...r,
            placeholderImageUrl: null as string | null,
          })),
        )
      : [];
    const byId = new Map(rows.map((r) => [r.id, r]));
    const pick = (list: number[]) => list.flatMap((id) => byId.get(id) ?? []);
    return {
      offers: { pinned: pick(lists.offers), automatic: pick(autoOffers.map((r) => r.id)), hidden: pick(hiddenOffers) },
      popular: { pinned: pick(lists.popular), automatic: pick(autoPopular.map((r) => r.id)), hidden: pick(hiddenPopular) },
    };
  },

};
