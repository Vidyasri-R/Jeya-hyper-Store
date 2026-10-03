// Render out/*.svg → out/png/*.png (preview) and out/webp/*.webp (app assets) with sharp (librsvg).
// Usage: node render.mjs [name …]   (from this folder, after the python scripts wrote out/*.svg)
import { mkdirSync, readdirSync, readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
// sharp (with librsvg) comes from the backend's dependencies.
const require = createRequire(new URL('../../backend/package.json', import.meta.url));
const sharp = require('sharp');
const only = process.argv.slice(2);
mkdirSync('out/png', { recursive: true }); mkdirSync('out/webp', { recursive: true });
for (const file of readdirSync('out').filter((f) => f.endsWith('.svg'))) {
  const name = file.replace(/\.svg$/, '');
  if (only.length && !only.includes(name)) continue;
  const svg = readFileSync(`out/${file}`);
  await sharp(svg, { density: 72 }).png().toFile(`out/png/${name}.png`);
  const info = await sharp(svg, { density: 72 }).webp({ quality: 90, alphaQuality: 95, effort: 6, smartSubsample: true }).toFile(`out/webp/${name}.webp`);
  console.log(name.padEnd(18), `${info.width}×${info.height}`, `${(info.size / 1024).toFixed(1)} KB`);
}
