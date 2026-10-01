import { z } from 'zod';

export const updateProfileSchema = z
  .object({
    name: z
      .string()
      .trim()
      .min(2, 'Name must be at least 2 characters')
      .max(120)
      .regex(/^[\p{L}\p{M}][\p{L}\p{M} .'-]*$/u, 'Name can only contain letters, spaces, . \' -')
      .optional(),
    email: z
      .union([z.email().trim().toLowerCase().max(254), z.literal('').transform(() => null), z.null()])
      .optional(),
  })
  .strict()
  .refine((value) => value.name !== undefined || value.email !== undefined, 'Nothing to update');

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
