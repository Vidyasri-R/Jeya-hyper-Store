import { buildMockCatalog, type MockItem } from './mock-catalog';
import type { PosCatalogClient, PosItemsPage } from './types';

/**
 * In-memory stand-in for the GoFrugal API with the same paging/delta semantics:
 * items are ordered by (updatedAt, externalId) and `modifiedSince` is exclusive.
 * `simulateChanges` mutates prices/stock like a busy store day so delta sync
 * can be exercised end to end.
 */
export class MockGoFrugalClient implements PosCatalogClient {
  readonly name = 'gofrugal-mock';
  private readonly catalog = buildMockCatalog();

  async fetchCategories(): Promise<unknown[]> {
    return structuredClone(this.catalog.categories);
  }

  async fetchItemsPage({
    modifiedSince,
    page,
    pageSize,
  }: {
    modifiedSince: Date | null;
    page: number;
    pageSize: number;
  }): Promise<PosItemsPage> {
    const since = modifiedSince?.getTime() ?? Number.NEGATIVE_INFINITY;
    const matching = this.catalog.items
      .filter((item) => new Date(item.updatedAt).getTime() > since)
      .sort((a, b) => a.updatedAt.localeCompare(b.updatedAt) || a.externalId.localeCompare(b.externalId));
    const start = (page - 1) * pageSize;
    return {
      items: structuredClone(matching.slice(start, start + pageSize)),
      hasMore: start + pageSize < matching.length,
    };
  }

  /** Mutate `count` items (stock, price, or deactivate) and stamp them with `at`. */
  simulateChanges(count: number, at = new Date()): MockItem[] {
    const changed: MockItem[] = [];
    const items = this.catalog.items;
    for (let i = 0; i < count && items.length > 0; i++) {
      const item = items[(i * 37 + at.getMinutes()) % items.length];
      if (!item) continue;
      const kind = i % 5;
      if (kind === 0) item.sellingPrice = Math.max(1, Math.min(item.mrp, item.sellingPrice - 1));
      else if (kind === 4) item.isActive = !item.isActive;
      else item.stock = Math.max(0, Number((item.stock - 1).toFixed(3)));
      item.updatedAt = at.toISOString();
      changed.push(structuredClone(item));
    }
    return changed;
  }

  /** Inject a POS row that violates our validation rules (selling price > MRP). */
  injectInvalidItem(at = new Date()): void {
    this.catalog.items.push({
      externalId: 'MOCK-I-BAD-1',
      itemCode: 'MKBAD1',
      barcode: null,
      name: 'Broken Price Item',
      brand: null,
      categoryExternalId: 'MOCK-C-SNACKS',
      mrp: 10,
      sellingPrice: 25,
      hsnCode: null,
      gstRate: 18,
      stock: 5,
      unit: 'NOS',
      packSize: null,
      isActive: true,
      isWeighable: false,
      updatedAt: at.toISOString(),
    });
  }
}
