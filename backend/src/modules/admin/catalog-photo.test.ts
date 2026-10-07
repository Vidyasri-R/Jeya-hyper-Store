import sharp from 'sharp';
import { describe, expect, it } from 'vitest';
import { catalogPhoto } from './admin-products.service';

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

  it('rejects files that are not images', async () => {
    await expect(catalogPhoto(Buffer.from('not an image'))).rejects.toThrow();
  });
});
