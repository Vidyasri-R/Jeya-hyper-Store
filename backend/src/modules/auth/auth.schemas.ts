import { z } from 'zod';
import { normalizeIndianMobile } from '../../common/phone';

const phone = z
  .string()
  .trim()
  .max(20)
  .transform((value, ctx) => {
    const normalized = normalizeIndianMobile(value);
    if (!normalized) {
      ctx.addIssue({ code: 'custom', message: 'Enter a valid 10-digit Indian mobile number' });
      return z.NEVER;
    }
    return normalized;
  });

export const requestOtpSchema = z.object({ phone });

export const verifyOtpSchema = z.object({
  phone,
  otp: z.string().trim().regex(/^[0-9]{6}$/, 'OTP must be 6 digits'),
  deviceId: z.string().trim().min(1).max(128).optional(),
  deviceInfo: z.string().trim().min(1).max(255).optional(),
});

export const refreshSchema = z.object({
  refreshToken: z.string().trim().min(32).max(256),
});

export const logoutSchema = refreshSchema;

export type VerifyOtpInput = z.infer<typeof verifyOtpSchema>;
