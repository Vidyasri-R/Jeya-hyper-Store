import { displayQty, fromPaise, includedGstPaise, lineTotalPaise, toPaise } from '../../common/money';
import { toProductCard, type ProductCard } from '../catalog/catalog.service';
import { purchaseLimits, validateQty, type PurchaseLimits } from '../catalog/purchase-rules';
import type { CartProduct } from './cart.repository';

export type LineIssue =
  /** Product was deactivated / removed in the POS. */
  | 'unavailable'
  | 'out_of_stock'
  /** Wanted more than can be bought now — `limits.maxMilli` says how many can. */
  | 'exceeds_stock'
  /** Qty no longer fits min/step rules (rules changed after it was added). */
  | 'invalid_quantity';

export type PricedLine = {
  product: CartProduct;
  qtyMilli: number;
  limits: PurchaseLimits;
  unitPricePaise: number;
  mrpPaise: number;
  lineTotalPaise: number;
  lineMrpTotalPaise: number;
  issue: LineIssue | null;
};

/** One rule set for cart display and checkout, so what the customer sees is what they pay. */
export function priceLine(product: CartProduct, qtyMilli: number): PricedLine {
  const limits = purchaseLimits(product);
  const unitPricePaise = toPaise(product.sellingPrice);
  const mrpPaise = toPaise(product.mrp);

  let issue: LineIssue | null = null;
  if (!product.isActive) issue = 'unavailable';
  else if (limits.maxMilli <= 0) issue = 'out_of_stock';
  else {
    const problem = validateQty(qtyMilli, limits, limits.maxMilli);
    if (problem === 'above_max') issue = 'exceeds_stock';
    else if (problem) issue = 'invalid_quantity';
  }

  return {
    product,
    qtyMilli,
    limits,
    unitPricePaise,
    mrpPaise,
    lineTotalPaise: lineTotalPaise(unitPricePaise, qtyMilli),
    lineMrpTotalPaise: lineTotalPaise(mrpPaise, qtyMilli),
    issue,
  };
}

/** Quantity the line would be fixed to: clamp to max, snap to step; 0 = remove. */
export function fixedQtyMilli(line: PricedLine): number {
  if (line.issue === 'unavailable' || line.issue === 'out_of_stock') return 0;
  const { minMilli, stepMilli, maxMilli } = line.limits;
  const clamped = Math.min(line.qtyMilli, maxMilli);
  const snapped = Math.floor(clamped / stepMilli) * stepMilli;
  return snapped >= minMilli ? snapped : maxMilli >= minMilli ? minMilli : 0;
}

export type CartSummary = {
  itemCount: number;
  subtotalPaise: number;
  mrpTotalPaise: number;
  includedGstPaise: number;
  hasIssues: boolean;
};

export function summarize(lines: PricedLine[]): CartSummary {
  const purchasable = lines.filter((line) => line.issue === null);
  return {
    itemCount: purchasable.length,
    subtotalPaise: purchasable.reduce((sum, line) => sum + line.lineTotalPaise, 0),
    mrpTotalPaise: purchasable.reduce((sum, line) => sum + line.lineMrpTotalPaise, 0),
    includedGstPaise: purchasable.reduce(
      (sum, line) => sum + includedGstPaise(line.lineTotalPaise, line.product.gstRate),
      0,
    ),
    hasIssues: lines.some((line) => line.issue !== null),
  };
}

export type PublicCartLine = {
  product: ProductCard;
  quantity: string;
  unitPrice: string;
  lineTotal: string;
  lineMrpTotal: string;
  issue: LineIssue | null;
  /** What "Fix cart" would set this line to ("0" = removed). Present only when there's an issue. */
  suggestedQuantity: string | null;
};

export function toPublicLine(line: PricedLine): PublicCartLine {
  return {
    product: toProductCard(line.product),
    quantity: displayQty(line.qtyMilli),
    unitPrice: fromPaise(line.unitPricePaise),
    lineTotal: fromPaise(line.lineTotalPaise),
    lineMrpTotal: fromPaise(line.lineMrpTotalPaise),
    issue: line.issue,
    suggestedQuantity: line.issue ? displayQty(fixedQtyMilli(line)) : null,
  };
}
