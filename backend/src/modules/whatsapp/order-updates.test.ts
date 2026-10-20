import { describe, expect, it } from 'vitest';
import { shapeOf, templateMessage } from './whatsapp.client';
import { deliverBy, messageFor } from './order-updates.service';

const event = (o: Partial<Parameters<typeof messageFor>[0]>) => ({
  history_id: 41,
  from_status: null,
  to_status: 'placed',
  changed_by: null,
  note: null,
  order_id: 'a5d3c2e1-0000-4000-8000-000000000001',
  order_number: 'JHS-261016-1001',
  total_amount: '480.00',
  final_amount: null,
  payment_method: 'cod',
  payment_status: 'pending',
  promised_by: new Date('2026-10-17T18:29:59.999Z'),
  cancelled_reason: null,
  phone: '919876543210',
  name: 'Priya Raman',
  recipient: null,
  ...o,
});

describe('WhatsApp order updates', () => {
  it('says today / tomorrow / weekday in India time', () => {
    const now = new Date('2026-10-16T04:00:00Z'); // 9:30 am IST, 16 Oct
    expect(deliverBy(new Date('2026-10-16T18:29:59Z'), now)).toBe('today, 16 Oct');
    expect(deliverBy(new Date('2026-10-17T18:29:59Z'), now)).toBe('tomorrow, 17 Oct');
    expect(deliverBy(new Date('2026-10-18T18:29:59Z'), now)).toBe('Sun, 18 Oct');
    // Raw SQL rows bring the timestamp back as text.
    expect(deliverBy('2026-10-17 18:29:59.999+00', now)).toBe('tomorrow, 17 Oct');
    expect(deliverBy('not a date', now)).toBe('soon');
  });

  it('order confirmed: first name, number, amount without .00, and the track link', () => {
    const m = messageFor(event({ promised_by: '2026-10-17T18:29:59.999Z' }))!;
    expect(m.template).toBe('order_confirmed');
    expect(m.body.slice(0, 3)).toEqual(['Priya', 'JHS-261016-1001', '480']);
    expect(m.url).toBe('a5d3c2e1-0000-4000-8000-000000000001');
    expect(m.refKey).toBe('hist:41');
  });

  it('out for delivery: amount to collect, or already paid', () => {
    expect(messageFor(event({ to_status: 'out_for_delivery', final_amount: '455.50' }))!.body[2]).toBe('₹455.50 (cash or UPI at your door)');
    expect(messageFor(event({ to_status: 'out_for_delivery', payment_status: 'paid', payment_method: 'online' }))!.body[2]).toBe('Already paid online');
  });

  it('cancelled by the store explains the money; the customer’s own cancel sends nothing', () => {
    const cod = messageFor(event({ to_status: 'cancelled', cancelled_reason: 'Item out of stock.' }))!;
    expect(cod.body.slice(2)).toEqual(['Item out of stock', 'No payment was taken.']);
    const paid = messageFor(event({ to_status: 'cancelled', payment_method: 'online', payment_status: 'paid', note: 'Shop closed' }))!;
    expect(paid.body[3]).toMatch(/refund of ₹480/);
    expect(messageFor(event({ to_status: 'cancelled', changed_by: 'user-1' }))).toBeNull();
    expect(messageFor(event({ to_status: 'packing' }))).toBeNull();
  });

  it('builds the request from the approved layout (variables, button, language)', () => {
    const shape = shapeOf({
      name: 'order_delivered',
      language: 'en',
      status: 'APPROVED',
      components: [
        { type: 'BODY', text: 'Hi {{1}}, your order {{2}} has been delivered.' },
        { type: 'FOOTER', text: 'Jeya Hyper Store, Trichy' },
        { type: 'BUTTONS', buttons: [{ type: 'URL', url: 'https://jeyahyperstore.in/order/{{1}}' }] },
      ],
    });
    expect(shape).toMatchObject({ bodyVars: 2, urlButtonIndex: 0 });
    const msg = templateMessage(shape, '919876543210', ['Priya', 'JHS-1'], 'abc');
    expect(msg.template.components).toEqual([
      { type: 'body', parameters: [{ type: 'text', text: 'Priya' }, { type: 'text', text: 'JHS-1' }] },
      { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: 'abc' }] },
    ]);
    const plain = shapeOf({ name: 'refund_processed', language: 'en', status: 'APPROVED', components: [{ type: 'BODY', text: 'Hi {{1}}, ₹{{2}} for {{3}}.' }] });
    expect(templateMessage(plain, '91', ['a', 'b', 'c'], 'ignored').template.components).toHaveLength(1);
    expect(() => templateMessage(plain, '91', ['a'])).toThrow();
  });
});
