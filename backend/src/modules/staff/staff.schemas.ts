import { z } from 'zod';
import { normalizeIndianMobile } from '../../common/phone';

export const username = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9][a-z0-9._-]{2,39}$/, 'Username: 3–40 characters, letters, numbers, dot, dash or underscore');

const password = z.string().min(1, 'Enter the password').max(128);

export const staffLoginSchema = z
  .object({
    username: z.string().trim().toLowerCase().min(1, 'Enter the username').max(40),
    password,
    deviceInfo: z.string().trim().min(1).max(255).optional(),
  })
  .strict();

export const staffRefreshSchema = z.object({ refreshToken: z.string().trim().min(32).max(256) }).strict();

export const changePasswordSchema = z
  .object({ currentPassword: password, newPassword: z.string().min(8).max(128) })
  .strict();

export const optionalPhone = z
  .string()
  .trim()
  .max(20)
  .nullable()
  .optional()
  .transform((value, ctx) => {
    if (value === undefined) return undefined;
    if (value === null || value === '') return null;
    const normalized = normalizeIndianMobile(value);
    if (!normalized) {
      ctx.addIssue({ code: 'custom', message: 'Enter a valid 10-digit Indian mobile number' });
      return z.NEVER;
    }
    return normalized;
  });

export type StaffLoginInput = z.infer<typeof staffLoginSchema>;
