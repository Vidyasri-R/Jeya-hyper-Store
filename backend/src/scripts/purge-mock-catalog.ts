/**
 * Removes every MOCK- product and category and resets the sync watermark.
 * Run once before switching POS_PROVIDER to the real GoFrugal API:
 *   npm run catalog:purge-mock -- --yes
 */
import { like, sql } from 'drizzle-orm';
import { closeDb, db } from '../db/client';
import { cartItems, categories, orderItems, products, syncState } from '../db/schema';

async function main(): Promise<void> {
  if (!process.argv.includes('--yes')) {
    console.error('This deletes all MOCK- catalogue data. Re-run with: npm run catalog:purge-mock -- --yes');
    process.exitCode = 2;
    return;
  }

  const result = await db.transaction(async (tx) => {
    const [ordered] = await tx
      .select({ count: sql<number>`count(*)::int` })
      .from(orderItems)
      .where(sql`${orderItems.gofrugalItemId} LIKE 'MOCK-%'`);
    if (Number(ordered?.count ?? 0) > 0) {
      throw new Error(`${ordered?.count} order line(s) reference mock products — delete those test orders first`);
    }

    await tx.delete(cartItems).where(
      sql`${cartItems.productId} IN (SELECT ${products.id} FROM ${products} WHERE ${products.gofrugalItemId} LIKE 'MOCK-%')`,
    );
    const deletedProducts = await tx
      .delete(products)
      .where(like(products.gofrugalItemId, 'MOCK-%'))
      .returning({ id: products.id });
    await tx.update(categories).set({ parentId: null }).where(like(categories.gofrugalCatId, 'MOCK-%'));
    const deletedCategories = await tx
      .delete(categories)
      .where(like(categories.gofrugalCatId, 'MOCK-%'))
      .returning({ id: categories.id });
    await tx.delete(syncState).where(sql`${syncState.key} LIKE 'gofrugal_%'`);
    return { products: deletedProducts.length, categories: deletedCategories.length };
  });

  console.log(`✔ removed ${result.products} mock products, ${result.categories} mock categories; sync watermark reset`);
}

main()
  .catch((error: unknown) => {
    console.error('❌ purge failed:', error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => closeDb());
