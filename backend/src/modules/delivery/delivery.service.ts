import { and, eq, inArray } from 'drizzle-orm';
import { fromPaise, toPaise } from '../../common/money';
import { db, type DbExecutor } from '../../db/client';
import { serviceablePincodes } from '../../db/schema';

export type DeliveryRule = {
  pincode: string;
  areaName: string;
  deliveryFeePaise: number;
  minOrderPaise: number;
  freeDeliveryAbovePaise: number | null;
};

export type DeliveryCharge = { feePaise: number; freeDeliveryApplied: boolean };

export const deliveryService = {
  async ruleFor(pincode: string, executor: DbExecutor = db): Promise<DeliveryRule | null> {
    const [row] = await executor
      .select()
      .from(serviceablePincodes)
      .where(and(eq(serviceablePincodes.pincode, pincode), eq(serviceablePincodes.isActive, true)))
      .limit(1);
    if (!row) return null;
    return {
      pincode: row.pincode,
      areaName: row.areaName,
      deliveryFeePaise: toPaise(row.deliveryFee),
      minOrderPaise: toPaise(row.minOrderAmount),
      freeDeliveryAbovePaise: row.freeDeliveryAbove !== null ? toPaise(row.freeDeliveryAbove) : null,
    };
  },

  async servicedPincodes(pincodes: string[], executor: DbExecutor = db): Promise<Set<string>> {
    if (pincodes.length === 0) return new Set();
    const rows = await executor
      .select({ pincode: serviceablePincodes.pincode })
      .from(serviceablePincodes)
      .where(and(eq(serviceablePincodes.isActive, true), inArray(serviceablePincodes.pincode, [...new Set(pincodes)])));
    return new Set(rows.map((row) => row.pincode));
  },

  charge(rule: DeliveryRule, subtotalPaise: number): DeliveryCharge {
    const free = rule.freeDeliveryAbovePaise !== null && subtotalPaise >= rule.freeDeliveryAbovePaise;
    return { feePaise: free ? 0 : rule.deliveryFeePaise, freeDeliveryApplied: free && rule.deliveryFeePaise > 0 };
  },

  toPublic(rule: DeliveryRule) {
    return {
      pincode: rule.pincode,
      areaName: rule.areaName,
      deliveryFee: fromPaise(rule.deliveryFeePaise),
      minOrderAmount: fromPaise(rule.minOrderPaise),
      freeDeliveryAbove: rule.freeDeliveryAbovePaise !== null ? fromPaise(rule.freeDeliveryAbovePaise) : null,
    };
  },
};
