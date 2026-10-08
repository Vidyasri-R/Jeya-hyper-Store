import { describe, expect, it } from 'vitest';
import { alertText, hashDeviceKey } from './order-alerts.service';

describe('new-order alerts', () => {
  it('says the order number, total and how it is paid', () => {
    expect(alertText({ id: 'x', orderNumber: 'JHS-261008-0042', totalAmount: '480.00', paymentMethod: 'cod' })).toEqual({
      title: 'New order JHS-261008-0042',
      body: '₹480 · Cash on delivery — tap to open',
    });
    expect(alertText({ id: 'x', orderNumber: 'JHS-1', totalAmount: '45.50', paymentMethod: 'upi' }).body).toBe('₹45.50 · Paid online — tap to open');
  });

  it('keeps only a hash of the device key', () => {
    expect(hashDeviceKey('abc')).toMatch(/^[0-9a-f]{64}$/);
    expect(hashDeviceKey('abc')).not.toBe(hashDeviceKey('abd'));
  });
});
