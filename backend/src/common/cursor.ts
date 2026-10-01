import { AppError } from './errors';

/**
 * Opaque keyset-pagination cursor: the sort value + id of the last row on the page.
 * Keyset (not OFFSET) keeps deep scrolling through 30k products O(page size).
 */
export type Cursor = { v: string | number; id: number };

export function encodeCursor(cursor: Cursor): string {
  return Buffer.from(JSON.stringify(cursor)).toString('base64url');
}

export function decodeCursor(raw: string): Cursor {
  try {
    const parsed: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (
      typeof parsed === 'object' &&
      parsed !== null &&
      'v' in parsed &&
      'id' in parsed &&
      (typeof parsed.v === 'string' || typeof parsed.v === 'number') &&
      typeof parsed.id === 'number' &&
      Number.isSafeInteger(parsed.id)
    ) {
      return { v: parsed.v, id: parsed.id };
    }
  } catch {
    // fall through
  }
  throw new AppError('BAD_REQUEST', 'Invalid pagination cursor', { reason: 'cursor_invalid' });
}
