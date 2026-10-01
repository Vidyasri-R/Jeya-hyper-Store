import { AppError, PG_ERROR, pgErrorCode } from '../../common/errors';
import { displayQty, fromMilli, fromPaise, includedGstPaise, toMilli, toPaise } from '../../common/money';
import { logger } from '../../config/logger';
import { db, type Transaction } from '../../db/client';
import type { DeliveryAddressSnapshot, Order, OrderItem, OrderStatus, OrderStatusHistory } from '../../db/schema';
import { addressesRepository } from '../addresses/addresses.repository';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';
import { cartRepository } from '../cart/cart.repository';
import { priceLine, summarize, toPublicLine, type PricedLine } from '../cart/pricing';
import { deliveryService, type DeliveryRule } from '../delivery/delivery.service';
import { ordersRepository } from './orders.repository';
import type { PlaceOrderInput } from './orders.schemas';

/** How long an unpaid online order holds its stock. */
export const PAYMENT_HOLD_MS = 15 * 60 * 1000;

/** Customer may cancel until the store starts working on it. */
const CUSTOMER_CANCELLABLE: OrderStatus[] = ['pending_payment', 'placed'];

type Blocker =
  | { reason: 'cart_empty' }
  | { reason: 'cart_needs_review'; items: { productId: number; name: string; issue: string; suggestedQuantity: string | null }[] }
  | { reason: 'address_not_serviceable'; pincode: string }
  | { reason: 'below_minimum'; minOrderAmount: string; shortBy: string };

type Evaluation = {
  lines: PricedLine[];
  rule: DeliveryRule | null;
  subtotalPaise: number;
  mrpTotalPaise: number;
  deliveryFeePaise: number;
  freeDeliveryApplied: boolean;
  totalPaise: number;
  blockers: Blocker[];
};

async function evaluate(executor: Transaction | typeof db, userId: string, pincode: string): Promise<Evaluation> {
  const [rows, rule] = await Promise.all([
    cartRepository.lines(executor, userId),
    deliveryService.ruleFor(pincode, executor),
  ]);
  const lines = rows.map((row) => priceLine(row.product, toMilli(row.quantity)));
  const summary = summarize(lines);

  const blockers: Blocker[] = [];
  if (lines.length === 0) blockers.push({ reason: 'cart_empty' });
  const flagged = lines.filter((line) => line.issue !== null);
  if (flagged.length > 0) {
    blockers.push({
      reason: 'cart_needs_review',
      items: flagged.map((line) => {
        const view = toPublicLine(line);
        return { productId: line.product.id, name: line.product.name, issue: line.issue!, suggestedQuantity: view.suggestedQuantity };
      }),
    });
  }
  if (!rule) blockers.push({ reason: 'address_not_serviceable', pincode });
  else if (lines.length > 0 && summary.subtotalPaise < rule.minOrderPaise) {
    blockers.push({
      reason: 'below_minimum',
      minOrderAmount: fromPaise(rule.minOrderPaise),
      shortBy: fromPaise(rule.minOrderPaise - summary.subtotalPaise),
    });
  }

  const delivery = rule ? deliveryService.charge(rule, summary.subtotalPaise) : { feePaise: 0, freeDeliveryApplied: false };
  return {
    lines,
    rule,
    subtotalPaise: summary.subtotalPaise,
    mrpTotalPaise: summary.mrpTotalPaise,
    deliveryFeePaise: delivery.feePaise,
    freeDeliveryApplied: delivery.freeDeliveryApplied,
    totalPaise: summary.subtotalPaise + delivery.feePaise,
    blockers,
  };
}

async function paymentMethods() {
  return appConfigService.getObject(CONFIG_KEYS.PAYMENT_METHODS, { cod: true, online: false });
}

function orderNumber(seq: number, at: Date): string {
  const ist = new Date(at.getTime() + 5.5 * 60 * 60 * 1000);
  const yymmdd = ist.toISOString().slice(2, 10).replace(/-/g, '');
  return `JHS-${yymmdd}-${seq}`;
}

function blockerError(blocker: Blocker): AppError {
  const messages: Record<Blocker['reason'], string> = {
    cart_empty: 'Your cart is empty',
    cart_needs_review: 'Some items in your cart changed. Please review your cart.',
    address_not_serviceable: "We don't deliver to this pincode yet",
    below_minimum: 'Add more items to reach the minimum order value',
  };
  return new AppError('CONFLICT', messages[blocker.reason], blocker);
}

function toPublicOrder(order: Order, itemCount?: number) {
  const status = order.orderStatus;
  return {
    id: order.id,
    orderNumber: order.orderNumber,
    status,
    paymentStatus: order.paymentStatus,
    paymentMethod: order.paymentMethod,
    subtotal: order.subtotal,
    discountAmount: order.discountAmount,
    deliveryFee: order.deliveryFee,
    taxTotal: order.taxTotal,
    totalAmount: order.totalAmount,
    finalAmount: order.finalAmount,
    deliveryAddress: order.deliveryAddress,
    customerNote: order.customerNote,
    reservationExpiresAt: status === 'pending_payment' ? order.reservationExpiresAt : null,
    canCancel: CUSTOMER_CANCELLABLE.includes(status) && order.paymentStatus !== 'paid',
    placedAt: order.placedAt,
    deliveredAt: order.deliveredAt,
    cancelledAt: order.cancelledAt,
    createdAt: order.createdAt,
    ...(itemCount !== undefined ? { itemCount } : {}),
  };
}

function toPublicItem(item: OrderItem) {
  return {
    productId: item.productId,
    name: item.productName,
    itemCode: item.itemCode,
    unit: item.unit,
    quantity: displayQty(toMilli(item.quantity)),
    packedQuantity: item.packedQuantity !== null ? displayQty(toMilli(item.packedQuantity)) : null,
    mrp: item.mrp,
    unitPrice: item.unitPrice,
    totalPrice: item.totalPrice,
  };
}

function toPublicHistory(entry: OrderStatusHistory) {
  return { status: entry.toStatus, note: entry.note, at: entry.createdAt };
}

function encodeOrderCursor(order: Order): string {
  return Buffer.from(JSON.stringify({ t: order.createdAt.toISOString(), id: order.id })).toString('base64url');
}

function decodeOrderCursor(raw: string): { createdAt: Date; id: string } {
  try {
    const parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as { t?: unknown; id?: unknown };
    const createdAt = new Date(String(parsed.t));
    if (typeof parsed.id === 'string' && /^[0-9a-f-]{36}$/.test(parsed.id) && !Number.isNaN(createdAt.getTime())) {
      return { createdAt, id: parsed.id };
    }
  } catch {
    // fall through
  }
  throw new AppError('BAD_REQUEST', 'Invalid pagination cursor', { reason: 'cursor_invalid' });
}

export const ordersService = {
  /** Read-only checkout preview: exactly the numbers placeOrder will charge, plus anything blocking it. */
  async quote(userId: string, addressId: string) {
    const address = await addressesRepository.findForUser(db, userId, addressId);
    if (!address) throw AppError.notFound('Address');
    const evaluation = await evaluate(db, userId, address.pincode);
    const methods = await paymentMethods();
    return {
      items: evaluation.lines.map(toPublicLine),
      totals: {
        subtotal: fromPaise(evaluation.subtotalPaise),
        mrpTotal: fromPaise(evaluation.mrpTotalPaise),
        savings: fromPaise(Math.max(0, evaluation.mrpTotalPaise - evaluation.subtotalPaise)),
        deliveryFee: fromPaise(evaluation.deliveryFeePaise),
        freeDeliveryApplied: evaluation.freeDeliveryApplied,
        total: fromPaise(evaluation.totalPaise),
      },
      delivery: evaluation.rule ? deliveryService.toPublic(evaluation.rule) : null,
      paymentMethods: methods,
      canPlaceOrder: evaluation.blockers.length === 0,
      blockers: evaluation.blockers,
    };
  },

  async placeOrder(userId: string, input: PlaceOrderInput) {
    const methods = await paymentMethods();
    if (!methods[input.paymentMethod]) {
      throw new AppError('CONFLICT', 'This payment method is not available right now', {
        reason: 'payment_method_unavailable',
        paymentMethods: methods,
      });
    }

    try {
      return await db.transaction(async (tx) => {
        const existing = await ordersRepository.findByIdempotencyKey(tx, userId, input.idempotencyKey);
        if (existing) return { order: toPublicOrder(existing), created: false };

        const address = await addressesRepository.findForUser(tx, userId, input.addressId);
        if (!address) throw AppError.notFound('Address');

        const evaluation = await evaluate(tx, userId, address.pincode);
        const [firstBlocker] = evaluation.blockers;
        if (firstBlocker) throw blockerError(firstBlocker);

        if (toPaise(input.expectedTotal) !== evaluation.totalPaise) {
          throw new AppError('CONFLICT', 'Prices or delivery charges changed. Please review the new total.', {
            reason: 'total_changed',
            expectedTotal: input.expectedTotal,
            total: fromPaise(evaluation.totalPaise),
          });
        }

        const short = await ordersRepository.reserve(
          tx,
          evaluation.lines.map((line) => ({ productId: line.product.id, quantity: fromMilli(line.qtyMilli) })),
        );
        if (short.length > 0) {
          // Someone bought it between cart refresh and now; the transaction rolls back every reservation.
          throw new AppError('CONFLICT', 'Some items just went out of stock. Please review your cart.', {
            reason: 'stock_changed',
            productIds: short,
          });
        }

        const now = new Date();
        const isCod = input.paymentMethod === 'cod';
        const status: OrderStatus = isCod ? 'placed' : 'pending_payment';
        const snapshot: DeliveryAddressSnapshot = {
          recipientName: address.recipientName,
          phone: address.phone,
          pincode: address.pincode,
          line1: address.line1,
          line2: address.line2,
          landmark: address.landmark,
          city: address.city,
          state: address.state,
          latitude: address.latitude,
          longitude: address.longitude,
        };

        const order = await ordersRepository.insertOrder(tx, {
          orderNumber: orderNumber(await ordersRepository.nextOrderSeq(tx), now),
          userId,
          addressId: address.id,
          deliveryAddress: snapshot,
          subtotal: fromPaise(evaluation.subtotalPaise),
          deliveryFee: fromPaise(evaluation.deliveryFeePaise),
          taxTotal: fromPaise(
            evaluation.lines.reduce((sum, line) => sum + includedGstPaise(line.lineTotalPaise, line.product.gstRate), 0),
          ),
          totalAmount: fromPaise(evaluation.totalPaise),
          paymentStatus: 'pending',
          // 'online' = prepaid; the exact method (UPI/card/…) is recorded on the payment row.
          paymentMethod: input.paymentMethod,
          orderStatus: status,
          idempotencyKey: input.idempotencyKey,
          customerNote: input.customerNote,
          reservationExpiresAt: isCod ? null : new Date(now.getTime() + PAYMENT_HOLD_MS),
          // Online orders are pushed to GoFrugal only after payment is captured.
          gofrugalSyncStatus: 'pending',
          placedAt: isCod ? now : null,
        });

        await ordersRepository.insertItems(
          tx,
          evaluation.lines.map((line) => ({
            orderId: order.id,
            productId: line.product.id,
            itemCode: line.product.itemCode,
            gofrugalItemId: line.product.gofrugalItemId,
            productName: line.product.name,
            unit: line.product.unit,
            mrp: line.product.mrp,
            unitPrice: line.product.sellingPrice,
            gstRate: line.product.gstRate,
            hsnCode: line.product.hsnCode,
            quantity: fromMilli(line.qtyMilli),
            totalPrice: fromPaise(line.lineTotalPaise),
          })),
        );
        await ordersRepository.addHistory(tx, [
          { orderId: order.id, fromStatus: null, toStatus: status, changedBy: userId, note: isCod ? 'Cash on delivery' : 'Awaiting payment' },
        ]);
        await cartRepository.clear(tx, userId);

        logger.info({ orderId: order.id, orderNumber: order.orderNumber, total: order.totalAmount, method: input.paymentMethod }, 'order placed');
        return { order: toPublicOrder(order, evaluation.lines.length), created: true };
      });
    } catch (error) {
      // Two simultaneous submits with the same key: the loser hits the unique index — return the winner's order.
      if (pgErrorCode(error) === PG_ERROR.UNIQUE_VIOLATION) {
        const existing = await ordersRepository.findByIdempotencyKey(db, userId, input.idempotencyKey);
        if (existing) return { order: toPublicOrder(existing), created: false };
      }
      throw error;
    }
  },

  async list(userId: string, cursor: string | undefined, limit: number) {
    const rows = await ordersRepository.listForUser(db, userId, cursor ? decodeOrderCursor(cursor) : null, limit);
    const page = rows.slice(0, limit);
    const last = page.at(-1);
    return {
      orders: page.map((row) => toPublicOrder(row.order, Number(row.itemCount))),
      nextCursor: rows.length > limit && last ? encodeOrderCursor(last.order) : null,
    };
  },

  async get(userId: string, orderId: string) {
    const found = await ordersRepository.findForUser(db, userId, orderId);
    if (!found) throw AppError.notFound('Order');
    return {
      ...toPublicOrder(found.order, found.items.length),
      items: found.items.map(toPublicItem),
      statusHistory: found.history.map(toPublicHistory),
    };
  },

  async cancel(userId: string, orderId: string, reason: string | undefined) {
    const order = await db.transaction(async (tx) => {
      const current = await ordersRepository.lockForUser(tx, userId, orderId);
      if (!current) throw AppError.notFound('Order');
      if (!CUSTOMER_CANCELLABLE.includes(current.orderStatus)) {
        throw new AppError('CONFLICT', 'This order can no longer be cancelled. Please contact the store.', {
          reason: 'not_cancellable',
          status: current.orderStatus,
        });
      }
      if (current.paymentStatus === 'paid') {
        // Refund flow lands with Razorpay (Step 4b); until then a paid order is cancelled by the store.
        throw new AppError('CONFLICT', 'This order is paid. Please contact the store to cancel and get a refund.', {
          reason: 'paid_needs_refund',
        });
      }
      await ordersRepository.releaseForOrders(tx, [orderId]);
      const updated = await ordersRepository.updateOrder(tx, orderId, {
        orderStatus: 'cancelled',
        paymentStatus: current.paymentStatus === 'pending' ? 'failed' : current.paymentStatus,
        gofrugalSyncStatus: 'not_required',
        cancelledAt: new Date(),
        cancelledReason: reason ?? 'Cancelled by customer',
        reservationExpiresAt: null,
      });
      await ordersRepository.addHistory(tx, [
        { orderId, fromStatus: current.orderStatus, toStatus: 'cancelled', changedBy: userId, note: reason ?? 'Cancelled by customer' },
      ]);
      return updated!;
    });
    logger.info({ orderId, userId }, 'order cancelled by customer');
    return toPublicOrder(order);
  },

  /** Sweeper: unpaid online orders past their hold → payment_failed, stock released. */
  async expireUnpaid(batchSize = 50): Promise<number> {
    return db.transaction(async (tx) => {
      const expired = await ordersRepository.lockExpiredPending(tx, batchSize);
      const ids = expired.map((row) => row.id);
      if (ids.length === 0) return 0;
      await ordersRepository.releaseForOrders(tx, ids);
      await ordersRepository.markPaymentFailed(tx, ids);
      await ordersRepository.addHistory(
        tx,
        ids.map((id) => ({ orderId: id, fromStatus: 'pending_payment' as const, toStatus: 'payment_failed' as const, changedBy: null, note: 'Payment not received in time; items released' })),
      );
      logger.info({ count: ids.length }, 'expired unpaid orders');
      return ids.length;
    });
  },
};
