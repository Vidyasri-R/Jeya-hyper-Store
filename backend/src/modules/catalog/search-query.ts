const MAX_TOKENS = 6;

export type ParsedSearch = {
  /** Lower-cased, whitespace-normalised query for trigram matching. */
  text: string;
  /** Prefix tsquery, e.g. "pon:* & rice:*"; null if the query had no searchable tokens. */
  tsquery: string | null;
  /** Raw-ish token for exact barcode / item-code lookups (scanner input). */
  code: string | null;
};

/**
 * Turns user input into safe search inputs. Tokens are restricted to Unicode
 * letters/digits (Tamil included), so nothing reaches to_tsquery that could be
 * parsed as tsquery syntax (&, |, !, :, quotes…).
 */
export function parseSearch(input: string): ParsedSearch {
  const text = input.normalize('NFC').toLowerCase().replace(/\s+/g, ' ').trim().slice(0, 100);
  const tokens = (text.match(/[\p{L}\p{M}\p{N}]+/gu) ?? []).slice(0, MAX_TOKENS);
  // Scanner input / item codes: a single token containing at least one digit.
  const raw = input.trim();
  return {
    text,
    tsquery: tokens.length > 0 ? tokens.map((token) => `${token}:*`).join(' & ') : null,
    code: /^[A-Za-z0-9-]{4,64}$/.test(raw) && /[0-9]/.test(raw) ? raw.toUpperCase() : null,
  };
}
