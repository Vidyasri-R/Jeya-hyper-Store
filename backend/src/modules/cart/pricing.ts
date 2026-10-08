import { displayQty, fromPaise, includedGstPaise, lineTotalPaise, toPaise } from '../../common/money';
import { toProductCard, withPlaceholders, type ProductCard } from '../catalog/catalog.service';
import { purchaseLimits, validateQty, type PurchaseLimits } from '../catalog/purchase-rules';
import type { CartProduct } from './cart.repository';
import { validChoices, type Choices } from './choices';

export type LineIssue =
  /** Product was deactivated / removed in the POS. */
  | 'unavailable'
  | 'out_of_stock'
  /** Wanted more than can be bought now — `limits.maxMilli` says how many can. */
  | 'exceeds_stock'
  /** Qty no longer fits min/step rules (rules changed after it was added). */
  | 'invalid_quantity'
  /** The store sells it in flavours/colours and the customer hasn't split the quantity across them. */
  | 'choose_option';

export type PricedLine = {
  product: CartProduct;
  qtyMilli: number;
  limits: PurchaseLimits;
  unitPricePaise: number;
  mrpPaise: number;
  lineTotalPaise: number;
  lineMrpTotalPaise: number;
  /** Flavour split (products with options). */
  choices: Choices | null;
  issue: LineIssue | null;
};

/** One rule set for cart display and checkout, so what the customer sees is what they pay. */
export function priceLine(product: CartProduct, qtyMilli: number, rawChoices: Choices | null = null): PricedLine {
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
  const options = product.options && product.options.values.length > 0 ? product.options : null;
  const choices = options ? validChoices(rawChoices, options, qtyMilli) : null;
  if (!issue && options && !choices) issue = 'choose_option';

  return {
    product,
    qtyMilli,
    limits,
    unitPricePaise,
    mrpPaise,
    lineTotalPaise: lineTotalPaise(unitPricePaise, qtyMilli),
    lineMrpTotalPaise: lineTotalPaise(mrpPaise, qtyMilli),
    choices,
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
  /** Flavour split, e.g. {"Vanilla": "2"} (products with options). */
  choices: Choices | null;
  /** What "Fix cart" would set this line to ("0" = removed). Present only when there's an issue. */
  suggestedQuantity: string | null;
};

/** Lines for the apps (cart, checkout): products without a photo get their category's photo. */
export async function publicLines(lines: PricedLine[]): Promise<PublicCartLine[]> {
  const items = lines.map(toPublicLine);
  const products = await withPlaceholders(items.map((item) => item.product));
  return items.map((item, i) => ({ ...item, product: products[i]! }));
}

export function toPublicLine(line: PricedLine): PublicCartLine {
  return {
    product: toProductCard(line.product),
    quantity: displayQty(line.qtyMilli),
    unitPrice: fromPaise(line.unitPricePaise),
    lineTotal: fromPaise(line.lineTotalPaise),
    lineMrpTotal: fromPaise(line.lineMrpTotalPaise),
    issue: line.issue,
    choices: line.choices,
    suggestedQuantity: line.issue ? displayQty(fixedQtyMilli(line)) : null,
  };
}
