import { z } from 'zod';
import { AppError } from '../../common/errors';
import { normalizeIndianMobile } from '../../common/phone';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';
import { DEFAULT_DELIVERY_RULES, deliveryRulesSchema } from '../delivery/delivery.service';
import { DEFAULT_USAGE_LIMITS, usageLimitsSchema } from '../usage/usage.limits';

const phoneOrNull = z
  .string()
  .trim()
  .max(20)
  .nullable()
  .transform((value, ctx) => {
    if (value === null || value === '') return null;
    const normalized = normalizeIndianMobile(value);
    if (!normalized) {
      ctx.addIssue({ code: 'custom', message: 'Enter a valid 10-digit Indian mobile number' });
      return z.NEVER;
    }
    return normalized;
  });

/**
 * What the admin app may edit, with the same validation the readers apply. `isPublic` keys are
 * served to the customer app via GET /v1/config, so nothing secret belongs here.
 */
const SETTINGS = {
  [CONFIG_KEYS.DELIVERY_RULES]: {
    schema: deliveryRulesSchema,
    fallback: DEFAULT_DELIVERY_RULES,
    isPublic: true,
    description: 'Free above freeDeliveryAbove; else fee by distance band from the shop.',
  },
  [CONFIG_KEYS.PAYMENT_METHODS]: {
    schema: z.object({ cod: z.boolean(), online: z.boolean() }).strict().refine((v) => v.cod || v.online, 'Keep at least one payment method on'),
    fallback: { cod: true, online: false },
    isPublic: true,
    description: 'Payment options shown at checkout.',
  },
  [CONFIG_KEYS.STORE_INFO]: {
    schema: z
      .object({
        name: z.string().trim().min(2).max(80),
        city: z.string().trim().min(2).max(60),
        supportPhone: phoneOrNull,
        supportWhatsApp: phoneOrNull,
        address: z.string().trim().max(250).nullable().optional(),
        openingHours: z.string().trim().max(120).nullable().optional(),
      })
      .strict(),
    fallback: { name: 'Jeya Hyper Store', city: 'Tiruchirappalli', supportPhone: null, supportWhatsApp: null },
    isPublic: true,
    description: 'Store contact details shown in the app.',
  },
  [CONFIG_KEYS.APP_THEME]: {
    schema: z
      .object({
        /** Festival look of the customer app; presets are designed into the app. */
        preset: z.enum(['standard', 'diwali', 'pongal', 'christmas', 'valentine', 'puthandu', 'eid', 'national', 'vinayagar', 'navaratri', 'karthigai']),
        /** Shown from/until (ISO times); null = no limit on that side. */
        startsAt: z.iso.datetime({ offset: true }).nullable(),
        endsAt: z.iso.datetime({ offset: true }).nullable(),
        greeting: z.string().trim().max(120).nullable(),
      })
      .strict()
      .refine((v) => !v.startsAt || !v.endsAt || new Date(v.endsAt) > new Date(v.startsAt), { message: 'End must be after start', path: ['endsAt'] }),
    fallback: { preset: 'standard', startsAt: null, endsAt: null, greeting: null },
    isPublic: true,
    description: 'Festival theme for the customer app (e.g. Diwali) and when it is shown.',
  },
  [CONFIG_KEYS.APP_BRAND]: {
    schema: z
      .object({
        /** Main brand colour (#RRGGBB); the app derives every shade and keeps text readable. */
        color: z.string().trim().regex(/^#[0-9a-fA-F]{6}$/, 'Use a colour like #1B7A3E').transform((v) => v.toUpperCase()),
      })
      .strict(),
    fallback: { color: '#1B7A3E' },
    isPublic: true,
    description: 'Everyday brand colour of the customer app (festival themes take over on their dates).',
  },
  [CONFIG_KEYS.MAINTENANCE]: {
    schema: z.object({ enabled: z.boolean(), message: z.string().trim().max(200) }).strict(),
    fallback: { enabled: false, message: '' },
    isPublic: true,
    description: 'Show a maintenance banner and block checkout.',
  },
  [CONFIG_KEYS.DEMO_LOGIN_ENABLED]: {
    schema: z.boolean(),
    fallback: false,
    isPublic: false,
    description: 'Accept the fixed reviewer OTP for DEMO_LOGIN_PHONE. Turn OFF after store approval.',
  },
  [CONFIG_KEYS.MIN_APP_VERSION]: {
    schema: z.object({ android: z.string().regex(/^\d+\.\d+\.\d+$/), ios: z.string().regex(/^\d+\.\d+\.\d+$/) }).strict(),
    fallback: { android: '1.0.0', ios: '1.0.0' },
    isPublic: true,
    description: 'App shows a force-update screen below this version.',
  },
  [CONFIG_KEYS.USAGE_LIMITS]: {
    schema: usageLimitsSchema,
    fallback: DEFAULT_USAGE_LIMITS,
    isPublic: false,
    description: 'Plan limits and prices the usage monitor compares against.',
  },
} as const satisfies Record<string, { schema: z.ZodType; fallback: unknown; isPublic: boolean; description: string }>;

export type SettingKey = keyof typeof SETTINGS;
export const SETTING_KEYS = Object.keys(SETTINGS) as SettingKey[];

export const adminSettingsService = {
  async all() {
    const entries = await Promise.all(
      SETTING_KEYS.map(async (key) => {
        const stored = await appConfigService.getRaw(key);
        return [key, stored === undefined ? SETTINGS[key].fallback : stored] as const;
      }),
    );
    return Object.fromEntries(entries);
  },

  async set(key: string, value: unknown) {
    if (!(key in SETTINGS)) throw new AppError('NOT_FOUND', `Unknown setting ${key}`);
    const setting = SETTINGS[key as SettingKey];
    const parsed = (setting.schema as z.ZodType).parse(value);
    await appConfigService.set(key, parsed, { isPublic: setting.isPublic, description: setting.description });
    return parsed;
  },
};
