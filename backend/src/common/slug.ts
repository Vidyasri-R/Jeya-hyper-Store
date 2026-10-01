/**
 * URL-safe slug: lowercase ASCII words joined by '-'. Non-Latin text (Tamil) is
 * dropped, so callers append a stable id suffix to keep slugs unique and non-empty.
 */
export function slugify(input: string, maxLength = 80): string {
  const slug = input
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug.slice(0, maxLength).replace(/-+$/g, '');
}

/** "Ponni Raw Rice 1kg" + "GF10234" → "ponni-raw-rice-1kg-gf10234". Stable across syncs. */
export function slugWithId(name: string, id: string): string {
  const base = slugify(name);
  const suffix = slugify(id, 40) || 'item';
  return base ? `${base}-${suffix}` : suffix;
}
