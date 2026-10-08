import { AppError } from '../../common/errors';
import { displayQty, fromMilli, fromPaise, toMilli } from '../../common/money';
import { db } from '../../db/client';
import { validateQty } from '../catalog/purchase-rules';
import { cartRepository } from './cart.repository';
import { clampChoices, type Choices } from './choices';
import { fixedQtyMilli, priceLine, publicLines, summarize, type PricedLine } from './pricing';

const MAX_CART_LINES = 100;

export async function pricedCart(userId: string): Promise<PricedLine[]> {
  const rows = await cartRepository.lines(db, userId);
  return rows.map((row) => priceLine(row.product, toMilli(row.quantity), row.choices));
}

async function toView(lines: PricedLine[]) {
  const summary = summarize(lines);
  return {
    items: await publicLines(lines),
    summary: {
      itemCount: summary.itemCount,
      subtotal: fromPaise(summary.subtotalPaise),
      mrpTotal: fromPaise(summary.mrpTotalPaise),
      savings: fromPaise(Math.max(0, summary.mrpTotalPaise - summary.subtotalPaise)),
      hasIssues: summary.hasIssues,
    },
  };
}

export type CartView = Awaited<ReturnType<typeof toView>>;

export const cartService = {
  async get(userId: string): Promise<CartView> {
    return toView(await pricedCart(userId));
  },

  /**
   * Set a line's quantity; "0" removes it. Rejects (with the allowed max) rather than silently clamping.
   * Products with options (flavours) need [choices] that split the quantity across them.
   */
  async setQuantity(userId: string, productId: number, quantity: string, choices: Choices | null = null): Promise<CartView> {
    const qtyMilli = toMilli(quantity);
    if (qtyMilli === 0) {
      await cartRepository.remove(db, userId, productId);
      return cartService.get(userId);
    }

    const [product] = await cartRepository.findProducts(db, [productId]);
    if (!product || !product.isActive) throw AppError.notFound('Product');

    const line = priceLine(product, qtyMilli, choices);
    if (line.issue === 'choose_option') {
      throw new AppError('BAD_REQUEST', `Choose the ${product.options!.label.toLowerCase()} for ${product.name}`, {
        reason: 'choose_option',
        productId,
        options: product.options,
      });
    }
    if (line.issue === 'out_of_stock') {
      throw new AppError('CONFLICT', `${product.name} is out of stock`, { reason: 'out_of_stock', productId });
    }
    const problem = validateQty(qtyMilli, line.limits, line.limits.maxMilli);
    if (problem) {
      throw new AppError(
        problem === 'above_max' ? 'CONFLICT' : 'BAD_REQUEST',
        problem === 'above_max'
          ? `Only ${displayQty(line.limits.maxMilli)} ${product.unit} of ${product.name} can be added`
          : `Quantity must be at least ${displayQty(line.limits.minMilli)} in steps of ${displayQty(line.limits.stepMilli)}`,
        {
          reason: problem === 'above_max' ? 'exceeds_stock' : 'invalid_quantity',
          productId,
          minOrderQty: displayQty(line.limits.minMilli),
          qtyStep: displayQty(line.limits.stepMilli),
          maxPurchasableQty: displayQty(line.limits.maxMilli),
        },
      );
    }

    // The limit only matters for new lines; updating an existing one is always allowed.
    const existing = await cartRepository.lines(db, userId);
    if (!existing.some((row) => row.product.id === productId) && existing.length >= MAX_CART_LINES) {
      throw new AppError('CONFLICT', `Your cart can hold up to ${MAX_CART_LINES} different items`, {
        reason: 'cart_full',
      });
    }

    await cartRepository.setQuantity(db, userId, productId, fromMilli(qtyMilli), line.choices);
    return cartService.get(userId);
  },

  async remove(userId: string, productId: number): Promise<CartView> {
    await cartRepository.remove(db, userId, productId);
    return cartService.get(userId);
  },

  async clear(userId: string): Promise<void> {
    await cartRepository.clear(db, userId);
  },

  /** "Fix my cart": clamp over-stock lines, drop unavailable ones. Returns what changed. */
  async fix(userId: string) {
    const lines = await pricedCart(userId);
    const changes: { productId: number; name: string; from: string; to: string }[] = [];
    await db.transaction(async (tx) => {
      for (const line of lines) {
        // A missing flavour choice can't be fixed for the customer: the app asks them.
        if (!line.issue || line.issue === 'choose_option') continue;
        const to = fixedQtyMilli(line);
        changes.push({ productId: line.product.id, name: line.product.name, from: displayQty(line.qtyMilli), to: displayQty(to) });
        if (to === 0) await cartRepository.remove(tx, userId, line.product.id);
        else await cartRepository.setQuantity(tx, userId, line.product.id, fromMilli(to), line.choices ? clampChoices(line.choices, to) : null);
      }
    });
    return { changes, cart: await cartService.get(userId) };
  },

  /**
   * Merge a guest (pre-login) cart. Uses the larger of the two quantities rather than
   * the sum, so retrying the merge can't double the cart. Invalid lines are skipped, not fatal.
   */
  async merge(userId: string, items: { productId: number; quantity: string; choices?: Choices | null | undefined }[]) {
    const incoming = new Map<number, number>();
    const incomingChoices = new Map<number, Choices | null>();
    for (const item of items) {
      const qty = toMilli(item.quantity);
      if (qty > 0 && qty >= (incoming.get(item.productId) ?? 0)) {
        incoming.set(item.productId, qty);
        incomingChoices.set(item.productId, item.choices ?? null);
      }
    }

    const [existing, products] = await Promise.all([
      cartRepository.lines(db, userId),
      cartRepository.findProducts(db, [...incoming.keys()]),
    ]);
    const current = new Map(existing.map((row) => [row.product.id, toMilli(row.quantity)]));
    const existingChoices = new Map(existing.map((row) => [row.product.id, row.choices]));
    const byId = new Map(products.map((product) => [product.id, product]));
    const skipped: { productId: number; reason: string }[] = [];
    let lineCount = existing.length;

    await db.transaction(async (tx) => {
      for (const [productId, qtyMilli] of incoming) {
        const product = byId.get(productId);
        if (!product || !product.isActive) {
          skipped.push({ productId, reason: 'unavailable' });
          continue;
        }
        const isNew = !current.has(productId);
        if (isNew && lineCount >= MAX_CART_LINES) {
          skipped.push({ productId, reason: 'cart_full' });
          continue;
        }
        const keepExisting = (current.get(productId) ?? 0) > qtyMilli;
        const wanted = keepExisting ? current.get(productId)! : qtyMilli;
        const wantedChoices = keepExisting ? (existingChoices.get(productId) ?? null) : (incomingChoices.get(productId) ?? null);
        const priced = priceLine(product, wanted, wantedChoices);
        const fixed = fixedQtyMilli(priced);
        if (fixed === 0) {
          skipped.push({ productId, reason: 'out_of_stock' });
          continue;
        }
        const choices = priced.choices ? clampChoices(priced.choices, fixed) : null;
        await cartRepository.setQuantity(tx, userId, productId, fromMilli(fixed), choices);
        if (isNew) lineCount++;
      }
    });

    return { skipped, cart: await cartService.get(userId) };
  },
};
