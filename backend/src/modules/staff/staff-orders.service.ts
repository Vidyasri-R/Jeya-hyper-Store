import { AppError } from '../../common/errors';
import { placeholderFor } from '../catalog/catalog.service';
import { displayQty, fromMilli, fromPaise, lineTotalPaise, toMilli, toPaise } from '../../common/money';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import type { Order, OrderStatus, StaffRole } from '../../db/schema';
import { orderEvents } from '../orders/order-events';
import { ordersRepository } from '../orders/orders.repository';
import { paymentsService } from '../payments/payments.service';
import { staffRepository } from './staff.repository';
import { staffOrdersRepository } from './staff-orders.repository';

/** Board tabs → statuses. Active tabs list oldest first (serve in order); finished tabs newest first. */
export const STAFF_TABS = {
  new: { statuses: ['placed'], direction: 'asc' },
  packing: { statuses: ['confirmed', 'packing'], direction: 'asc' },
  ready: { statuses: ['ready_for_delivery'], direction: 'asc' },
  out: { statuses: ['out_for_delivery'], direction: 'asc' },
  unpaid: { statuses: ['pending_payment'], direction: 'asc' },
  delivered: { statuses: ['delivered'], direction: 'desc' },
  cancelled: { statuses: ['cancelled', 'payment_failed'], direction: 'desc' },
  all: { statuses: null, direction: 'desc' },
} as const satisfies Record<string, { statuses: readonly OrderStatus[] | null; direction: 'asc' | 'desc' }>;

export type StaffTab = keyof typeof STAFF_TABS;

/** The one forward step from each status (placed may skip straight to packing). */
const NEXT: Partial<Record<OrderStatus, OrderStatus[]>> = {
  placed: ['confirmed', 'packing'],
  confirmed: ['packing'],
  packing: ['ready_for_delivery'],
  ready_for_delivery: ['out_for_delivery'],
  out_for_delivery: ['delivered'],
};

const ACTION_LABEL: Partial<Record<OrderStatus, string>> = {
  confirmed: 'Accept order',
  packing: 'Start packing',
  ready_for_delivery: 'Mark packed',
  out_for_delivery: 'Out for delivery',
  delivered: 'Mark delivered',
};

const STAFF_CANCELLABLE: OrderStatus[] = ['pending_payment', 'placed', 'confirmed', 'packing', 'ready_for_delivery', 'out_for_delivery'];

const SUMMARY_MAX_AGE_MS = 60_000;

export type AdvanceInput = {
  from: OrderStatus;
  to: OrderStatus;
  note?: string | undefined;
  packedItems?: { productId: number; packedQuantity: string }[] | undefined;
  codCollectedAmount?: string | undefined;
};

let summaryCache: { version: number; at: number; value: Awaited<ReturnType<typeof staffOrdersRepository.counts>> } | null = null;

function amountDue(order: Order): string {
  return order.finalAmount ?? order.totalAmount;
}

function encodeCursor(row: { cursorTs: string; id: string }): string {
  return Buffer.from(JSON.stringify({ t: row.cursorTs, id: row.id })).toString('base64url');
}

function decodeCursor(raw: string): { createdAt: string; id: string } {
  try {
    const parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as { t?: unknown; id?: unknown };
    if (
      typeof parsed.t === 'string' &&
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$/.test(parsed.t) &&
      typeof parsed.id === 'string' &&
      /^[0-9a-f-]{36}$/.test(parsed.id)
    ) {
      return { createdAt: parsed.t, id: parsed.id };
    }
  } catch {
    // fall through
  }
  throw new AppError('BAD_REQUEST', 'Invalid pagination cursor', { reason: 'cursor_invalid' });
}

function orderChanged(current: Order): AppError {
  return new AppError('CONFLICT', `This order was already updated (now: ${current.orderStatus.replace(/_/g, ' ')}). Refresh to see the latest.`, {
    reason: 'order_changed',
    status: current.orderStatus,
  });
}

function mapsUrl(lat: string | null, lng: string | null): string | null {
  return lat && lng ? `https://www.google.com/maps/search/?api=1&query=${lat},${lng}` : null;
}

export const staffOrdersService = {
  async list(params: { tab: StaffTab; q?: string | undefined; cursor?: string | undefined; limit: number }) {
    const searching = Boolean(params.q && params.q.trim().length >= 2);
    const tab = STAFF_TABS[searching ? 'all' : params.tab];
    const rows = await staffOrdersRepository.list(db, {
      statuses: tab.statuses ? [...tab.statuses] : null,
      search: searching ? params.q!.trim() : null,
      direction: tab.direction,
      cursor: params.cursor ? decodeCursor(params.cursor) : null,
      limit: params.limit,
    });
    const page = rows.slice(0, params.limit);
    const last = page.at(-1);
    return {
      orders: page.map(({ cursorTs: _cursor, ...row }) => ({ ...row, itemCount: Number(row.itemCount), amountDue: row.finalAmount ?? row.totalAmount })),
      nextCursor: rows.length > params.limit && last ? encodeCursor(last) : null,
    };
  },

  /** Polled by the board every ~20 s — answered from memory unless an order changed. */
  async summary() {
    const version = orderEvents.version();
    if (!summaryCache || summaryCache.version !== version || Date.now() - summaryCache.at > SUMMARY_MAX_AGE_MS) {
      summaryCache = { version, at: Date.now(), value: await staffOrdersRepository.counts(db) };
    }
    const counts = summaryCache.value;
    return {
      counts: {
        new: Number(counts.placed),
        packing: Number(counts.packing),
        ready: Number(counts.ready),
        out: Number(counts.out),
        unpaid: Number(counts.unpaid),
        deliveredToday: Number(counts.deliveredToday),
      },
      latestPlacedAt: counts.latestPlacedAt ? new Date(counts.latestPlacedAt) : null,
      version,
    };
  },

  async detail(orderId: string, viewerRole: StaffRole) {
    const found = await staffOrdersRepository.detail(db, orderId);
    if (!found) throw AppError.notFound('Order');
    const { order } = found;
    const staffNames = await staffRepository.names(
      db,
      [...new Set(found.history.map((entry) => entry.changedByStaff).filter((id): id is string => id !== null))],
    );
    const placeholders = await Promise.all(found.items.map((row) => (row.imageUrl ? null : placeholderFor(row.categoryId))));
    const next = (NEXT[order.orderStatus] ?? []).at(-1) ?? null;
    const isCod = order.paymentMethod === 'cod';

    return {
      id: order.id,
      orderNumber: order.orderNumber,
      status: order.orderStatus,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      subtotal: order.subtotal,
      deliveryFee: order.deliveryFee,
      totalAmount: order.totalAmount,
      finalAmount: order.finalAmount,
      /** What the delivery person collects at the door (0 for prepaid). */
      amountToCollect: isCod && order.orderStatus !== 'cancelled' ? amountDue(order) : '0.00',
      customerNote: order.customerNote,
      customer: found.customer ? { name: found.customer.name, phone: found.customer.phone } : null,
      deliveryAddress: order.deliveryAddress,
      mapsUrl: mapsUrl(order.deliveryAddress.latitude, order.deliveryAddress.longitude),
      items: found.items.map(({ item, barcode, packSize, isLoose, imageUrl, options }, i) => ({
        productId: item.productId,
        name: item.productName,
        itemCode: item.itemCode,
        barcode,
        unit: item.unit,
        packSize,
        isLoose,
        imageUrl,
        /** No photo yet: its category's general photo (the app labels it, so packers don't rely on it). */
        placeholderImageUrl: placeholders[i] ?? null,
        quantity: displayQty(toMilli(item.quantity)),
        /** Flavour split to pick, e.g. {"Vanilla": "2", "Chocolate": "1"}. */
        choices: item.choices,
        /** Photo of each chosen flavour/design (when the store added one). */
        choiceImages: item.choices && options?.images
          ? Object.fromEntries(Object.keys(item.choices).flatMap((name) => (options.images![name] ? [[name, options.images![name]]] : [])))
          : null,
        packedQuantity: item.packedQuantity !== null ? displayQty(toMilli(item.packedQuantity)) : null,
        unitPrice: item.unitPrice,
        mrp: item.mrp,
        totalPrice: item.totalPrice,
      })),
      history: found.history.map((entry) => ({
        status: entry.toStatus,
        note: entry.note,
        at: entry.createdAt,
        by: entry.changedByStaff ? (staffNames.get(entry.changedByStaff) ?? 'Staff') : entry.changedBy ? 'Customer' : 'System',
      })),
      payments: found.payments,
      refunds: found.refunds,
      cod: isCod
        ? { collectedAmount: order.codCollectedAmount, collectedAt: order.codCollectedAt }
        : null,
      cancelledReason: order.cancelledReason,
      placedAt: order.placedAt,
      promisedBy: order.promisedBy,
      deliveredAt: order.deliveredAt,
      cancelledAt: order.cancelledAt,
      createdAt: order.createdAt,
      actions: {
        next: next ? { to: next, label: ACTION_LABEL[next] ?? next } : null,
        canCancel: STAFF_CANCELLABLE.includes(order.orderStatus),
        // Admin-only extras could hang off viewerRole later (e.g. manual refunds).
        isAdmin: viewerRole === 'admin',
      },
    };
  },

  /** Move an order one step forward. `from` is the status the staff member saw (stale taps get a 409). */
  async advance(orderId: string, staffId: string, input: AdvanceInput) {
    if (!(NEXT[input.from] ?? []).includes(input.to)) {
      throw new AppError('BAD_REQUEST', `Can't move an order from ${input.from} to ${input.to}`, { reason: 'invalid_transition' });
    }

    const outcome = await db.transaction(async (tx) => {
      const current = await staffOrdersRepository.lock(tx, orderId);
      if (!current) throw AppError.notFound('Order');
      if (current.orderStatus === input.to) return { order: current, shortfallPaise: 0, changed: false }; // retried tap
      if (current.orderStatus !== input.from) throw orderChanged(current);

      const patch: Partial<Order> = { orderStatus: input.to };
      let note = input.note ?? null;
      let shortfallPaise = 0;

      if (input.to === 'ready_for_delivery') {
        const items = await staffOrdersRepository.items(tx, orderId);
        const packed = new Map((input.packedItems ?? []).map((entry) => [entry.productId, entry.packedQuantity]));
        for (const productId of packed.keys()) {
          if (!items.some((item) => item.productId === productId)) {
            throw new AppError('BAD_REQUEST', 'Packed item is not in this order', { reason: 'unknown_item', productId });
          }
        }
        const rows = items.map((item) => {
          const orderedMilli = toMilli(item.quantity);
          const packedMilli = packed.has(item.productId) ? toMilli(packed.get(item.productId)!) : orderedMilli;
          if (packedMilli < 0 || packedMilli > orderedMilli) {
            throw new AppError('BAD_REQUEST', `Packed quantity for ${item.productName} must be between 0 and ${displayQty(orderedMilli)}`, {
              reason: 'packed_quantity_invalid',
              productId: item.productId,
            });
          }
          const linePaise = packedMilli === orderedMilli ? toPaise(item.totalPrice) : lineTotalPaise(toPaise(item.unitPrice), packedMilli);
          shortfallPaise += toPaise(item.totalPrice) - linePaise;
          return { id: item.id, packedMilli, packedQuantity: fromMilli(packedMilli), name: item.productName, orderedMilli };
        });
        if (rows.every((row) => row.packedMilli === 0)) {
          throw new AppError('CONFLICT', 'Nothing was packed. Cancel the order instead.', { reason: 'nothing_packed' });
        }
        await staffOrdersRepository.setPackedQuantities(tx, rows);
        if (shortfallPaise > 0) {
          patch.finalAmount = fromPaise(toPaise(current.totalAmount) - shortfallPaise);
          const changes = rows
            .filter((row) => row.packedMilli !== row.orderedMilli)
            .map((row) => `${row.name}: ${displayQty(row.packedMilli)} of ${displayQty(row.orderedMilli)}`);
          note = [note, `Packed less: ${changes.join('; ')}. New total ₹${patch.finalAmount}`].filter(Boolean).join(' — ').slice(0, 500);
        }
      }

      if (input.to === 'delivered') {
        patch.deliveredAt = new Date();
        if (current.paymentMethod === 'cod') {
          if (input.codCollectedAmount === undefined) {
            throw new AppError('BAD_REQUEST', 'Enter the cash collected', { reason: 'cod_amount_required', amountDue: amountDue(current) });
          }
          const due = amountDue(current);
          if (toPaise(input.codCollectedAmount) !== toPaise(due) && !input.note) {
            throw new AppError('BAD_REQUEST', `Cash collected differs from ₹${due}. Add a note explaining why.`, {
              reason: 'cod_amount_mismatch',
              amountDue: due,
            });
          }
          patch.codCollectedAmount = fromPaise(toPaise(input.codCollectedAmount));
          patch.codCollectedAt = new Date();
          patch.codCollectedBy = staffId;
          patch.paymentStatus = 'paid';
          note = [note, `Cash collected ₹${patch.codCollectedAmount}`].filter(Boolean).join(' — ');
        } else if (current.paymentStatus === 'paid' && current.finalAmount !== null) {
          shortfallPaise = toPaise(current.totalAmount) - toPaise(current.finalAmount);
        }
        // Billed and handed over: the POS stock now reflects it, so stop holding it.
        await ordersRepository.releaseForOrders(tx, [orderId]);
      }

      const updated = await staffOrdersRepository.update(tx, orderId, patch);
      await ordersRepository.addHistory(tx, [
        { orderId, fromStatus: current.orderStatus, toStatus: input.to, changedBy: null, changedByStaff: staffId, ...(note ? { note } : {}) },
      ]);
      return { order: updated, shortfallPaise: input.to === 'delivered' ? shortfallPaise : 0, changed: true };
    });

    if (outcome.changed) {
      orderEvents.bump();
      logger.info({ orderId, staffId, from: input.from, to: input.to }, 'order status changed by staff');
    }
    if (outcome.shortfallPaise > 0) {
      await paymentsService.refundShortfall(orderId, outcome.shortfallPaise, 'Items packed short of the order');
    }
    return { id: outcome.order.id, status: outcome.order.orderStatus, changed: outcome.changed };
  },

  async cancel(orderId: string, staffId: string, input: { from: OrderStatus; reason: string }) {
    const order = await db.transaction(async (tx) => {
      const current = await staffOrdersRepository.lock(tx, orderId);
      if (!current) throw AppError.notFound('Order');
      if (current.orderStatus === 'cancelled') return null; // retried tap
      if (current.orderStatus !== input.from) throw orderChanged(current);
      if (!STAFF_CANCELLABLE.includes(current.orderStatus)) {
        throw new AppError('CONFLICT', 'This order can no longer be cancelled', { reason: 'not_cancellable', status: current.orderStatus });
      }
      await ordersRepository.releaseForOrders(tx, [orderId]);
      const updated = await staffOrdersRepository.update(tx, orderId, {
        orderStatus: 'cancelled',
        paymentStatus: current.paymentStatus === 'pending' ? 'failed' : current.paymentStatus,
        gofrugalSyncStatus: current.gofrugalSyncStatus === 'synced' ? 'synced' : 'not_required',
        cancelledAt: new Date(),
        cancelledReason: `Cancelled by store: ${input.reason}`.slice(0, 255),
        reservationExpiresAt: null,
      });
      await ordersRepository.addHistory(tx, [
        { orderId, fromStatus: current.orderStatus, toStatus: 'cancelled', changedBy: null, changedByStaff: staffId, note: `Cancelled by store: ${input.reason}` },
      ]);
      return updated;
    });
    if (!order) return { id: orderId, status: 'cancelled' as const, changed: false };
    orderEvents.bump();
    logger.info({ orderId, staffId }, 'order cancelled by store');
    if (order.paymentStatus === 'paid') await paymentsService.refundOrder(orderId, `Cancelled by store: ${input.reason}`);
    return { id: order.id, status: order.orderStatus, changed: true };
  },
};
