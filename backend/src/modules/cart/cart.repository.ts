import { and, asc, eq, inArray, sql } from 'drizzle-orm';
import type { DbExecutor } from '../../db/client';
import { cartItems, products } from '../../db/schema';
import { productCardColumns, type ProductCardRow } from '../catalog/catalog.repository';

/** Card fields + what checkout needs to snapshot the line onto the order. */
export const cartProductColumns = {
  ...productCardColumns,
  isActive: products.isActive,
  gstRate: products.gstRate,
  hsnCode: products.hsnCode,
  itemCode: products.itemCode,
  gofrugalItemId: products.gofrugalItemId,
};

export type CartProduct = ProductCardRow & {
  isActive: boolean;
  gstRate: string;
  hsnCode: string | null;
  itemCode: string;
  gofrugalItemId: string;
};

export type CartLineRow = { quantity: string; addedAt: Date; product: CartProduct };

export const cartRepository = {
  async lines(db: DbExecutor, userId: string): Promise<CartLineRow[]> {
    const rows = await db
      .select({
        quantity: cartItems.quantity,
        addedAt: cartItems.createdAt,
        product: cartProductColumns,
      })
      .from(cartItems)
      .innerJoin(products, eq(products.id, cartItems.productId))
      .where(eq(cartItems.userId, userId))
      .orderBy(asc(cartItems.createdAt), asc(cartItems.productId));
    return rows as CartLineRow[];
  },

  async lineCount(db: DbExecutor, userId: string): Promise<number> {
    const [row] = await db
      .select({ count: sql<number>`count(*)::int` })
      .from(cartItems)
      .where(eq(cartItems.userId, userId));
    return Number(row?.count ?? 0);
  },

  async findProducts(db: DbExecutor, ids: number[]) {
    if (ids.length === 0) return [];
    return db
      .select(cartProductColumns)
      .from(products)
      .where(inArray(products.id, ids)) as Promise<CartProduct[]>;
  },

  async setQuantity(db: DbExecutor, userId: string, productId: number, quantity: string) {
    await db
      .insert(cartItems)
      .values({ userId, productId, quantity })
      .onConflictDoUpdate({
        target: [cartItems.userId, cartItems.productId],
        set: { quantity, updatedAt: sql`now()` },
      });
  },

  async remove(db: DbExecutor, userId: string, productId: number) {
    await db.delete(cartItems).where(and(eq(cartItems.userId, userId), eq(cartItems.productId, productId)));
  },

  async removeMany(db: DbExecutor, userId: string, productIds: number[]) {
    if (productIds.length === 0) return;
    await db.delete(cartItems).where(and(eq(cartItems.userId, userId), inArray(cartItems.productId, productIds)));
  },

  async clear(db: DbExecutor, userId: string) {
    await db.delete(cartItems).where(eq(cartItems.userId, userId));
  },
};
