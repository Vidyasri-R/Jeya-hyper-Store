import { z } from 'zod';

/** "1", "0.25", 2 — up to 3 decimals, 0 means remove. */
export const quantitySchema = z
  .union([z.string().trim(), z.number()])
  .transform((value) => String(value))
  .refine((value) => /^\d{1,6}(\.\d{1,3})?$/.test(value), 'Quantity must be a number with at most 3 decimals');

export const productIdParams = z.object({ productId: z.coerce.number().int().positive() });

/** Flavour split for products with options: {"Vanilla": "2", "Chocolate": "1"}. */
export const choicesSchema = z.record(z.string().trim().min(1).max(40), quantitySchema).nullable().optional();

export const setQuantitySchema = z.object({ quantity: quantitySchema, choices: choicesSchema }).strict();

export const mergeCartSchema = z
  .object({
    items: z
      .array(z.object({ productId: z.number().int().positive(), quantity: quantitySchema, choices: choicesSchema }))
      .max(100),
  })
  .strict();
