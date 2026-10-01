import { createHash, createHmac, randomBytes, randomInt, timingSafeEqual } from 'node:crypto';

export function sha256Hex(value: string): string {
  return createHash('sha256').update(value).digest('hex');
}

export function hmacSha256Hex(secret: string, value: string): string {
  return createHmac('sha256', secret).update(value).digest('hex');
}

/** Constant-time string comparison (length leak only, which is fine for fixed-length hashes/codes). */
export function safeEqual(a: string, b: string): boolean {
  const left = Buffer.from(a);
  const right = Buffer.from(b);
  return left.length === right.length && timingSafeEqual(left, right);
}

/** Uniformly random numeric code, zero-padded (e.g. "004219"). */
export function randomNumericCode(length: number): string {
  return randomInt(0, 10 ** length)
    .toString()
    .padStart(length, '0');
}

/** URL-safe opaque token (refresh tokens). 48 bytes → 64 chars. */
export function randomToken(bytes = 48): string {
  return randomBytes(bytes).toString('base64url');
}
