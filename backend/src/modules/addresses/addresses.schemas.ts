import { z } from 'zod';
import { normalizeIndianMobile } from '../../common/phone';

const text = (max: number) => z.string().trim().min(1).max(max);
const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .nullish()
    .transform((value) => value || null);

const phone = z
  .string()
  .trim()
  .transform((value, ctx) => {
    const normalized = normalizeIndianMobile(value);
    if (!normalized) {
      ctx.addIssue({ code: 'custom', message: 'Enter a valid 10-digit mobile number' });
      return z.NEVER;
    }
    return normalized;
  });

const coordinate = (min: number, max: number) =>
  z.coerce
    .number()
    .min(min)
    .max(max)
    .transform((value) => value.toFixed(6))
    .nullish()
    .transform((value) => value ?? null);

const addressFields = {
  label: optionalText(30),
  recipientName: z.string().trim().min(2, 'Enter the recipient name').max(120),
  phone,
  pincode: z.string().trim().regex(/^[1-9][0-9]{5}$/, 'Enter a valid 6-digit pincode'),
  line1: text(255),
  line2: optionalText(255),
  landmark: optionalText(255),
  city: text(100),
  state: z.string().trim().min(2).max(100).default('Tamil Nadu'),
  latitude: coordinate(-90, 90),
  longitude: coordinate(-180, 180),
};

export const createAddressSchema = z.object({ ...addressFields, isDefault: z.boolean().default(false) }).strict();

export const updateAddressSchema = z
  .object({
    label: addressFields.label.optional(),
    recipientName: addressFields.recipientName.optional(),
    phone: addressFields.phone.optional(),
    pincode: addressFields.pincode.optional(),
    line1: addressFields.line1.optional(),
    line2: addressFields.line2.optional(),
    landmark: addressFields.landmark.optional(),
    city: addressFields.city.optional(),
    state: z.string().trim().min(2).max(100).optional(),
    latitude: addressFields.latitude.optional(),
    longitude: addressFields.longitude.optional(),
    isDefault: z.literal(true).optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, 'Nothing to update');

export const addressIdParams = z.object({ id: z.uuid('Invalid address id') });

export type CreateAddressInput = z.infer<typeof createAddressSchema>;
export type UpdateAddressInput = z.infer<typeof updateAddressSchema>;
