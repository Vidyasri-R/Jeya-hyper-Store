// Render the Trichy delivery-area map to raster tiles for Cloudflare R2 (free, no map API, no key).
//
//   pmtiles extract https://build.protomaps.com/<YYYYMMDD>.pmtiles out/trichy.pmtiles --bbox=78.50,10.68,78.80,10.95 --maxzoom=15
//   node render_tiles.mjs            # → out/tiles/{z}/{x}/{y}.webp (512 px, for 256 px map cells)
//   node upload_tiles.mjs            # → R2 bucket, maps/trichy/<version>/
//
// Map data © OpenStreetMap contributors (ODbL), vector tiles and style by Protomaps (BSD/CC0).
// Tiles are drawn in 4 × 4 blocks with a one-tile margin so street names aren't cut at tile edges.
import { mkdirSync, readFileSync, writeFileSync, existsSync, openSync, readSync, fstatSync } from 'node:fs';
import { createRequire } from 'node:module';
import mbgl from '@maplibre/maplibre-gl-native';
import { layers, namedFlavor } from '@protomaps/basemaps';
import { PMTiles } from 'pmtiles';

const require = createRequire(new URL('../../backend/package.json', import.meta.url));
const sharp = require('sharp');

export const BBOX = [78.5, 10.68, 78.8, 10.95]; // west, south, east, north
export const ZOOMS = [11, 12, 13, 14, 15, 16];
const META = 4; // tiles per block side
const RATIO = 2; // 512 px images for 256 px cells
const ASSETS = 'https://protomaps.github.io/basemaps-assets';

// PMTiles over the local file
const fd = openSync('out/trichy.pmtiles', 'r');
const size = fstatSync(fd).size;
const archive = new PMTiles({
  getKey: () => 'trichy',
  getBytes: async (offset, length) => {
    const buf = Buffer.alloc(Math.min(length, size - offset));
    readSync(fd, buf, 0, buf.length, offset);
    return { data: buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.length) };
  },
});

// fonts and sprites from Protomaps' assets, cached on disk
mkdirSync('out/cache', { recursive: true });
async function cachedFetch(url) {
  const file = `out/cache/${Buffer.from(url).toString('base64url')}`;
  if (existsSync(file)) return readFileSync(file);
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} ${url}`);
  const data = Buffer.from(await res.arrayBuffer());
  writeFileSync(file, data);
  return data;
}

const style = {
  version: 8,
  glyphs: `${ASSETS}/fonts/{fontstack}/{range}.pbf`,
  sprite: `${ASSETS}/sprites/v4/light`,
  sources: { protomaps: { type: 'vector', tiles: ['pmt://{z}/{x}/{y}'], minzoom: 0, maxzoom: 15 } },
  layers: layers('protomaps', namedFlavor('light'), { lang: 'en' }),
};

const map = new mbgl.Map({
  ratio: RATIO,
  request: (req, callback) => {
    (async () => {
      if (req.url.startsWith('pmt://')) {
        const [z, x, y] = req.url.slice(6).split('/').map(Number);
        const tile = await archive.getZxy(z, x, y);
        return tile ? { data: Buffer.from(tile.data) } : {};
      }
      return { data: await cachedFetch(req.url) };
    })().then((r) => callback(null, r), (e) => callback(e));
  },
});
map.load(style);

const lon2x = (lon, z) => ((lon + 180) / 360) * 2 ** z;
const lat2y = (lat, z) => ((1 - Math.log(Math.tan((lat * Math.PI) / 180) + 1 / Math.cos((lat * Math.PI) / 180)) / Math.PI) / 2) * 2 ** z;
const x2lon = (x, z) => (x / 2 ** z) * 360 - 180;
const y2lat = (y, z) => (Math.atan(Math.sinh(Math.PI * (1 - (2 * y) / 2 ** z))) * 180) / Math.PI;

const render = (opts) => new Promise((resolve, reject) => map.render(opts, (err, buf) => (err ? reject(err) : resolve(buf))));

let written = 0;
for (const z of ZOOMS) {
  const x0 = Math.floor(lon2x(BBOX[0], z)), x1 = Math.floor(lon2x(BBOX[2], z));
  const y0 = Math.floor(lat2y(BBOX[3], z)), y1 = Math.floor(lat2y(BBOX[1], z));
  for (let bx = x0; bx <= x1; bx += META) {
    for (let by = y0; by <= y1; by += META) {
      // block of META × META tiles plus a one-tile margin all round
      const span = META + 2;
      const cx = bx - 1 + span / 2, cy = by - 1 + span / 2;
      const px = span * 256;
      // MapLibre's zoom counts 512 px tiles: a 256 px tile at z is zoom z - 1
      const raw = await render({ zoom: z - 1, center: [x2lon(cx, z), y2lat(cy, z)], width: px, height: px });
      const img = sharp(raw, { raw: { width: px * RATIO, height: px * RATIO, channels: 4 } });
      const full = await img.png().toBuffer();
      for (let i = 0; i < META; i++) {
        for (let j = 0; j < META; j++) {
          const x = bx + i, y = by + j;
          if (x > x1 || y > y1) continue;
          const left = (1 + i) * 256 * RATIO, top = (1 + j) * 256 * RATIO;
          mkdirSync(`out/tiles/${z}/${x}`, { recursive: true });
          await sharp(full).extract({ left, top, width: 256 * RATIO, height: 256 * RATIO }).webp({ quality: 82, effort: 5 }).toFile(`out/tiles/${z}/${x}/${y}.webp`);
          written++;
        }
      }
    }
  }
  console.log(`z${z}: x ${x0}–${x1}, y ${y0}–${y1} · ${written} tiles so far`);
}
map.release();
console.log('done', written, 'tiles');
