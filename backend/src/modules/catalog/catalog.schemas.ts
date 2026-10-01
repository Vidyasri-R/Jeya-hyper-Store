import { z } from 'zod';

export const LISTING_SORTS = ['popular', 'price_asc', 'price_desc', 'name_asc'] as const;
export const SEARCH_SORTS = ['relevance', 'price_asc', 'price_desc'] as const;

const boolFlag = z
  .enum(['true', 'false', '1', '0'])
  .optional()
  .transform((value) => value === 'true' || value === '1');

export const productListQuerySchema = z.object({
  category: z.string().trim().min(1).max(170).optional(),
  q: z.string().trim().max(100).optional().transform((value) => value || undefined),
  sort: z.enum([...LISTING_SORTS, 'relevance']).optional(),
  inStock: boolFlag,
  cursor: z.string().trim().max(500).optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export const suggestQuerySchema = z.object({
  q: z.string().trim().min(1).max(100),
});

export const slugParamSchema = z.object({
  slug: z
    .string()
    .trim()
    .min(1)
    .max(300)
    .regex(/^[a-z0-9-]+$/, 'invalid slug'),
});

export type ProductListQuery = z.infer<typeof productListQuerySchema>;
