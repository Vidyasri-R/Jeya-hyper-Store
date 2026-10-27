import { z } from 'zod';

/**
 * Shop TV ad breaks. The plan for a day is worked out from a seed (the date + settings + the ads on
 * the list), so the TV and the shop phone asking separately get exactly the same break times and
 * ads — the phone plays the sound in time with the TV's picture without talking to it.
 */

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use HH:MM, e.g. 08:00');

export const shopTvSettingsSchema = z
  .object({
    /** A break every min–max minutes (random within). */
    breakEveryMinutes: z.object({ min: z.number().int().min(1).max(180), max: z.number().int().min(1).max(180) }).refine((r) => r.max >= r.min, 'Max must be ≥ min'),
    /** 1–2 items per break (random within). */
    itemsPerBreak: z.object({ min: z.number().int().min(1).max(6), max: z.number().int().min(1).max(6) }).refine((r) => r.max >= r.min, 'Max must be ≥ min'),
    /** Breaks only while the shop is open (India time). */
    openTime: hhmm,
    closeTime: hhmm,
    /** How long a poster stays on screen. */
    imageSeconds: z.number().int().min(3).max(120),
    /** Where the ad sound plays: the shop phone's speakers, the TV, or both. */
    adSound: z.enum(['phone', 'tv', 'both']),
    tvVolume: z.number().int().min(0).max(100),
    phoneVolume: z.number().int().min(0).max(100),
    cctv: z.object({
      /** composite = the recorder's one combined grid stream; pages = the TV builds the grid. */
      mode: z.enum(['composite', 'pages']),
      channelCount: z.number().int().min(1).max(64),
      /** Cameras to show, in order (empty = all channels). */
      cameras: z.array(z.number().int().min(1).max(64)).max(64),
      pageSize: z.union([z.literal(1), z.literal(4), z.literal(6), z.literal(9)]),
      pageSeconds: z.number().int().min(5).max(300),
    }),
    /** Side panel next to 9:16 Reels. */
    panel: z.object({
      headline: z.string().trim().max(60),
      offer: z.string().trim().max(120),
      qrUrl: z.url().max(300),
    }),
  })
  .strict();

export type ShopTvSettings = z.infer<typeof shopTvSettingsSchema>;

export const DEFAULT_SHOP_TV_SETTINGS: ShopTvSettings = {
  breakEveryMinutes: { min: 3, max: 7 },
  itemsPerBreak: { min: 1, max: 2 },
  openTime: '08:00',
  closeTime: '22:00',
  imageSeconds: 10,
  adSound: 'phone',
  tvVolume: 80,
  phoneVolume: 100,
  cctv: { mode: 'pages', channelCount: 36, cameras: [], pageSize: 9, pageSeconds: 15 },
  panel: { headline: 'Order on the Jeya Hyper Store app', offer: 'Free delivery above ₹999', qrUrl: 'https://jeyahyperstore.in' },
};

export type PlanItem = { id: string; mediaType: 'video' | 'image' | 'audio'; durationMs: number | null };

export type PlannedBreak = {
  /** Same on every device: "2026-10-28#12". */
  id: string;
  /** Start, ms since epoch. */
  at: number;
  /** Items in play order, each with when it starts (ms after [at]) and how long it runs. */
  items: { id: string; offsetMs: number; durationMs: number }[];
  durationMs: number;
};

/** Unknown video/audio length until the TV has measured it. */
const FALLBACK_MS = 30_000;
/** Pause between two items in a break. */
const BETWEEN_MS = 1_000;

/** Deterministic 32-bit PRNG (mulberry32) seeded by a string hash (xmur3). */
function rng(seedText: string): () => number {
  let h = 1779033703 ^ seedText.length;
  for (let i = 0; i < seedText.length; i++) {
    h = Math.imul(h ^ seedText.charCodeAt(i), 3432918353);
    h = (h << 13) | (h >>> 19);
  }
  let a = (h ^ (h >>> 16)) >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const between = (random: () => number, min: number, max: number) => min + Math.floor(random() * (max - min + 1));

/** "2026-10-28" + "08:00" India time → ms since epoch. */
export const istTime = (day: string, time: string) => Date.parse(`${day}T${time}:00+05:30`);

/** Today's date in India. */
export const istDay = (now = Date.now()) => new Date(now + 5.5 * 3600_000).toISOString().slice(0, 10);

export function itemDuration(item: PlanItem, settings: ShopTvSettings): number {
  if (item.mediaType === 'image') return settings.imageSeconds * 1000;
  return item.durationMs && item.durationMs > 0 ? item.durationMs : FALLBACK_MS;
}

/** Every break of [day], from opening to closing time. */
export function dayPlan(day: string, settings: ShopTvSettings, items: PlanItem[]): PlannedBreak[] {
  if (items.length === 0) return [];
  const sorted = [...items].sort((a, b) => a.id.localeCompare(b.id));
  const random = rng(`${day}|${JSON.stringify(settings)}|${sorted.map((i) => `${i.id}:${i.durationMs ?? ''}`).join(',')}`);
  const open = istTime(day, settings.openTime);
  let close = istTime(day, settings.closeTime);
  if (close <= open) close += 86_400_000; // open past midnight

  // Shuffled rounds: every ad plays once before any repeats, never twice in a row.
  let deck: PlanItem[] = [];
  let last: string | null = null;
  const draw = (): PlanItem => {
    if (deck.length === 0) {
      deck = [...sorted];
      for (let i = deck.length - 1; i > 0; i--) {
        const j = Math.floor(random() * (i + 1));
        [deck[i], deck[j]] = [deck[j]!, deck[i]!];
      }
      if (deck.length > 1 && deck[0]!.id === last) deck.push(deck.shift()!);
    }
    const next = deck.shift()!;
    last = next.id;
    return next;
  };

  const breaks: PlannedBreak[] = [];
  const gap = () => between(random, settings.breakEveryMinutes.min * 60, settings.breakEveryMinutes.max * 60) * 1000;
  let at = open + gap();
  for (let n = 1; at < close && n <= 2000; n++) {
    const count = Math.min(between(random, settings.itemsPerBreak.min, settings.itemsPerBreak.max), sorted.length);
    const chosen: PlannedBreak['items'] = [];
    let offset = 0;
    for (let k = 0; k < count; k++) {
      const item = draw();
      const length = itemDuration(item, settings);
      chosen.push({ id: item.id, offsetMs: offset, durationMs: length });
      offset += length + BETWEEN_MS;
    }
    const length = offset - BETWEEN_MS;
    if (at + length > close) break;
    breaks.push({ id: `${day}#${n}`, at, items: chosen, durationMs: length });
    at += length + gap();
  }
  return breaks;
}

/** Breaks from 2 minutes ago to [aheadMinutes] ahead (today; and tomorrow's first breaks near midnight). */
export function upcomingBreaks(now: number, settings: ShopTvSettings, itemsFor: (day: string) => PlanItem[], aheadMinutes = 90): PlannedBreak[] {
  const from = now - 2 * 60_000;
  const to = now + aheadMinutes * 60_000;
  const days = [istDay(now - 86_400_000), istDay(now), istDay(to)];
  const seen = new Set<string>();
  const out: PlannedBreak[] = [];
  for (const day of days) {
    if (seen.has(day)) continue;
    seen.add(day);
    for (const b of dayPlan(day, settings, itemsFor(day))) if (b.at + b.durationMs >= from && b.at <= to) out.push(b);
  }
  return out.sort((a, b) => a.at - b.at);
}
