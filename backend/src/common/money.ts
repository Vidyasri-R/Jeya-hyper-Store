/**
 * Exact money/quantity arithmetic on integers.
 *
 * Postgres numeric(12,2) money and numeric(12,3) quantities arrive as strings.
 * We parse them into integer paise / milli-units WITHOUT going through a float,
 * do all maths on integers, and format back to strings. Values stay far below
 * 2^53 (₹10 crore × 1,000 kg is ~1e13), so plain numbers are exact.
 */

function parseScaled(value: string | number, scale: number, label: string): number {
  const text = String(value).trim();
  const match = /^(-?)(\d+)(?:\.(\d+))?$/.exec(text);
  if (!match) throw new Error(`invalid ${label}: ${text}`);
  const [, sign, whole, fraction = ''] = match;
  if (fraction.length > scale && /[1-9]/.test(fraction.slice(scale))) {
    throw new Error(`${label} has more than ${scale} decimals: ${text}`);
  }
  const scaled = Number(whole) * 10 ** scale + Number(fraction.slice(0, scale).padEnd(scale, '0'));
  return sign === '-' ? -scaled : scaled;
}

function formatScaled(value: number, scale: number): string {
  const sign = value < 0 ? '-' : '';
  const abs = Math.abs(value);
  const unit = 10 ** scale;
  return `${sign}${Math.floor(abs / unit)}.${String(abs % unit).padStart(scale, '0')}`;
}

/** "68.50" → 6850 */
export const toPaise = (value: string | number): number => parseScaled(value, 2, 'amount');
/** 6850 → "68.50" */
export const fromPaise = (paise: number): string => formatScaled(paise, 2);

/** "1.250" → 1250 */
export const toMilli = (value: string | number): number => parseScaled(value, 3, 'quantity');
/** 1250 → "1.250" */
export const fromMilli = (milli: number): string => formatScaled(milli, 3);
/** 1250 → "1.25", 2000 → "2" — for display in API responses. */
export const displayQty = (milli: number): string => fromMilli(milli).replace(/\.?0+$/, '');

/** unit price × quantity, rounded half-up to the paisa. */
export function lineTotalPaise(unitPricePaise: number, qtyMilli: number): number {
  return Math.round((unitPricePaise * qtyMilli) / 1000);
}

/**
 * GST already included in a GST-inclusive amount (Indian retail prices are inclusive):
 * tax = amount × rate / (100 + rate). Rate is a percentage like "18.00".
 */
export function includedGstPaise(amountPaise: number, gstRate: string): number {
  const rateBasisPoints = toPaise(gstRate); // 18.00% → 1800
  if (rateBasisPoints <= 0) return 0;
  return Math.round((amountPaise * rateBasisPoints) / (10_000 + rateBasisPoints));
}
