/**
 * Normalises Indian mobile numbers to the stored form: `91` + 10 digits (no '+').
 *
 * Accepts "9876543210", "09876543210", "+91 98765-43210", "919876543210".
 * Returns null for anything that isn't a valid Indian mobile (must start 6–9).
 */
export function normalizeIndianMobile(input: string): string | null {
  const digits = input.replace(/[\s\-().]/g, '').replace(/^\+/, '');
  if (!/^[0-9]+$/.test(digits)) return null;

  let local: string;
  if (digits.length === 10) local = digits;
  else if (digits.length === 11 && digits.startsWith('0')) local = digits.slice(1);
  else if (digits.length === 12 && digits.startsWith('91')) local = digits.slice(2);
  else return null;

  return /^[6-9][0-9]{9}$/.test(local) ? `91${local}` : null;
}

/** "919876543210" → "98765•••10" for logs and API responses. */
export function maskPhone(phone: string): string {
  const local = phone.startsWith('91') && phone.length === 12 ? phone.slice(2) : phone;
  return `${local.slice(0, 5)}•••${local.slice(-2)}`;
}
