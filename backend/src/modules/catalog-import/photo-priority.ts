import type { StockItem } from './stock-csv';

/** Category groups customers buy most often get photographed first. */
const GROUP_WEIGHT: Record<string, number> = {
  rice: 25, atta: 25, dals: 25, oils: 25, masalas: 20, salt_sugar: 20, tea_coffee: 20, milk_dairy: 20, bakery: 15,
  biscuits: 15, chips: 12, health_drinks: 12, laundry: 15, dishwash: 15, bath: 12, oral: 12, hair: 10, baby: 10,
  stationery: -10, other: -15,
};

/**
 * Photo priority for a product (higher = sooner). There is no sales report in the stock file, so it
 * uses what the file shows: products the store restocks often (several open batches, recent inward)
 * sell fast; staples and daily needs first; "More Items" and stationery last.
 */
export function photoPriority(item: Pick<StockItem, 'batches' | 'updatedAt' | 'isActive'>, category: string, now = new Date()): number {
  if (!item.isActive) return 0;
  const days = (now.getTime() - item.updatedAt.getTime()) / 86_400_000;
  const recency = days <= 30 ? 30 : days <= 90 ? 15 : days <= 365 ? 5 : 0;
  return Math.max(1, Math.min(item.batches, 10) * 10 + recency + (GROUP_WEIGHT[category] ?? 0) + 20);
}
