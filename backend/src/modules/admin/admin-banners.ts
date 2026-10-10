import { createHash } from 'node:crypto';
import { z } from 'zod';
import { AppError } from '../../common/errors';
import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { r2 } from '../../infra/r2';
import { loadSharp, oneImageAtATime } from './admin-products.service';

/**
 * Home-screen banners the store manages from the admin app (public config `home.banners`).
 * Shown in order after any festival banners; an empty list = the app's built-in banners.
 */
export const MAX_BANNERS = 8;

/** Banner images are 2:1 (the app's carousel), stored on R2 under banners/. */
const BANNER_W = 1200;
const BANNER_H = 600;
const MAX_INPUT_PIXELS = 40_000_000;

const text = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .nullable()
    .transform((v) => (v === '' ? null : v));

const imageUrl = z
  .string()
  .url()
  .refine((url) => {
    const base = env.R2_PUBLIC_BASE_URL;
    return base ? url.startsWith(`${base}/banners/`) : new URL(url).pathname.startsWith('/banners/');
  }, 'Upload the banner image from the admin app')
  .nullable();

const link = z.discriminatedUnion('type', [
  z.object({ type: z.literal('none') }).strict(),
  z.object({ type: z.literal('search'), value: z.string().trim().min(1).max(60) }).strict(),
  z.object({ type: z.literal('category'), value: z.string().trim().regex(/^[a-z0-9-]{1,80}$/, 'Pick a category') }).strict(),
  z.object({ type: z.literal('product'), value: z.string().trim().regex(/^[a-z0-9-]{1,120}$/, 'Pick a product') }).strict(),
]);

export const bannerSchema = z
  .object({
    id: z.string().regex(/^[A-Za-z0-9_-]{6,40}$/),
    active: z.boolean(),
    image: imageUrl,
    tag: text(24),
    title: text(60),
    subtitle: text(90),
    cta: text(20),
    /** Card colour behind the text (null = the brand's soft colour). */
    background: z.string().trim().regex(/^#[0-9a-fA-F]{6}$/).transform((v) => v.toUpperCase()).nullable(),
    link,
    startsAt: z.iso.datetime({ offset: true }).nullable(),
    endsAt: z.iso.datetime({ offset: true }).nullable(),
  })
  .strict()
  .refine((b) => b.image !== null || b.title !== null, { message: 'Add an image or a title', path: ['title'] })
  .refine((b) => !b.startsAt || !b.endsAt || new Date(b.endsAt) > new Date(b.startsAt), { message: 'End must be after start', path: ['endsAt'] });

export const bannersSchema = z
  .array(bannerSchema)
  .max(MAX_BANNERS, `At most ${MAX_BANNERS} banners`)
  .refine((list) => new Set(list.map((b) => b.id)).size === list.length, 'Duplicate banner id');

export type Banner = z.infer<typeof bannerSchema>;

export const adminBannersService = {
  /** Crop to 2:1, compress to WebP, store on R2; returns the URL to put in a banner. */
  async uploadImage(input: Buffer) {
    if (!r2.isConfigured()) throw new AppError('UPSTREAM_UNAVAILABLE', 'Image storage is not configured');
    const sharp = await loadSharp();
    let output: Buffer;
    try {
      output = await oneImageAtATime(() =>
        sharp(input, { limitInputPixels: MAX_INPUT_PIXELS, failOn: 'error' })
          .rotate()
          .resize(BANNER_W, BANNER_H, { fit: 'cover', position: 'attention' })
          .flatten({ background: '#ffffff' })
          .webp({ quality: 82, effort: 4 })
          .toBuffer(),
      );
    } catch (error) {
      logger.warn({ err: error }, 'banner image could not be processed');
      throw new AppError('BAD_REQUEST', 'This file is not a supported image (use JPG, PNG or WebP)', { reason: 'image_invalid' });
    }
    const hash = createHash('sha1').update(output).digest('hex').slice(0, 16);
    const stored = await r2.put(`banners/${hash}.webp`, output, { contentType: 'image/webp' });
    logger.info({ bytesIn: input.length, bytesOut: output.length }, 'banner image uploaded');
    return { imageUrl: stored.url, width: BANNER_W, height: BANNER_H };
  },

  /** After a save: delete images of banners that were removed or got a new picture. */
  async removeUnusedImages(previous: unknown, next: Banner[]) {
    const keep = new Set(next.map((b) => b.image).filter(Boolean));
    const old = Array.isArray(previous) ? previous.map((b) => (b as { image?: unknown }).image).filter((u): u is string => typeof u === 'string') : [];
    for (const url of old) {
      if (keep.has(url)) continue;
      const key = r2.keyFromUrl(url);
      if (key?.startsWith('banners/')) await r2.remove(key).catch((error: unknown) => logger.warn({ err: error, key }, 'old banner image not deleted'));
    }
  },
};
