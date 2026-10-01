/**
 * Smoke test for the DB layer: `npm run db:check`
 *
 * Verifies, over the 6543 transaction pooler (the same path the API uses):
 *  1. connectivity + server version
 *  2. every schema table exists
 *  3. pg_trgm is installed
 *  4. a full insert → search → constraint → rollback cycle works (leaves no data behind)
 */
import { eq, is, sql } from 'drizzle-orm';
import { getTableConfig, PgTable } from 'drizzle-orm/pg-core';
import { closeDb, db, sqlClient } from '../db/client';
import * as schema from '../db/schema';

class Rollback extends Error {}

const expectedTables = Object.values(schema as Record<string, unknown>)
  .filter((value): value is PgTable => is(value, PgTable))
  .map((table) => getTableConfig(table).name)
  .sort();

async function main(): Promise<void> {
  const [info] = await sqlClient<{ version: string; db: string }[]>`
    select current_setting('server_version') as version, current_database() as db`;
  console.log(`✔ connected: ${info?.db} (Postgres ${info?.version})`);

  const rows = await sqlClient<{ table_name: string }[]>`
    select table_name from information_schema.tables
    where table_schema = 'public' and table_type = 'BASE TABLE'`;
  const present = new Set(rows.map((row) => row.table_name));
  const missing = expectedTables.filter((name) => !present.has(name));
  if (missing.length > 0) throw new Error(`missing tables: ${missing.join(', ')} — run npm run db:migrate`);
  console.log(`✔ all ${expectedTables.length} tables present`);

  const [trgm] = await sqlClient<{ extversion: string }[]>`
    select extversion from pg_extension where extname = 'pg_trgm'`;
  if (!trgm) throw new Error('pg_trgm extension missing');
  console.log(`✔ pg_trgm ${trgm.extversion}`);

  try {
    await db.transaction(async (tx) => {
      const [category] = await tx
        .insert(schema.categories)
        .values({ name: 'DB Check Rice', slug: `db-check-rice-${Date.now()}` })
        .returning();
      if (!category) throw new Error('category insert returned nothing');

      const [product] = await tx
        .insert(schema.products)
        .values({
          gofrugalItemId: `dbcheck-${Date.now()}`,
          itemCode: 'DBCHK001',
          name: 'Ponni Raw Rice Premium',
          nameTa: 'பொன்னி பச்சரிசி',
          brand: 'Jeya',
          slug: `db-check-ponni-${Date.now()}`,
          categoryId: category.id,
          mrp: '75.00',
          sellingPrice: '68.50',
          stockQuantity: '120.500',
          unit: 'kg',
          isLoose: true,
        })
        .returning();
      if (!product) throw new Error('product insert returned nothing');
      console.log(`✔ insert ok (product id ${product.id}, price ₹${product.sellingPrice}, stock ${product.stockQuantity})`);

      const fullText = await tx
        .select({ id: schema.products.id })
        .from(schema.products)
        .where(sql`${schema.products.searchVector} @@ plainto_tsquery('simple', 'ponni rice')`);
      if (!fullText.some((row) => row.id === product.id)) throw new Error('full-text search did not match');
      console.log('✔ full-text search ok');

      const fuzzy = await tx
        .select({ id: schema.products.id })
        .from(schema.products)
        .where(sql`${schema.products.name} % 'poni rise'`);
      if (!fuzzy.some((row) => row.id === product.id)) throw new Error('trigram fuzzy search did not match');
      console.log('✔ fuzzy (typo) search ok');

      // Atomic reservation pattern used at checkout: succeeds only if enough stock is free.
      const reserved = await tx
        .update(schema.products)
        .set({ reservedQuantity: sql`${schema.products.reservedQuantity} + ${'2.000'}` })
        .where(
          sql`${schema.products.id} = ${product.id}
              AND ${schema.products.stockQuantity} - ${schema.products.reservedQuantity} - ${schema.products.safetyStock} >= ${'2.000'}`,
        )
        .returning({ reservedQuantity: schema.products.reservedQuantity });
      if (reserved[0]?.reservedQuantity !== '2.000') throw new Error('stock reservation failed');
      console.log('✔ atomic stock reservation ok');

      const constraintRejected = await tx
        .execute(sql`savepoint ck`)
        .then(() =>
          tx.update(schema.products).set({ reservedQuantity: '-1' }).where(eq(schema.products.id, product.id)),
        )
        .then(
          () => false,
          () => true,
        );
      await tx.execute(sql`rollback to savepoint ck`);
      if (!constraintRejected) throw new Error('CHECK constraint products_reserved_ck did not fire');
      console.log('✔ CHECK constraints enforced');

      throw new Rollback();
    });
  } catch (error) {
    if (!(error instanceof Rollback)) throw error;
  }
  console.log('✔ test data rolled back\n\n🎉 Database layer is healthy.');
}

main()
  .catch((error: unknown) => {
    console.error('\n❌ db-check failed:', error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => closeDb());
