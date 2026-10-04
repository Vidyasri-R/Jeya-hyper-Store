// Frame raw simulator screenshots into store images: headline on brand green + rounded screen.
//   node frame.mjs <raw-dir> <out-dir>
// App Store 6.5" = 1284 × 2778, Google Play phone = 1080 × 1920 (Play allows at most 2:1).
import { readdirSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(new URL('../../backend/package.json', import.meta.url));
const sharp = require('sharp');

const [rawDir, outDir] = process.argv.slice(2);
const captions = {
  '01-home': ['Your neighbourhood', 'supermarket, now on your phone'],
  '02-categories': ['Groceries & daily needs,', 'neatly sorted'],
  '03-cart': ['See the delivery charge', 'before you pay'],
  '04-checkout': ['Pay by UPI, card', 'or cash on delivery'],
  '05-address-map': ['Pin your door,', 'our staff find you'],
};
const sizes = { 'appstore-6.5': [1284, 2778], 'play-phone': [1080, 1920] };
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');

for (const [label, [W, H]] of Object.entries(sizes)) {
  mkdirSync(`${outDir}/${label}`, { recursive: true });
  for (const file of readdirSync(rawDir).filter((f) => f.endsWith('.png')).sort()) {
    const id = file.replace('.png', '');
    const lines = captions[id];
    if (!lines) continue;
    const longest = Math.max(...lines.map((l) => l.length));
    const font = Math.round(Math.min(W * 0.068, (W * 0.88) / (longest * 0.56)));
    const top = Math.round(H * 0.06);
    const textH = top + font * 2.6;
    const shotH = Math.round(H - textH - H * 0.03);
    const shotW = Math.round(shotH * (1320 / 2868));
    const radius = Math.round(shotW * 0.09);
    const shot = await sharp(`${rawDir}/${file}`).resize(shotW, shotH).composite([{
      input: Buffer.from(`<svg width="${shotW}" height="${shotH}"><rect width="${shotW}" height="${shotH}" rx="${radius}" ry="${radius}"/></svg>`),
      blend: 'dest-in',
    }]).png().toBuffer();
    const bg = Buffer.from(`<svg width="${W}" height="${H}" xmlns="http://www.w3.org/2000/svg">
      <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0E7A3B"/><stop offset="1" stop-color="#064D25"/></linearGradient></defs>
      <rect width="${W}" height="${H}" fill="url(#g)"/>
      <rect x="${(W - shotW) / 2 - 10}" y="${textH - 10}" width="${shotW + 20}" height="${shotH + 20}" rx="${radius + 10}" fill="#ffffff" fill-opacity="0.18"/>
      ${lines.map((l, i) => `<text x="${W / 2}" y="${top + font * (i + 1)}" text-anchor="middle" font-family="Helvetica Neue, Helvetica, Arial" font-weight="700" font-size="${font}" fill="#ffffff">${esc(l)}</text>`).join('')}
    </svg>`);
    await sharp(bg).composite([{ input: shot, left: Math.round((W - shotW) / 2), top: Math.round(textH) }]).png().toFile(`${outDir}/${label}/${id}.png`);
  }
}
console.log('done');
