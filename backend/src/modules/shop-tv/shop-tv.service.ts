import { randomInt, randomUUID } from 'node:crypto';
import type { Readable } from 'node:stream';
import { and, asc, eq, isNotNull, isNull, lt, or, sql } from 'drizzle-orm';
import { sha256Hex } from '../../common/crypto';
import { AppError } from '../../common/errors';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { shopMedia, shopScreens } from '../../db/schema';
import { r2 } from '../../infra/r2';
import { appConfigService } from '../app-config/app-config.service';
import { DEFAULT_SHOP_TV_SETTINGS, istDay, shopTvSettingsSchema, upcomingBreaks, type PlanItem, type ShopTvSettings } from './plan';

/**
 * Shop TV: the Jeya TV app shows live CCTV and plays ad breaks; the shop phone (store app → Shop
 * audio) pauses the owner's music and plays the ad sound at the same moments. Both read the same
 * plan (plan.ts). TVs sign in with a device key and are paired once with a 6-digit code.
 */

export const SHOP_TV_KEY = 'shoptv.settings';
const PAIR_CODE_MINUTES = 30;

/** What may be uploaded, and how big. */
export const SHOP_MEDIA_TYPES: Record<string, { mediaType: 'video' | 'image' | 'audio'; ext: string; maxBytes: number }> = {
  'video/mp4': { mediaType: 'video', ext: 'mp4', maxBytes: 200 * 1024 * 1024 },
  'video/quicktime': { mediaType: 'video', ext: 'mov', maxBytes: 200 * 1024 * 1024 },
  'video/webm': { mediaType: 'video', ext: 'webm', maxBytes: 200 * 1024 * 1024 },
  'image/jpeg': { mediaType: 'image', ext: 'jpg', maxBytes: 15 * 1024 * 1024 },
  'image/png': { mediaType: 'image', ext: 'png', maxBytes: 15 * 1024 * 1024 },
  'image/webp': { mediaType: 'image', ext: 'webp', maxBytes: 15 * 1024 * 1024 },
  'audio/mpeg': { mediaType: 'audio', ext: 'mp3', maxBytes: 40 * 1024 * 1024 },
  'audio/mp4': { mediaType: 'audio', ext: 'm4a', maxBytes: 40 * 1024 * 1024 },
  'audio/x-m4a': { mediaType: 'audio', ext: 'm4a', maxBytes: 40 * 1024 * 1024 },
  'audio/aac': { mediaType: 'audio', ext: 'aac', maxBytes: 40 * 1024 * 1024 },
  'audio/wav': { mediaType: 'audio', ext: 'wav', maxBytes: 40 * 1024 * 1024 },
  'audio/x-wav': { mediaType: 'audio', ext: 'wav', maxBytes: 40 * 1024 * 1024 },
  'audio/ogg': { mediaType: 'audio', ext: 'ogg', maxBytes: 40 * 1024 * 1024 },
};

export async function shopTvSettings(): Promise<ShopTvSettings> {
  const raw = await appConfigService.getRaw(SHOP_TV_KEY);
  const parsed = shopTvSettingsSchema.safeParse(raw && typeof raw === 'object' ? { ...DEFAULT_SHOP_TV_SETTINGS, ...raw } : DEFAULT_SHOP_TV_SETTINGS);
  return parsed.success ? parsed.data : DEFAULT_SHOP_TV_SETTINGS;
}

type MediaRow = typeof shopMedia.$inferSelect;

function publicMedia(m: MediaRow) {
  return {
    id: m.id,
    kind: m.kind,
    mediaType: m.mediaType,
    title: m.title,
    url: m.url,
    contentType: m.contentType,
    bytes: m.bytes,
    durationMs: m.durationMs,
    aspect: m.aspect === null ? null : Number(m.aspect),
    isActive: m.isActive,
    startsOn: m.startsOn,
    endsOn: m.endsOn,
    sortOrder: m.sortOrder,
    createdAt: m.createdAt,
  };
}

const onAir = (m: MediaRow, day: string) => m.isActive && (!m.startsOn || m.startsOn <= day) && (!m.endsOn || m.endsOn >= day);

/** The plan + the files it needs: what both the TV and the shop phone read. */
async function playlist(now = Date.now()) {
  const [settings, media] = await Promise.all([
    shopTvSettings(),
    db.select().from(shopMedia).where(eq(shopMedia.isActive, true)).orderBy(asc(shopMedia.sortOrder), asc(shopMedia.createdAt)),
  ]);
  const itemsFor = (day: string): PlanItem[] =>
    media.filter((m) => onAir(m, day)).map((m) => ({ id: m.id, mediaType: m.mediaType as PlanItem['mediaType'], durationMs: m.durationMs }));
  const breaks = upcomingBreaks(now, settings, itemsFor);
  // Files: today's and tomorrow's ads, so the TV has them before they're needed.
  const today = istDay(now);
  const tomorrow = istDay(now + 86_400_000);
  const files = media.filter((m) => onAir(m, today) || onAir(m, tomorrow)).map(publicMedia);
  return { serverNow: now, settings, media: files, breaks };
}

export const shopTvService = {
  /* ── the TV ── */

  /** First start (or after "Remove"): the TV gets a code to show until an admin pairs it. */
  async register(deviceKey: string) {
    const hash = sha256Hex(deviceKey);
    const [existing] = await db.select().from(shopScreens).where(eq(shopScreens.deviceKeyHash, hash)).limit(1);
    if (existing?.pairedAt) return { paired: true as const, name: existing.name };
    const code = await freshCode();
    const expiresAt = new Date(Date.now() + PAIR_CODE_MINUTES * 60_000);
    if (existing) {
      await db.update(shopScreens).set({ pairCode: code, pairCodeExpiresAt: expiresAt }).where(eq(shopScreens.id, existing.id));
    } else {
      await db.insert(shopScreens).values({ deviceKeyHash: hash, pairCode: code, pairCodeExpiresAt: expiresAt });
    }
    // Leftovers: codes nobody typed in for a day.
    await db.delete(shopScreens).where(and(isNull(shopScreens.pairedAt), lt(shopScreens.createdAt, sql`now() - interval '1 day'`)));
    return { paired: false as const, code, expiresAt };
  },

  /** Everything the TV needs; `paired: false` (with a fresh code) until an admin pairs it. */
  async state(deviceKey: string) {
    const screen = await screenFor(deviceKey);
    if (!screen) throw new AppError('UNAUTHORIZED', 'Unknown TV', { reason: 'tv_unknown' });
    if (!screen.pairedAt) {
      if (!screen.pairCode || !screen.pairCodeExpiresAt || screen.pairCodeExpiresAt < new Date()) return shopTvService.register(deviceKey);
      return { paired: false as const, code: screen.pairCode, expiresAt: screen.pairCodeExpiresAt };
    }
    await db.update(shopScreens).set({ lastSeenAt: new Date() }).where(eq(shopScreens.id, screen.id));
    return { paired: true as const, name: screen.name, ...(await playlist()) };
  },

  async heartbeat(deviceKey: string, status: Record<string, unknown>, appVersion: string | undefined) {
    const screen = await screenFor(deviceKey);
    if (!screen?.pairedAt) throw new AppError('UNAUTHORIZED', 'Unknown TV', { reason: 'tv_unknown' });
    await db.update(shopScreens).set({ lastSeenAt: new Date(), status, ...(appVersion ? { appVersion } : {}) }).where(eq(shopScreens.id, screen.id));
  },

  /** The TV measured a file it downloaded (the server can't read video). */
  async reportMedia(deviceKey: string, id: string, info: { durationMs: number; aspect: number | null }) {
    const screen = await screenFor(deviceKey);
    if (!screen?.pairedAt) throw new AppError('UNAUTHORIZED', 'Unknown TV', { reason: 'tv_unknown' });
    await db
      .update(shopMedia)
      .set({ durationMs: info.durationMs, ...(info.aspect ? { aspect: info.aspect.toFixed(3) } : {}) })
      .where(and(eq(shopMedia.id, id), or(isNull(shopMedia.durationMs), sql`abs(${shopMedia.durationMs} - ${info.durationMs}) > 1000`)));
  },

  /* ── the shop phone (store app → Shop audio) ── */

  async audioState() {
    return playlist();
  },

  /* ── admin ── */

  async overview() {
    const [settings, media, screens] = await Promise.all([
      shopTvSettings(),
      db.select().from(shopMedia).orderBy(asc(shopMedia.sortOrder), asc(shopMedia.createdAt)),
      db.select().from(shopScreens).where(isNotNull(shopScreens.pairedAt)).orderBy(asc(shopScreens.pairedAt)),
    ]);
    const { breaks } = await playlist();
    return {
      settings,
      media: media.map(publicMedia),
      screens: screens.map((s) => ({
        id: s.id,
        name: s.name,
        pairedAt: s.pairedAt,
        lastSeenAt: s.lastSeenAt,
        online: s.lastSeenAt !== null && Date.now() - s.lastSeenAt.getTime() < 3 * 60_000,
        status: s.status,
        appVersion: s.appVersion,
      })),
      nextBreak: breaks.find((b) => b.at > Date.now()) ?? null,
    };
  },

  async setSettings(value: unknown) {
    const parsed = shopTvSettingsSchema.safeParse(value);
    if (!parsed.success) throw new AppError('VALIDATION_FAILED', parsed.error.issues[0]?.message ?? 'Invalid settings', parsed.error.issues);
    await appConfigService.set(SHOP_TV_KEY, parsed.data, { isPublic: false, description: 'Shop TV: ad break rules, CCTV layout, sound, Reel side panel.' });
    return parsed.data;
  },

  async pair(code: string, name: string) {
    const [screen] = await db
      .select()
      .from(shopScreens)
      .where(and(eq(shopScreens.pairCode, code), isNull(shopScreens.pairedAt)))
      .limit(1);
    if (!screen || !screen.pairCodeExpiresAt || screen.pairCodeExpiresAt < new Date()) {
      throw new AppError('NOT_FOUND', 'That code isn’t showing on any TV. Check the TV screen and try again.', { reason: 'pair_code_unknown' });
    }
    await db.update(shopScreens).set({ pairedAt: new Date(), name, pairCode: null, pairCodeExpiresAt: null }).where(eq(shopScreens.id, screen.id));
    logger.info({ screen: screen.id, name }, 'shop TV paired');
    return { id: screen.id, name };
  },

  async renameScreen(id: string, name: string) {
    const rows = await db.update(shopScreens).set({ name }).where(eq(shopScreens.id, id)).returning({ id: shopScreens.id });
    if (rows.length === 0) throw AppError.notFound('TV');
  },

  /** The TV goes back to showing a pairing code. */
  async removeScreen(id: string) {
    await db.delete(shopScreens).where(eq(shopScreens.id, id));
  },

  async upload(input: { body: Readable; contentType: string; declaredBytes: number | null; kind: 'ad' | 'announcement'; title: string; staffId: string }) {
    const type = SHOP_MEDIA_TYPES[input.contentType];
    if (!type) throw new AppError('BAD_REQUEST', 'Use an MP4 video, a JPG/PNG/WebP poster or an MP3/M4A sound.', { reason: 'media_type' });
    if (input.declaredBytes !== null && input.declaredBytes > type.maxBytes) {
      throw new AppError('BAD_REQUEST', `Too big — the limit is ${Math.round(type.maxBytes / 1024 / 1024)} MB.`, { reason: 'media_too_large' });
    }
    const id = randomUUID();
    let stored: { url: string; bytes: number };
    try {
      stored = await r2.putStream(`shoptv/${id}.${type.ext}`, input.body, { contentType: input.contentType, maxBytes: type.maxBytes });
    } catch (error) {
      if ((error as Error).message === 'too_large') throw new AppError('BAD_REQUEST', `Too big — the limit is ${Math.round(type.maxBytes / 1024 / 1024)} MB.`, { reason: 'media_too_large' });
      throw error;
    }
    const [{ next } = { next: 0 }] = await db.select({ next: sql<number>`coalesce(max(${shopMedia.sortOrder}), 0) + 1` }).from(shopMedia);
    const [row] = await db
      .insert(shopMedia)
      .values({
        id,
        kind: type.mediaType === 'audio' ? 'announcement' : input.kind,
        mediaType: type.mediaType,
        title: input.title,
        url: stored.url,
        contentType: input.contentType,
        bytes: stored.bytes,
        sortOrder: Number(next),
        createdBy: input.staffId,
      })
      .returning();
    logger.info({ id, bytes: stored.bytes, type: input.contentType }, 'shop TV media uploaded');
    return publicMedia(row!);
  },

  async updateMedia(id: string, patch: { title?: string; isActive?: boolean; startsOn?: string | null; endsOn?: string | null; sortOrder?: number }) {
    const rows = await db.update(shopMedia).set({ ...patch, updatedAt: new Date() }).where(eq(shopMedia.id, id)).returning();
    if (rows.length === 0) throw AppError.notFound('Ad');
    return publicMedia(rows[0]!);
  },

  async deleteMedia(id: string) {
    const [row] = await db.delete(shopMedia).where(eq(shopMedia.id, id)).returning();
    if (!row) throw AppError.notFound('Ad');
    const key = r2.keyFromUrl(row.url);
    if (key) await r2.remove(key).catch((error: unknown) => logger.warn({ err: error, key }, 'shop TV file not removed'));
  },
};

async function screenFor(deviceKey: string) {
  const [screen] = await db.select().from(shopScreens).where(eq(shopScreens.deviceKeyHash, sha256Hex(deviceKey))).limit(1);
  return screen ?? null;
}

/** A 6-digit code no other TV is showing. */
async function freshCode(): Promise<string> {
  for (let i = 0; i < 20; i++) {
    const code = String(randomInt(100000, 1000000));
    const [taken] = await db.select({ id: shopScreens.id }).from(shopScreens).where(eq(shopScreens.pairCode, code)).limit(1);
    if (!taken) return code;
  }
  throw new AppError('INTERNAL', 'Could not make a pairing code');
}
