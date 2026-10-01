import { toMilli } from '../../common/money';

/** Shown as "Only a few left" below this many steps of stock. */
const LOW_STOCK_STEPS = 5;
/** Per-line cap when the product has no explicit max (milli-units). */
const DEFAULT_MAX_MILLI = 50_000;
const DEFAULT_MAX_LOOSE_MILLI = 10_000;

export type StockStatus = 'in_stock' | 'low_stock' | 'out_of_stock';

export type PurchaseInput = {
  available: string;
  minOrderQty: string;
  qtyStep: string;
  maxOrderQty: string | null;
  isLoose: boolean;
};

export type PurchaseLimits = {
  minMilli: number;
  stepMilli: number;
  /** Largest valid qty purchasable right now; 0 = can't buy. */
  maxMilli: number;
  stockStatus: StockStatus;
};

/** Single source of truth for qty rules — catalogue cards, cart and checkout all use it. */
export function purchaseLimits(input: PurchaseInput): PurchaseLimits {
  const availableMilli = Math.max(0, Math.floor(toMilli(input.available)));
  const stepMilli = Math.max(1, toMilli(input.qtyStep));
  const minMilli = Math.max(stepMilli, toMilli(input.minOrderQty));
  const ruleMax =
    input.maxOrderQty !== null ? toMilli(input.maxOrderQty) : input.isLoose ? DEFAULT_MAX_LOOSE_MILLI : DEFAULT_MAX_MILLI;

  const rawMax = Math.min(availableMilli, ruleMax);
  // Round down to a whole number of steps so the app never offers an unsellable qty.
  const maxMilli = rawMax >= minMilli ? Math.floor(rawMax / stepMilli) * stepMilli : 0;

  const stockStatus: StockStatus =
    maxMilli <= 0 ? 'out_of_stock' : availableMilli < LOW_STOCK_STEPS * stepMilli ? 'low_stock' : 'in_stock';

  return { minMilli, stepMilli, maxMilli, stockStatus };
}

export type QtyProblem = 'below_min' | 'not_step_multiple' | 'above_max';

export function validateQty(qtyMilli: number, limits: Pick<PurchaseLimits, 'minMilli' | 'stepMilli'>, maxMilli: number): QtyProblem | null {
  if (qtyMilli < limits.minMilli) return 'below_min';
  if (qtyMilli % limits.stepMilli !== 0) return 'not_step_multiple';
  if (qtyMilli > maxMilli) return 'above_max';
  return null;
}
