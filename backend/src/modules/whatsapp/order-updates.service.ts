import { sql } from 'drizzle-orm';
import { maskPhone } from '../../common/phone';
import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { whatsappMessages } from '../../db/schema';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';
import { orderEvents } from '../orders/order-events';
import { sendTemplate, whatsappConfig, WhatsAppError } from './whatsapp.client';

/**
 * WhatsApp order updates (templates order_confirmed, order_out_for_delivery, order_delivered,
 * order_cancelled, refund_processed). An outbox: every status change is already in
 * order_status_history, so a sweep after each change (and once a minute) sends what's new.
 * whatsapp_messages.ref_key makes each event go out at most once, from any path or instance.
 */

export const ORDER_TEMPLATES = ['order_confirmed', 'order_out_for_delivery', 'order_delivered', 'order_cancelled', 'refund_processed'] as const;

/** Events older than this (or from before the switch went on) are never sent. */
const LOOKBACK = '2 hours';

type Setting = { on: boolean; since: string | null };

export async function orderUpdatesSetting(): Promise<Setting> {
  const raw = (await appConfigService.getRaw(CONFIG_KEYS.WHATSAPP_ORDER_UPDATES)) as Partial<Setting> | undefined;
  return { on: raw?.on === true, since: typeof raw?.since === 'string' ? raw.since : null };
}

const rupees = (amount: string | number) => {
  const n = Number(amount);
  return Number.isInteger(n) ? String(n) : n.toFixed(2);
};

/** "today, 16 Oct" / "tomorrow, 17 Oct" / "Sat, 18 Oct" (India time). */
export function deliverBy(at: Date | null, now = new Date()): string {
  if (!at) return 'soon';
  const ist = (d: Date) => new Date(d.getTime() + 5.5 * 3600_000);
  const day = (d: Date) => ist(d).toISOString().slice(0, 10);
  const label = ist(at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', timeZone: 'UTC' });
  const diff = Math.round((Date.parse(day(at)) - Date.parse(day(now))) / 86_400_000);
  if (diff === 0) return `today, ${label}`;
  if (diff === 1) return `tomorrow, ${label}`;
  return `${ist(at).toLocaleDateString('en-IN', { weekday: 'short', timeZone: 'UTC' })}, ${label}`;
}

const firstName = (name: string | null | undefined) => (name ?? '').trim().split(/\s+/)[0] || 'there';

type HistoryEvent = {
  history_id: number;
  from_status: string | null;
  to_status: string;
  changed_by: string | null;
  note: string | null;
  order_id: string;
  order_number: string;
  total_amount: string;
  final_amount: string | null;
  payment_method: string;
  payment_status: string;
  promised_by: Date | null;
  cancelled_reason: string | null;
  phone: string;
  name: string | null;
  recipient: string | null;
};

type Outgoing = { refKey: string; kind: string; orderId: string; phone: string; template: string; body: string[]; url?: string };

/** What to send for one status change (null = nothing for this change). */
export function messageFor(e: HistoryEvent): Outgoing | null {
  const name = firstName(e.name ?? e.recipient);
  const base = { refKey: `hist:${e.history_id}`, orderId: e.order_id, phone: e.phone };
  switch (e.to_status) {
    case 'placed': // COD placed, or online payment received
      return { ...base, kind: 'order_confirmed', template: 'order_confirmed', body: [name, e.order_number, rupees(e.total_amount), deliverBy(e.promised_by)], url: e.order_id };
    case 'out_for_delivery': {
      const amount = rupees(e.final_amount ?? e.total_amount);
      const pay = e.payment_status === 'paid' ? 'Already paid online' : `₹${amount} (cash or UPI at your door)`;
      return { ...base, kind: 'order_out_for_delivery', template: 'order_out_for_delivery', body: [name, e.order_number, pay], url: e.order_id };
    }
    case 'delivered':
      return { ...base, kind: 'order_delivered', template: 'order_delivered', body: [name, e.order_number], url: e.order_id };
    case 'cancelled': {
      if (e.changed_by) return null; // the customer cancelled it themselves — they already know
      const reason = (e.cancelled_reason ?? e.note ?? 'the store could not fulfil it').replace(/[.\s]+$/, '');
      const paidOnline = e.payment_method === 'online' && ['paid', 'refunded', 'partially_refunded'].includes(e.payment_status);
      const money = paidOnline
        ? `Your refund of ₹${rupees(e.total_amount)} will reach your account in 5–7 working days.`
        : 'No payment was taken.';
      return { ...base, kind: 'order_cancelled', template: 'order_cancelled', body: [name, e.order_number, reason, money], url: e.order_id };
    }
    default:
      return null;
  }
}

async function claim(m: Outgoing): Promise<boolean> {
  const rows = await db
    .insert(whatsappMessages)
    .values({ refKey: m.refKey, kind: m.kind, orderId: m.orderId, phone: m.phone, template: m.template })
    .onConflictDoNothing({ target: whatsappMessages.refKey })
    .returning({ id: whatsappMessages.id });
  return rows.length > 0;
}

async function finish(refKey: string, status: 'sent' | 'failed' | 'skipped', patch: { providerMessageId?: string | null; error?: string }) {
  await db.execute(sql`update ${whatsappMessages}
     set status = ${status}, provider_message_id = ${patch.providerMessageId ?? null}, error = ${patch.error ?? null}
   where ref_key = ${refKey}`);
}

async function deliver(m: Outgoing) {
  const config = whatsappConfig();
  if (!config) return;
  if (!(await claim(m))) return; // already handled
  // Never message the store reviewers' demo account (smoke tests use it too).
  if (m.phone === env.DEMO_LOGIN_PHONE) return finish(m.refKey, 'skipped', { error: 'demo account' });
  try {
    const id = await sendTemplate(config, m.template, m.phone, m.body, m.url);
    await finish(m.refKey, 'sent', { providerMessageId: id });
    logger.info({ kind: m.kind, phone: maskPhone(m.phone), id }, 'WhatsApp order update sent');
  } catch (error) {
    const reason = error instanceof WhatsAppError ? error.friendly : String(error);
    await finish(m.refKey, 'failed', { error: reason.slice(0, 500) });
    logger.warn({ err: error, kind: m.kind, phone: maskPhone(m.phone) }, 'WhatsApp order update failed');
  }
}

async function sweep(): Promise<void> {
  const setting = await orderUpdatesSetting();
  if (!setting.on || !whatsappConfig()) return;
  const since = setting.since ? sql`greatest(${setting.since}::timestamptz, now() - ${LOOKBACK}::interval)` : sql`now() - ${LOOKBACK}::interval`;

  const events = (await db.execute(sql`
    select h.id as history_id, h.from_status, h.to_status, h.changed_by, h.note,
           o.id as order_id, o.order_number, o.total_amount, o.final_amount, o.payment_method, o.payment_status,
           o.promised_by, o.cancelled_reason, u.phone, u.name, o.delivery_address->>'recipientName' as recipient
      from order_status_history h
      join orders o on o.id = h.order_id
      join users u on u.id = o.user_id
     where h.created_at >= ${since}
       and h.to_status in ('placed', 'out_for_delivery', 'delivered', 'cancelled')
       and not exists (select 1 from ${whatsappMessages} m where m.ref_key = 'hist:' || h.id)
     order by h.id
     limit 100`)) as unknown as { rows?: HistoryEvent[] } & HistoryEvent[];
  for (const e of events.rows ?? events) {
    const m = messageFor(e);
    if (m) await deliver(m);
  }

  const done = (await db.execute(sql`
    select r.id, r.amount, o.id as order_id, o.order_number, u.phone, u.name, o.delivery_address->>'recipientName' as recipient
      from refunds r
      join orders o on o.id = r.order_id
      join users u on u.id = o.user_id
     where r.status = 'processed' and r.updated_at >= ${since}
       and not exists (select 1 from ${whatsappMessages} m where m.ref_key = 'refund:' || r.id)
     limit 50`)) as unknown as { rows?: RefundRow[] } & RefundRow[];
  for (const r of done.rows ?? done) {
    await deliver({
      refKey: `refund:${r.id}`,
      kind: 'refund_processed',
      orderId: r.order_id,
      phone: r.phone,
      template: 'refund_processed',
      body: [firstName(r.name ?? r.recipient), rupees(r.amount), r.order_number],
    });
  }
}

type RefundRow = { id: string; amount: string; order_id: string; order_number: string; phone: string; name: string | null; recipient: string | null };

let running: Promise<void> | null = null;
let again = false;

export const orderUpdates = {
  /** Sends what's new; overlapping calls fold into one more pass. */
  async check(): Promise<void> {
    if (running) {
      again = true;
      return running;
    }
    running = (async () => {
      do {
        again = false;
        try {
          await sweep();
        } catch (error) {
          logger.error({ err: error }, 'WhatsApp order updates sweep failed');
        }
      } while (again);
    })().finally(() => {
      running = null;
    });
    return running;
  },

  start(): void {
    orderEvents.onBump(() => void orderUpdates.check());
  },

  async set(on: boolean) {
    const current = await orderUpdatesSetting();
    // Turning it on starts from now: no flood of messages for earlier orders.
    const next: Setting = { on, since: on ? (current.on && current.since ? current.since : new Date().toISOString()) : null };
    await appConfigService.set(CONFIG_KEYS.WHATSAPP_ORDER_UPDATES, next, {
      isPublic: false,
      description: 'WhatsApp order updates (order_confirmed, out for delivery, delivered, cancelled, refund). since = when it was switched on.',
    });
    return next;
  },

  /** Recent messages for the store app (newest first). */
  async recent(limit = 20) {
    const rows = await db.execute(sql`
      select m.kind, m.status, m.error, m.created_at, m.phone, o.order_number
        from ${whatsappMessages} m left join orders o on o.id = m.order_id
       order by m.id desc limit ${limit}`);
    const list = ((rows as unknown as { rows?: unknown[] }).rows ?? (rows as unknown as unknown[])) as {
      kind: string; status: string; error: string | null; created_at: Date; phone: string; order_number: string | null;
    }[];
    return list.map((r) => ({ kind: r.kind, status: r.status, error: r.error, at: r.created_at, phone: maskPhone(r.phone), orderNumber: r.order_number }));
  },
};
