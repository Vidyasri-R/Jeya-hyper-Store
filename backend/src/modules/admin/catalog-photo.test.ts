import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import { catalogPhoto, oneImageAtATime } from './admin-products.service';

describe('catalogue photo cleanup', () => {
  it('light-box photo → white square with the product centred and filling it', async () => {
    // 1000×1300 off-white backdrop with gentle falloff, a red "product" near the bottom-right.
    const backdrop = Buffer.from(
      '<svg width="1000" height="1300" xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="g"><stop offset="0" stop-color="#F3F1ED"/><stop offset="1" stop-color="#DDD8D0"/></radialGradient></defs><rect width="1000" height="1300" fill="url(#g)"/><rect x="600" y="800" width="250" height="350" fill="#C62828"/></svg>',
    );
    const out = await catalogPhoto(await sharp(backdrop).jpeg({ quality: 85 }).toBuffer());
    const { data, info } = await sharp(out).raw().toBuffer({ resolveWithObject: true });
    expect([info.width, info.height]).toEqual([800, 800]);
    const px = (x: number, y: number): number[] => [...data.subarray((y * info.width + x) * info.channels, (y * info.width + x) * info.channels + 3)];
    for (const [x, y] of [[5, 5], [795, 5], [5, 795], [795, 795]] as const) expect(px(x, y)).toEqual([255, 255, 255]);
    const [r = 0, g = 255, b = 255] = px(400, 400);
    expect(r).toBeGreaterThan(170);
    expect(g).toBeLessThan(80);
    expect(b).toBeLessThan(80);
    // product scaled up to ~88% of the square's height
    expect(px(400, 60)[1] ?? 255).toBeLessThan(80);
  });

  it('clean-up off: the picture stays as it is (background, shape), only resized', async () => {
    const photo = Buffer.from(
      '<svg width="1600" height="1000" xmlns="http://www.w3.org/2000/svg"><rect width="1600" height="1000" fill="#E8E2D8"/><rect x="600" y="300" width="400" height="400" fill="#C62828"/></svg>',
    );
    const out = await catalogPhoto(await sharp(photo).png().toBuffer(), { clean: false });
    const { data, info } = await sharp(out).raw().toBuffer({ resolveWithObject: true });
    expect([info.width, info.height]).toEqual([800, 500]);
    const [r = 0, g = 0, b = 0] = [...data.subarray(0, 3)];
    // the light backdrop is kept, not turned white
    expect(r).toBeLessThan(245);
    expect(Math.abs(r - 0xe8)).toBeLessThan(8);
    expect(Math.abs(g - 0xe2)).toBeLessThan(8);
    expect(Math.abs(b - 0xd8)).toBeLessThan(8);
  });

  it('processes one picture at a time; a bad picture does not block the next', async () => {
    let running = 0;
    let most = 0;
    const work = (fail: boolean) => () =>
      new Promise<string>((resolve, reject) => {
        running++;
        most = Math.max(most, running);
        setTimeout(() => {
          running--;
          if (fail) reject(new Error('bad picture'));
          else resolve('ok');
        }, 5);
      });
    const results = await Promise.allSettled([oneImageAtATime(work(false)), oneImageAtATime(work(true)), oneImageAtATime(work(false))]);
    expect(most).toBe(1);
    expect(results.map((r) => r.status)).toEqual(['fulfilled', 'rejected', 'fulfilled']);
  });

  it('rejects files that are not images', async () => {
    await expect(catalogPhoto(Buffer.from('not an image'))).rejects.toThrow();
  });
});
