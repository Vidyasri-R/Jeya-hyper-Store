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
import { adminProductColumns, loadSharp } from './admin-products.service';

/** Category pictures are real photos (not pack shots): square, cover-cropped, 480 px WebP. */
const SIDE = 480;

export async function categoryPhoto(input: Buffer): Promise<Buffer> {
  const sharp = await loadSharp();
  return sharp(input, { limitInputPixels: 40_000_000, failOn: 'error' })
    .rotate()
    .resize(SIDE, SIDE, { fit: 'cover', position: 'attention' })
    .flatten({ background: '#ffffff' })
    .webp({ quality: 80, effort: 4 })
    .toBuffer();
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

  async setImage(categoryId: number, input: Buffer) {
    if (!r2.isConfigured()) throw new AppError('UPSTREAM_UNAVAILABLE', 'Image storage is not configured');
    const [category] = await db.select({ id: categories.id, imageUrl: categories.imageUrl }).from(categories).where(eq(categories.id, categoryId)).limit(1);
    if (!category) throw AppError.notFound('Category');
    let output: Buffer;
    try {
      output = await categoryPhoto(input);
    } catch (error) {
      logger.warn({ err: error, categoryId }, 'category photo could not be processed');
      throw new AppError('BAD_REQUEST', 'This file is not a supported photo (use JPG, PNG or WebP)', { reason: 'image_invalid' });
    }
    const hash = createHash('sha1').update(output).digest('hex').slice(0, 16);
    const key = `categories/${category.id}/${hash}.webp`;
    const stored = await r2.put(key, output, { contentType: 'image/webp', metadata: { category: String(category.id) } });
    await db.update(categories).set({ imageUrl: stored.url }).where(eq(categories.id, categoryId));
    catalogCache.invalidate();
    const oldKey = category.imageUrl ? r2.keyFromUrl(category.imageUrl) : null;
    if (oldKey && oldKey !== key) await r2.remove(oldKey).catch((error: unknown) => logger.warn({ err: error, oldKey }, 'old category photo not deleted'));
    return { imageUrl: stored.url };
  },

  async removeImage(categoryId: number) {
    const [category] = await db.select({ imageUrl: categories.imageUrl }).from(categories).where(eq(categories.id, categoryId)).limit(1);
    if (!category) throw AppError.notFound('Category');
    await db.update(categories).set({ imageUrl: null }).where(eq(categories.id, categoryId));
    catalogCache.invalidate();
    const key = category.imageUrl ? r2.keyFromUrl(category.imageUrl) : null;
    if (key) await r2.remove(key).catch((error: unknown) => logger.warn({ err: error, key }, 'category photo not deleted'));
  },

  /** Home lists with each chosen product's details (sold-out / inactive ones included, so the admin sees them). */
  async homeLists() {
    const stored = homeListsSchema.safeParse(await appConfigService.getRaw(HOME_LISTS_KEY));
    const lists = stored.success ? stored.data : DEFAULT_HOME_LISTS;
    const ids = [...new Set([...lists.offers, ...lists.popular])];
    const rows = ids.length
      ? await db
          .select(adminProductColumns)
          .from(products)
          .leftJoin(categories, eq(categories.id, products.categoryId))
          .where(and(inArray(products.id, ids)))
      : [];
    const withPhotos = await withPlaceholders(rows.map((r) => ({ ...r, placeholderImageUrl: null as string | null })));
    const byId = new Map(withPhotos.map((r) => [r.id, r]));
    // What the shop shows when a list is empty — so the admin sees it and can start from it.
    const [autoOffers, autoPopular] = await Promise.all([automaticOffers(), automaticPopular()]);
    const autoIds = [...new Set([...autoOffers, ...autoPopular].map((r) => r.id))];
    const autoRows = autoIds.length
      ? await withPlaceholders(
          (await db.select(adminProductColumns).from(products).leftJoin(categories, eq(categories.id, products.categoryId)).where(inArray(products.id, autoIds))).map((r) => ({
            ...r,
            placeholderImageUrl: null as string | null,
          })),
        )
      : [];
    const autoById = new Map(autoRows.map((r) => [r.id, r]));
    return {
      offers: lists.offers.flatMap((id) => byId.get(id) ?? []),
      popular: lists.popular.flatMap((id) => byId.get(id) ?? []),
      automatic: {
        offers: autoOffers.flatMap((r) => autoById.get(r.id) ?? []),
        popular: autoPopular.flatMap((r) => autoById.get(r.id) ?? []),
      },
    };
  },
};
