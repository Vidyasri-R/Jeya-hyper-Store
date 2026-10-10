import { eq, inArray, sql } from 'drizzle-orm';
import { AppError } from '../../common/errors';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { categories, productLinks, products } from '../../db/schema';
import { appConfigService } from '../app-config/app-config.service';
import { catalogCache } from '../catalog/catalog.cache';
import { withPlaceholders } from '../catalog/catalog.service';
import { HOME_LISTS_KEY, homeListsSchema } from '../catalog/home-lists';
import { regroupVariants } from '../catalog/variants';
import { sameProductPairs, type CodeCandidate } from '../catalog-import/new-codes';
import { adminProductColumns } from './admin-products.service';

/** Codes that were merged: the old one leaves the shop once its stock is gone (and stays hidden). */
async function retireSoldOut(): Promise<number> {
  const rows = await db.execute(sql`
    UPDATE ${products} AS p
       SET is_active = false,
           locked_fields = (SELECT array_agg(DISTINCT f ORDER BY f) FROM unnest(p.locked_fields || ARRAY['is_active']) AS f),
           updated_at = now()
      FROM ${productLinks} AS l
     WHERE l.old_product_id = p.id AND l.decision = 'same' AND p.is_active
       AND (p.stock_quantity - p.reserved_quantity) <= 0
    RETURNING p.id`);
  const count = (rows as unknown as { rows?: unknown[] }).rows?.length ?? (rows as unknown as unknown[]).length ?? 0;
  if (count > 0) await regroupVariants();
  return count;
}

async function loadPairs() {
  const [rows, decided] = await Promise.all([
    db
      .select({
        id: products.id,
        itemCode: products.itemCode,
        name: products.name,
        brand: products.brand,
        packSize: products.packSize,
        mrp: products.mrp,
        isActive: products.isActive,
        hasPhoto: sql<boolean>`${products.imageUrl} is not null`,
        lastPurchaseAt: products.gofrugalUpdatedAt,
      })
      .from(products),
    db.select({ old: productLinks.oldProductId, new: productLinks.newProductId }).from(productLinks),
  ]);
  return sameProductPairs(rows as CodeCandidate[], new Set(decided.map((d) => `${d.old}:${d.new}`)));
}

export const newCodesService = {
  retireSoldOut,

  /** How many pairs are waiting for an answer (shown after a stock upload). */
  async count(): Promise<number> {
    return (await loadPairs()).length;
  },

  /** Pairs waiting for an answer, most useful first, with what the admin needs to decide. */
  async list(limit: number) {
    const pairs = await loadPairs();
    const page = pairs.slice(0, limit);
    const ids = [...new Set(page.flatMap((p) => [p.old.id, p.new.id]))];
    const details =
      ids.length === 0
        ? []
        : await withPlaceholders(
            (
              await db
                .select({ ...adminProductColumns, lastPurchaseAt: products.gofrugalUpdatedAt })
                .from(products)
                .leftJoin(categories, eq(categories.id, products.categoryId))
                .where(inArray(products.id, ids))
            ).map((r) => ({ ...r, placeholderImageUrl: null as string | null })),
          );
    const byId = new Map(details.map((d) => [d.id, d]));
    return {
      total: pairs.length,
      pairs: page.flatMap((p) => {
        const old = byId.get(p.old.id);
        const neu = byId.get(p.new.id);
        return old && neu ? [{ old, new: neu }] : [];
      }),
    };
  },

  /**
   * The admin's answer. Same: the new code gets what the old one had and it lacks (photo — marked
   * "check it matches the new pack" —, choices, Tamil name, description, priority, a hand-picked
   * category, home-list spots); the old code leaves the shop when its stock runs out.
   */
  async decide(input: { oldId: number; newId: number; same: boolean; staffId: string }) {
    if (input.oldId === input.newId) throw new AppError('BAD_REQUEST', 'Pick two different products');
    const both = await db.select().from(products).where(inArray(products.id, [input.oldId, input.newId]));
    const old = both.find((p) => p.id === input.oldId);
    const neu = both.find((p) => p.id === input.newId);
    if (!old || !neu) throw AppError.notFound('Product');

    let copiedPhoto = false;
    await db.transaction(async (tx) => {
      await tx
        .insert(productLinks)
        .values({ oldProductId: old.id, newProductId: neu.id, decision: input.same ? 'same' : 'different', decidedBy: input.staffId })
        .onConflictDoUpdate({
          target: [productLinks.oldProductId, productLinks.newProductId],
          set: { decision: input.same ? 'same' : 'different', decidedBy: input.staffId, decidedAt: sql`now()` },
        });
      if (!input.same) return;
      copiedPhoto = !neu.imageUrl && !!old.imageUrl;
      const categoryByHand = old.lockedFields.includes('category_id') && !neu.lockedFields.includes('category_id');
      await tx
        .update(products)
        .set({
          ...(copiedPhoto
            ? { imageUrl: old.imageUrl, photoById: old.photoById, photoAt: sql`now()`, photoCheckReason: 'new_code', photoCheckSince: sql`now()`, photoAssigneeId: null }
            : {}),
          ...(!neu.options && old.options ? { options: old.options } : {}),
          ...(!neu.nameTa && old.nameTa ? { nameTa: old.nameTa } : {}),
          ...(!neu.description && old.description ? { description: old.description } : {}),
          ...(old.sortRank > neu.sortRank ? { sortRank: old.sortRank } : {}),
          ...(categoryByHand ? { categoryId: old.categoryId, lockedFields: [...new Set([...neu.lockedFields, 'category_id'])].sort() } : {}),
          updatedAt: sql`now()`,
        })
        .where(eq(products.id, neu.id));
    });

    if (input.same) {
      // Hand-picked home lists: the new code takes the old one's place.
      const lists = homeListsSchema.safeParse(await appConfigService.getRaw(HOME_LISTS_KEY));
      if (lists.success) {
        const swap = (ids: number[]) => (ids.includes(old.id) && !ids.includes(neu.id) ? ids.map((id) => (id === old.id ? neu.id : id)) : ids);
        const next = { ...lists.data, offers: swap(lists.data.offers), popular: swap(lists.data.popular) };
        if (JSON.stringify(next) !== JSON.stringify(lists.data)) {
          await appConfigService.set(HOME_LISTS_KEY, homeListsSchema.parse(next), {
            isPublic: false,
            description: 'Product ids for the customer home "Today\'s offers" and "Popular in your store" (empty = automatic).',
          });
        }
      }
      await retireSoldOut();
      await regroupVariants();
    }
    catalogCache.invalidate();
    logger.info({ old: old.itemCode, new: neu.itemCode, same: input.same, copiedPhoto }, 'new code decision');
    return { copiedPhoto, oldStillOnSale: input.same ? Number(old.stockQuantity) - Number(old.reservedQuantity) > 0 && old.isActive : null };
  },
};
