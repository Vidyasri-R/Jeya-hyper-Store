import { createHmac } from 'node:crypto';
import { describe, expect, it, vi } from 'vitest';
import { razorpay } from './client';

vi.mock('../../config/env', async (original) => {
  const actual = await original<typeof import('../../config/env')>();
  return {
    ...actual,
    env: { ...actual.env, RAZORPAY_KEY_ID: 'rzp_test_unit', RAZORPAY_KEY_SECRET: 'unit-test-key-secret-1234', RAZORPAY_WEBHOOK_SECRET: 'unit-webhook-secret' },
  };
});

const sign = (secret: string, payload: string) => createHmac('sha256', secret).update(payload).digest('hex');

describe('checkout signature', () => {
  const good = sign('unit-test-key-secret-1234', 'order_ABC|pay_XYZ');
  it('accepts the genuine signature', () => {
    expect(razorpay.verifyPaymentSignature('order_ABC', 'pay_XYZ', good)).toBe(true);
  });
  it('rejects a signature for a different payment or order', () => {
    expect(razorpay.verifyPaymentSignature('order_ABC', 'pay_OTHER', good)).toBe(false);
    expect(razorpay.verifyPaymentSignature('order_OTHER', 'pay_XYZ', good)).toBe(false);
  });
  it('rejects garbage without throwing', () => {
    expect(razorpay.verifyPaymentSignature('order_ABC', 'pay_XYZ', 'not-hex')).toBe(false);
    expect(razorpay.verifyPaymentSignature('order_ABC', 'pay_XYZ', '')).toBe(false);
    expect(razorpay.verifyPaymentSignature('order_ABC', 'pay_XYZ', good.slice(0, 32))).toBe(false);
  });
});

describe('webhook signature', () => {
  const body = Buffer.from('{"event":"payment.captured","payload":{}}');
  it('accepts the exact raw body', () => {
    expect(razorpay.verifyWebhookSignature(body, sign('unit-webhook-secret', body.toString()))).toBe(true);
  });
  it('rejects a body changed by one byte (e.g. re-serialised JSON)', () => {
    const sig = sign('unit-webhook-secret', body.toString());
    expect(razorpay.verifyWebhookSignature(Buffer.from('{"event": "payment.captured","payload":{}}'), sig)).toBe(false);
  });
  it('knows test vs live keys', () => {
    expect(razorpay.isTestMode()).toBe(true);
  });
});
