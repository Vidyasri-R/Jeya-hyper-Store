import { z } from 'zod';

const money = z
  .union([z.string().trim(), z.number()])
  .transform((value) => String(value))
  .refine((value) => /^\d{1,10}(\.\d{1,2})?$/.test(value), 'Invalid amount');

export const quoteSchema = z.object({ addressId: z.uuid('Invalid address id') }).strict();

export const placeOrderSchema = z
  .object({
    addressId: z.uuid('Invalid address id'),
    paymentMethod: z.enum(['cod', 'online']),
    /** Client generates one UUID per checkout screen; retries reuse it. */
    idempotencyKey: z.string().trim().min(8).max(64).regex(/^[A-Za-z0-9_-]+$/, 'Invalid idempotency key'),
    /** The total the customer saw. If the server's total differs, the order is refused (no surprise charges). */
    expectedTotal: money,
    customerNote: z
      .string()
      .trim()
      .max(500)
      .optional()
      .transform((value) => value || null),
  })
  .strict();

export const orderIdParams = z.object({ id: z.uuid('Invalid order id') });

export const listOrdersQuery = z.object({
  cursor: z.string().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const cancelOrderSchema = z
  .object({ reason: z.string().trim().min(2).max(255).optional() })
  .strict();

export type PlaceOrderInput = z.infer<typeof placeOrderSchema>;
