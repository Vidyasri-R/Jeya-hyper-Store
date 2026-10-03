import { and, eq, inArray } from 'drizzle-orm';
import { z } from 'zod';
import { haversineKm } from '../../common/geo';
import { fromPaise, toPaise } from '../../common/money';
import { logger } from '../../config/logger';
import { db, type DbExecutor } from '../../db/client';
import { serviceablePincodes } from '../../db/schema';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';

/**
 * Delivery pricing (app_config `delivery.rules`, editable without a deploy):
 *  - order subtotal ≥ freeDeliveryAbove → free;
 *  - otherwise a distance-band fee from the shop. Distance = straight line ×
 *    roadDistanceFactor (approximates road km without a paid maps API);
 *  - beyond maxDistanceKm → not serviceable;
 *  - address without a map pin → fall back to its pincode's fee in serviceable_pincodes.
 */
const money = z.string().regex(/^\d{1,8}(\.\d{1,2})?$/);

const rulesSchema = z.object({
  storeLocation: z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) }),
  maxDistanceKm: z.number().positive().max(100),
  roadDistanceFactor: z.number().min(1).max(3),
  freeDeliveryAbove: money.nullable(),
  minOrderAmount: money,
  /** Promise shown to customers: delivered by the end of the day this many days after ordering (0 = same day). */
  deliveryDays: z.number().int().min(0).max(7).default(1),
  tiers: z
    .array(z.object({ upToKm: z.number().positive(), fee: money }))
    .min(1)
    .refine((tiers) => tiers.every((tier, i) => i === 0 || tier.upToKm > tiers[i - 1]!.upToKm), 'tiers must be ascending'),
});

export type DeliveryRules = z.infer<typeof rulesSchema>;
/** Same validation for admin edits as for reads. */
export const deliveryRulesSchema = rulesSchema;

/** Jeya Hyper Store, Trichy (from the store's Google Maps pin). Tiers are PLACEHOLDERS until the store confirms. */
export const DEFAULT_DELIVERY_RULES: DeliveryRules = {
  storeLocation: { lat: 10.8127737, lng: 78.6358536 },
  maxDistanceKm: 10,
  roadDistanceFactor: 1.3,
  freeDeliveryAbove: '999.00',
  minOrderAmount: '0.00',
  deliveryDays: 1,
  tiers: [
    { upToKm: 3, fee: '20.00' },
    { upToKm: 6, fee: '40.00' },
    { upToKm: 10, fee: '60.00' },
  ],
};

export async function deliveryRules(): Promise<DeliveryRules> {
  const raw = await appConfigService.getObject(CONFIG_KEYS.DELIVERY_RULES, DEFAULT_DELIVERY_RULES as unknown as Record<string, unknown>);
  const parsed = rulesSchema.safeParse(raw);
  if (parsed.success) return parsed.data;
  logger.error({ issues: parsed.error.issues }, 'invalid delivery.rules in app_config — using defaults');
  return DEFAULT_DELIVERY_RULES;
}

const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;

/** End of the IST day `days` after `at` — "delivery by tomorrow" for days = 1. */
export function expectedDeliveryBy(at: Date, days: number): Date {
  const ist = new Date(at.getTime() + IST_OFFSET_MS);
  const endOfDayIst = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate() + days, 23, 59, 59, 999);
  return new Date(endOfDayIst - IST_OFFSET_MS);
}

export type DeliveryTarget = { pincode: string; latitude: string | null; longitude: string | null };

export type DeliveryQuote =
  | {
      serviceable: true;
      method: 'distance' | 'pincode';
      areaName: string | null;
      /** Road-adjusted km; null when priced by pincode. */
      distanceKm: number | null;
      baseFeePaise: number;
      minOrderPaise: number;
      freeDeliveryAbovePaise: number | null;
    }
  | { serviceable: false; reason: 'out_of_range' | 'pincode_not_served'; distanceKm: number | null; maxDistanceKm: number };

export type DeliveryCharge = { feePaise: number; freeDeliveryApplied: boolean };

/** Pure: distance → band. Exported for tests. */
export function quoteByDistance(rules: DeliveryRules, lat: number, lng: number): DeliveryQuote {
  const straight = haversineKm(rules.storeLocation, { lat, lng });
  const distanceKm = Math.round(straight * rules.roadDistanceFactor * 10) / 10;
  if (distanceKm > rules.maxDistanceKm) {
    return { serviceable: false, reason: 'out_of_range', distanceKm, maxDistanceKm: rules.maxDistanceKm };
  }
  const tier = rules.tiers.find((band) => distanceKm <= band.upToKm) ?? rules.tiers.at(-1)!;
  return {
    serviceable: true,
    method: 'distance',
    areaName: null,
    distanceKm,
    baseFeePaise: toPaise(tier.fee),
    minOrderPaise: toPaise(rules.minOrderAmount),
    freeDeliveryAbovePaise: rules.freeDeliveryAbove !== null ? toPaise(rules.freeDeliveryAbove) : null,
  };
}

export const deliveryService = {
  async quote(target: DeliveryTarget, executor: DbExecutor = db): Promise<DeliveryQuote> {
    const rules = await deliveryRules();
    if (target.latitude !== null && target.longitude !== null) {
      return quoteByDistance(rules, Number(target.latitude), Number(target.longitude));
    }

    const [row] = await executor
      .select()
      .from(serviceablePincodes)
      .where(and(eq(serviceablePincodes.pincode, target.pincode), eq(serviceablePincodes.isActive, true)))
      .limit(1);
    if (!row) return { serviceable: false, reason: 'pincode_not_served', distanceKm: null, maxDistanceKm: rules.maxDistanceKm };
    return {
      serviceable: true,
      method: 'pincode',
      areaName: row.areaName,
      distanceKm: null,
      baseFeePaise: toPaise(row.deliveryFee),
      minOrderPaise: toPaise(rules.minOrderAmount),
      freeDeliveryAbovePaise: rules.freeDeliveryAbove !== null ? toPaise(rules.freeDeliveryAbove) : null,
    };
  },

  /** Batch serviceability for an address list (one rules read + one pincode query). */
  async serviceability(targets: DeliveryTarget[], executor: DbExecutor = db): Promise<boolean[]> {
    const rules = await deliveryRules();
    const pincodesNeeded = targets.filter((t) => t.latitude === null || t.longitude === null).map((t) => t.pincode);
    const served = new Set<string>();
    if (pincodesNeeded.length > 0) {
      const rows = await executor
        .select({ pincode: serviceablePincodes.pincode })
        .from(serviceablePincodes)
        .where(and(eq(serviceablePincodes.isActive, true), inArray(serviceablePincodes.pincode, [...new Set(pincodesNeeded)])));
      rows.forEach((row) => served.add(row.pincode));
    }
    return targets.map((t) =>
      t.latitude !== null && t.longitude !== null
        ? quoteByDistance(rules, Number(t.latitude), Number(t.longitude)).serviceable
        : served.has(t.pincode),
    );
  },

  charge(quote: Extract<DeliveryQuote, { serviceable: true }>, subtotalPaise: number): DeliveryCharge {
    const free = quote.freeDeliveryAbovePaise !== null && subtotalPaise >= quote.freeDeliveryAbovePaise;
    return { feePaise: free ? 0 : quote.baseFeePaise, freeDeliveryApplied: free && quote.baseFeePaise > 0 };
  },

  toPublic(quote: DeliveryQuote) {
    if (!quote.serviceable) {
      return { serviceable: false as const, reason: quote.reason, distanceKm: quote.distanceKm, maxDistanceKm: quote.maxDistanceKm };
    }
    return {
      serviceable: true as const,
      method: quote.method,
      areaName: quote.areaName,
      distanceKm: quote.distanceKm,
      deliveryFee: fromPaise(quote.baseFeePaise),
      minOrderAmount: fromPaise(quote.minOrderPaise),
      freeDeliveryAbove: quote.freeDeliveryAbovePaise !== null ? fromPaise(quote.freeDeliveryAbovePaise) : null,
    };
  },

  async publicRules() {
    const rules = await deliveryRules();
    return {
      storeLocation: rules.storeLocation,
      maxDistanceKm: rules.maxDistanceKm,
      freeDeliveryAbove: rules.freeDeliveryAbove,
      minOrderAmount: rules.minOrderAmount,
      tiers: rules.tiers,
    };
  },
};
