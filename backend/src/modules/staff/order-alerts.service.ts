import { createHash, randomBytes } from 'node:crypto';
import { and, desc, eq, gt, inArray, isNull, lt, sql } from 'drizzle-orm';
import webpush from 'web-push';
import { AppError } from '../../common/errors';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { orders, staffAlertDevices, staffUsers } from '../../db/schema';
import { appConfigService } from '../app-config/app-config.service';
import { orderEvents } from '../orders/order-events';

/**
 * New-order alerts for phones where the store app is closed.
 * - Browsers / iPhone home-screen app: Web Push (VAPID keys made once, kept in app_config).
 * - Android app: its background service asks GET /staff/alerts/new-orders with a device key.
 * An order is "announced" once (orders.alerted_at): COD when placed, online once paid.
 */

const VAPID_KEY = 'push.vapid';
/** Web Push sends that may fail in a row before the subscription is dropped. */
const MAX_FAILURES = 5;
const SEND_TIMEOUT_MS = 8_000;
/** Android phones ask often; their "last seen" is written at most this often. */
const SEEN_EVERY_MS = 5 * 60_000;
/** Order roles only (photo helpers never see orders). */
const ALERT_ROLES = ['staff', 'admin'] as const;

type Vapid = { publicKey: string; privateKey: string };
let vapid: Promise<Vapid> | null = null;

function vapidKeys(): Promise<Vapid> {
  vapid ??= (async () => {
    const stored = (await appConfigService.getRaw(VAPID_KEY)) as Partial<Vapid> | undefined;
    if (stored?.publicKey && stored.privateKey) return { publicKey: stored.publicKey, privateKey: stored.privateKey };
    const fresh = webpush.generateVAPIDKeys();
    await appConfigService.set(VAPID_KEY, fresh, { isPublic: false, description: 'Web Push keys for new-order alerts (made automatically; changing them stops existing alerts).' });
    return fresh;
  })().catch((error: unknown) => {
    vapid = null;
    throw error;
  });
  return vapid;
}

export const hashDeviceKey = (key: string) => createHash('sha256').update(key).digest('hex');

type Announced = { id: string; orderNumber: string; totalAmount: string; paymentMethod: string };

/** "480.00" → "₹480", "45.50" → "₹45.50" */
const rupees = (amount: string) => `₹${amount.replace(/\.00$/, '')}`;

/** "₹480 · Cash on delivery" */
export function alertText(order: Announced): { title: string; body: string } {
  return {
    title: `New order ${order.orderNumber}`,
    body: `${rupees(order.totalAmount)} · ${order.paymentMethod === 'cod' ? 'Cash on delivery' : 'Paid online'} — tap to open`,
  };
}

async function sendWebPush(announced: Announced[]) {
  const subs = await db
    .select({ id: staffAlertDevices.id, endpoint: staffAlertDevices.endpoint, p256dh: staffAlertDevices.p256dh, auth: staffAlertDevices.auth })
    .from(staffAlertDevices)
    .innerJoin(staffUsers, eq(staffUsers.id, staffAlertDevices.staffId))
    .where(and(eq(staffAlertDevices.kind, 'web_push'), eq(staffUsers.isActive, true), inArray(staffUsers.role, [...ALERT_ROLES])));
  if (subs.length === 0) return;
  const keys = await vapidKeys();
  // Several at once (a burst after downtime): one notification that says how many.
  const first = announced[0]!;
  const text = announced.length === 1 ? alertText(first) : { title: `${announced.length} new orders`, body: 'Tap to open the order board' };
  const payload = JSON.stringify({ ...text, url: '/orders', tag: announced.length === 1 ? `order-${first.id}` : 'orders' });
  await Promise.all(
    subs.map(async (sub) => {
      try {
        await webpush.sendNotification({ endpoint: sub.endpoint!, keys: { p256dh: sub.p256dh!, auth: sub.auth! } }, payload, {
          vapidDetails: { subject: 'https://jeyahyperstore.in', publicKey: keys.publicKey, privateKey: keys.privateKey },
          TTL: 3600,
          urgency: 'high',
          timeout: SEND_TIMEOUT_MS,
        });
        await db.update(staffAlertDevices).set({ failures: 0, lastSeenAt: new Date() }).where(eq(staffAlertDevices.id, sub.id));
      } catch (error) {
        const status = (error as { statusCode?: number }).statusCode;
        if (status === 404 || status === 410) {
          // The browser dropped the subscription (app removed, permission taken back).
          await db.delete(staffAlertDevices).where(eq(staffAlertDevices.id, sub.id));
          return;
        }
        logger.warn({ err: error, status, device: sub.id }, 'web push send failed');
        await db.update(staffAlertDevices).set({ failures: sql`${staffAlertDevices.failures} + 1` }).where(eq(staffAlertDevices.id, sub.id));
        await db.delete(staffAlertDevices).where(and(eq(staffAlertDevices.id, sub.id), sql`${staffAlertDevices.failures} >= ${MAX_FAILURES}`));
      }
    }),
  );
}

let running: Promise<void> | null = null;
let again = false;

/** Claims orders that just became "placed" and pushes them to the shop's browsers. */
async function announce(): Promise<void> {
  const claimed = (await db
    .update(orders)
    .set({ alertedAt: new Date() })
    .where(and(eq(orders.orderStatus, 'placed'), isNull(orders.alertedAt)))
    .returning({ id: orders.id, orderNumber: orders.orderNumber, totalAmount: orders.totalAmount, paymentMethod: orders.paymentMethod })) as Announced[];
  if (claimed.length > 0) await sendWebPush(claimed);
}

export const orderAlerts = {
  /** Runs [announce] now, or once more right after the current run (bursts don't overlap). */
  async check(): Promise<void> {
    if (running) {
      again = true;
      return running;
    }
    running = (async () => {
      do {
        again = false;
        try {
          await announce();
        } catch (error) {
          logger.error({ err: error }, 'new-order alert failed');
        }
      } while (again);
    })().finally(() => {
      running = null;
    });
    return running;
  },

  /** After every order change (placed, paid…), and from the minute sweep as a safety net. */
  start(): void {
    orderEvents.onBump(() => void orderAlerts.check());
  },

  async webPushKey(): Promise<string> {
    return (await vapidKeys()).publicKey;
  },

  /** This browser gets alerts for [staffId] (the same browser signing in as someone else moves over). */
  async saveWebPush(staffId: string, input: { endpoint: string; p256dh: string; auth: string; label?: string | undefined }) {
    await db
      .insert(staffAlertDevices)
      .values({ staffId, kind: 'web_push', endpoint: input.endpoint, p256dh: input.p256dh, auth: input.auth, label: input.label ?? null, lastSeenAt: new Date() })
      .onConflictDoUpdate({
        target: staffAlertDevices.endpoint,
        set: { staffId, p256dh: input.p256dh, auth: input.auth, label: input.label ?? null, failures: 0, lastSeenAt: new Date(), updatedAt: new Date() },
      });
  },

  async removeWebPush(staffId: string, endpoint: string) {
    await db.delete(staffAlertDevices).where(and(eq(staffAlertDevices.endpoint, endpoint), eq(staffAlertDevices.staffId, staffId)));
  },

  /** A new Android device key (shown once; only its hash is kept). */
  async addAndroid(staffId: string, label: string | undefined): Promise<string> {
    const key = randomBytes(32).toString('base64url');
    await db.insert(staffAlertDevices).values({ staffId, kind: 'android', keyHash: hashDeviceKey(key), label: label ?? null, lastSeenAt: new Date() });
    return key;
  },

  async removeAndroid(key: string) {
    await db.delete(staffAlertDevices).where(and(eq(staffAlertDevices.kind, 'android'), eq(staffAlertDevices.keyHash, hashDeviceKey(key))));
  },

  /**
   * The Android background service's question: orders announced after [after]. Needs only the
   * device key, and answers only order numbers and totals.
   */
  /** True when [key] is a registered Android phone of an active staff member (the background service's login). */
  async isActivePhone(key: string): Promise<boolean> {
    const [device] = await db
      .select({ id: staffAlertDevices.id })
      .from(staffAlertDevices)
      .innerJoin(staffUsers, eq(staffUsers.id, staffAlertDevices.staffId))
      .where(and(eq(staffAlertDevices.kind, 'android'), eq(staffAlertDevices.keyHash, hashDeviceKey(key)), eq(staffUsers.isActive, true), inArray(staffUsers.role, [...ALERT_ROLES])))
      .limit(1);
    return Boolean(device);
  },

  async newOrdersFor(key: string, after: Date | undefined) {
    const [device] = await db
      .select({ id: staffAlertDevices.id, lastSeenAt: staffAlertDevices.lastSeenAt })
      .from(staffAlertDevices)
      .innerJoin(staffUsers, eq(staffUsers.id, staffAlertDevices.staffId))
      .where(and(eq(staffAlertDevices.kind, 'android'), eq(staffAlertDevices.keyHash, hashDeviceKey(key)), eq(staffUsers.isActive, true), inArray(staffUsers.role, [...ALERT_ROLES])))
      .limit(1);
    if (!device) throw new AppError('UNAUTHORIZED', 'This phone is no longer set up for order alerts', { reason: 'alert_device_unknown' });
    if (!device.lastSeenAt || Date.now() - device.lastSeenAt.getTime() > SEEN_EVERY_MS) {
      await db.update(staffAlertDevices).set({ lastSeenAt: new Date() }).where(eq(staffAlertDevices.id, device.id));
    }
    await orderAlerts.check();
    const now = new Date();
    // First question from a phone: nothing old, just "from now on".
    if (!after) return { now: now.toISOString(), orders: [] };
    const rows = (await db
      .select({ id: orders.id, orderNumber: orders.orderNumber, totalAmount: orders.totalAmount, paymentMethod: orders.paymentMethod, alertedAt: orders.alertedAt })
      .from(orders)
      .where(and(gt(orders.alertedAt, after), lt(orders.alertedAt, now), eq(orders.orderStatus, 'placed')))
      .orderBy(desc(orders.alertedAt))
      .limit(20)) as (Announced & { alertedAt: Date })[];
    return {
      now: now.toISOString(),
      orders: rows.map((r) => ({ id: r.id, orderNumber: r.orderNumber, ...alertText(r), alertedAt: r.alertedAt.toISOString() })),
    };
  },
};
