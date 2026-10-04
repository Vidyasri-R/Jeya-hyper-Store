// Upload out/tiles to the public R2 bucket under maps/trichy/<version>/ (immutable, cached a year).
// Credentials come from backend/.env (the same R2 key the API uses); nothing is printed.
//   node upload_tiles.mjs v1
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { createRequire } from 'node:module';
import { join } from 'node:path';

const require = createRequire(new URL('../../backend/package.json', import.meta.url));
require('dotenv').config({ path: new URL('../../backend/.env', import.meta.url).pathname, quiet: true });
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const version = process.argv[2] ?? 'v1';
const { R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_BASE_URL } = process.env;
const s3 = new S3Client({
  region: 'auto',
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: R2_ACCESS_KEY_ID, secretAccessKey: R2_SECRET_ACCESS_KEY },
});

const files = [];
(function walk(dir) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) walk(p);
    else if (name.endsWith('.webp')) files.push(p);
  }
})('out/tiles');

let done = 0, bytes = 0;
async function worker() {
  while (files.length) {
    const file = files.pop();
    const key = `maps/trichy/${version}/${file.slice('out/tiles/'.length)}`;
    const body = readFileSync(file);
    await s3.send(new PutObjectCommand({ Bucket: R2_BUCKET, Key: key, Body: body, ContentType: 'image/webp', CacheControl: 'public, max-age=31536000, immutable' }));
    done++; bytes += body.length;
    if (done % 500 === 0) console.log(`${done} uploaded`);
  }
}
const total = files.length;
await Promise.all(Array.from({ length: 16 }, worker));
console.log(`uploaded ${done}/${total} tiles, ${(bytes / 1048576).toFixed(1)} MB → ${R2_PUBLIC_BASE_URL}/maps/trichy/${version}/{z}/{x}/{y}.webp`);
