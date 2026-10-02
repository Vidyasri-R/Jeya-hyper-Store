import { createHmac, timingSafeEqual } from 'node:crypto';
import { AppError } from '../../common/errors';
import { withRetry } from '../../common/retry';
import { env } from '../../config/env';
import { logger } from '../../config/logger';

/**
 * Minimal Razorpay REST client (no SDK): Orders, Payments, Refunds + signature checks.
 * Writes are never auto-retried (a retried POST could create a second order/refund);
 * reads retry on network errors and 5xx.
 */
const BASE_URL = 'https://api.razorpay.com/v1';
const TIMEOUT_MS = 10_000;

export type RazorpayOrder = {
  id: string;
  amount: number;
  amount_paid: number;
  currency: string;
  receipt: string | null;
  status: 'created' | 'attempted' | 'paid';
  notes: Record<string, string>;
  created_at: number;
};

export type RazorpayPayment = {
  id: string;
  order_id: string | null;
  amount: number;
  currency: string;
  status: 'created' | 'authorized' | 'captured' | 'refunded' | 'failed';
  method: 'upi' | 'card' | 'netbanking' | 'wallet' | 'emi' | 'cardless_emi' | 'paylater' | string;
  captured: boolean;
  error_code: string | null;
  error_description: string | null;
  created_at: number;
};

export type RazorpayRefund = { id: string; payment_id: string; amount: number; status: 'pending' | 'processed' | 'failed' };

class RazorpayHttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string | undefined,
    message: string,
  ) {
    super(message);
    this.name = 'RazorpayHttpError';
  }
}

export function razorpayConfigured(): boolean {
  return Boolean(env.RAZORPAY_KEY_ID && env.RAZORPAY_KEY_SECRET);
}

function credentials(): { keyId: string; secret: string } {
  if (!env.RAZORPAY_KEY_ID || !env.RAZORPAY_KEY_SECRET) {
    throw new AppError('UPSTREAM_UNAVAILABLE', 'Online payments are not configured');
  }
  return { keyId: env.RAZORPAY_KEY_ID, secret: env.RAZORPAY_KEY_SECRET };
}

async function request<T>(method: 'GET' | 'POST', path: string, body?: unknown): Promise<T> {
  const { keyId, secret } = credentials();
  const res = await fetch(`${BASE_URL}${path}`, {
    method,
    headers: {
      authorization: `Basic ${Buffer.from(`${keyId}:${secret}`).toString('base64')}`,
      ...(body ? { 'content-type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  const text = await res.text();
  const json = text ? (JSON.parse(text) as { error?: { code?: string; description?: string } }) : {};
  if (!res.ok) {
    throw new RazorpayHttpError(res.status, json.error?.code, json.error?.description ?? `Razorpay HTTP ${res.status}`);
  }
  return json as T;
}

const retryableRead = (error: unknown) =>
  !(error instanceof RazorpayHttpError) || error.status >= 500 || error.status === 429;

function hmacHex(secret: string, payload: string): string {
  return createHmac('sha256', secret).update(payload).digest('hex');
}

function safeHexEqual(expected: string, provided: string): boolean {
  const a = Buffer.from(expected, 'hex');
  const b = Buffer.from(/^[0-9a-f]+$/i.test(provided) ? provided : '', 'hex');
  return a.length > 0 && a.length === b.length && timingSafeEqual(a, b);
}

export const razorpay = {
  publicKeyId(): string {
    return credentials().keyId;
  },

  isTestMode(): boolean {
    return env.RAZORPAY_KEY_ID?.startsWith('rzp_test_') ?? true;
  },

  async createOrder(input: { amountPaise: number; receipt: string; notes: Record<string, string> }): Promise<RazorpayOrder> {
    try {
      return await request<RazorpayOrder>('POST', '/orders', {
        amount: input.amountPaise,
        currency: 'INR',
        receipt: input.receipt.slice(0, 40),
        notes: input.notes,
      });
    } catch (error) {
      logger.error({ err: error, receipt: input.receipt }, 'razorpay createOrder failed');
      throw new AppError('UPSTREAM_UNAVAILABLE', 'Could not start the payment. Please try again.');
    }
  },

  fetchOrder: (orderId: string) =>
    withRetry(() => request<RazorpayOrder>('GET', `/orders/${encodeURIComponent(orderId)}`), {
      label: 'razorpay.fetchOrder',
      shouldRetry: retryableRead,
    }),

  fetchPayment: (paymentId: string) =>
    withRetry(() => request<RazorpayPayment>('GET', `/payments/${encodeURIComponent(paymentId)}`), {
      label: 'razorpay.fetchPayment',
      shouldRetry: retryableRead,
    }),

  async fetchOrderPayments(orderId: string): Promise<RazorpayPayment[]> {
    const result = await withRetry(
      () => request<{ items: RazorpayPayment[] }>('GET', `/orders/${encodeURIComponent(orderId)}/payments`),
      { label: 'razorpay.fetchOrderPayments', shouldRetry: retryableRead },
    );
    return result.items;
  },

  /** Full refund when amountPaise is omitted. Idempotency is enforced by our refunds table, not here. */
  refund: (paymentId: string, amountPaise: number, notes: Record<string, string>) =>
    request<RazorpayRefund>('POST', `/payments/${encodeURIComponent(paymentId)}/refund`, { amount: amountPaise, notes }),

  /** Checkout success callback: HMAC_SHA256(order_id + "|" + payment_id, key_secret). */
  verifyPaymentSignature(orderId: string, paymentId: string, signature: string): boolean {
    return safeHexEqual(hmacHex(credentials().secret, `${orderId}|${paymentId}`), signature);
  },

  /** Webhook: HMAC_SHA256(raw request body, webhook secret). Must use the raw bytes, not re-serialised JSON. */
  verifyWebhookSignature(rawBody: Buffer, signature: string): boolean {
    if (!env.RAZORPAY_WEBHOOK_SECRET) return false;
    return safeHexEqual(hmacHex(env.RAZORPAY_WEBHOOK_SECRET, rawBody.toString('utf8')), signature);
  },
};
