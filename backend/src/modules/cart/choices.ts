import { displayQty, toMilli } from '../../common/money';
import type { ProductOptions } from '../../db/schema';

/**
 * Products the store sells in several flavours/colours under ONE POS item (e.g. "Arun ₹10" ice
 * cream): the customer splits the quantity across the store's choices — {"Vanilla": "2",
 * "Chocolate": "1"}. Stock and price stay the item's; the split tells the packer what to pick.
 */
export type Choices = Record<string, string>;

/** The split, cleaned (zero entries dropped), or null when it doesn't fit the options / quantity. */
export function validChoices(raw: Choices | null | undefined, options: ProductOptions | null, qtyMilli: number): Choices | null {
  if (!options || options.values.length === 0 || !raw) return null;
  const out: Choices = {};
  let sum = 0;
  for (const [name, qty] of Object.entries(raw)) {
    if (!options.values.includes(name)) return null;
    let milli: number;
    try {
      milli = toMilli(qty);
    } catch {
      return null;
    }
    if (!Number.isFinite(milli) || milli < 0) return null;
    if (milli === 0) continue;
    out[name] = displayQty(milli);
    sum += milli;
  }
  return sum === qtyMilli && sum > 0 ? out : null;
}

/** Fewer can be bought than chosen: take the shortfall off the last choices first. */
export function clampChoices(choices: Choices, toQtyMilli: number): Choices | null {
  let left = toQtyMilli;
  const out: Choices = {};
  for (const [name, qty] of Object.entries(choices)) {
    const take = Math.min(toMilli(qty), left);
    if (take > 0) out[name] = displayQty(take);
    left -= take;
  }
  return Object.keys(out).length > 0 ? out : null;
}

/** "Vanilla × 2, Chocolate × 1" for receipts and the packing screen. */
export function describeChoices(choices: Choices | null): string | null {
  if (!choices) return null;
  return Object.entries(choices)
    .map(([name, qty]) => `${name} × ${qty}`)
    .join(', ');
}
