import { z } from 'zod';

/**
 * POS-agnostic shapes the sync engine consumes. Each client (mock now, real
 * GoFrugal HTTP once API access is granted) maps its wire format into these,
 * and the sync engine validates every record with the schemas below before
 * it touches the DB — a single bad POS row must never break a sync batch.
 */

const decimalString = (scale: number) =>
  z
    .union([z.string(), z.number()])
    .transform((value) => String(value).trim())
    .refine((value) => /^-?\d+(\.\d+)?$/.test(value), 'must be a decimal number')
    .transform((value) => Number(value).toFixed(scale));

export const posCategorySchema = z.object({
  externalId: z.string().trim().min(1).max(64),
  name: z.string().trim().min(1).max(150),
  parentExternalId: z.string().trim().min(1).max(64).nullable(),
  sortOrder: z.number().int().default(0),
});

export const posItemSchema = z
  .object({
    externalId: z.string().trim().min(1).max(64),
    itemCode: z.string().trim().min(1).max(64),
    barcode: z.string().trim().max(64).nullable().transform((value) => value || null),
    name: z.string().trim().min(2).max(255),
    brand: z.string().trim().max(120).nullable().transform((value) => value || null),
    categoryExternalId: z.string().trim().max(64).nullable().transform((value) => value || null),
    mrp: decimalString(2),
    sellingPrice: decimalString(2),
    hsnCode: z.string().trim().max(10).nullable().transform((value) => value || null),
    gstRate: decimalString(2),
    stock: decimalString(3),
    /** Raw POS unit-of-measure, e.g. "KG", "NOS", "LTR". Mapped by mapPosUnit(). */
    unit: z.string().trim().max(20),
    packSize: z.string().trim().max(40).nullable().transform((value) => value || null),
    isActive: z.boolean(),
    /** POS "weighable/loose" flag when the POS exposes one; null = keep our value. */
    isWeighable: z.boolean().nullable(),
    updatedAt: z.coerce.date(),
  })
  .superRefine((item, ctx) => {
    const mrp = Number(item.mrp);
    const price = Number(item.sellingPrice);
    if (mrp < 0 || price < 0) ctx.addIssue({ code: 'custom', message: 'negative price' });
    if (price === 0) ctx.addIssue({ code: 'custom', message: 'selling price is zero' });
    // Legal Metrology Act: never sell above MRP. Reject rather than silently clamp.
    if (mrp > 0 && price > mrp) ctx.addIssue({ code: 'custom', message: `selling price ${price} > MRP ${mrp}` });
    const gst = Number(item.gstRate);
    if (gst < 0 || gst > 40) ctx.addIssue({ code: 'custom', message: `invalid GST rate ${gst}` });
  });

export type PosCategory = z.infer<typeof posCategorySchema>;
export type PosItem = z.infer<typeof posItemSchema>;

export type PosItemsPage = {
  /** Unvalidated records — the sync engine runs posItemSchema on each. */
  items: unknown[];
  hasMore: boolean;
};

export interface PosCatalogClient {
  readonly name: string;
  fetchCategories(): Promise<unknown[]>;
  /** modifiedSince = null → full catalogue. Pages are 1-based. */
  fetchItemsPage(params: { modifiedSince: Date | null; page: number; pageSize: number }): Promise<PosItemsPage>;
}

const UNIT_MAP: Record<string, 'pcs' | 'kg' | 'g' | 'l' | 'ml' | 'pack' | 'dozen'> = {
  NOS: 'pcs',
  NO: 'pcs',
  PCS: 'pcs',
  PC: 'pcs',
  EA: 'pcs',
  KG: 'kg',
  KGS: 'kg',
  G: 'g',
  GM: 'g',
  GMS: 'g',
  GRM: 'g',
  L: 'l',
  LT: 'l',
  LTR: 'l',
  LTRS: 'l',
  ML: 'ml',
  PKT: 'pack',
  PACK: 'pack',
  BOX: 'pack',
  DOZ: 'dozen',
  DOZEN: 'dozen',
};

export function mapPosUnit(raw: string): 'pcs' | 'kg' | 'g' | 'l' | 'ml' | 'pack' | 'dozen' {
  return UNIT_MAP[raw.trim().toUpperCase()] ?? 'pcs';
}
