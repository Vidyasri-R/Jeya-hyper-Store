/**
 * Cloudflare R2 smoke test: `npm run storage:check`
 *
 * Upload → HEAD → fetch through the PUBLIC URL (what the app will load) → delete.
 * Leaves nothing behind.
 */
import { r2 } from '../infra/r2';

// 1×1 WebP (lossless, transparent) — a real image so content-type handling is exercised.
const TINY_WEBP = Buffer.from('UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==', 'base64');

async function main(): Promise<void> {
  if (!r2.isConfigured()) {
    throw new Error('R2 not configured — fill the R2_* variables in backend/.env');
  }

  const key = `healthcheck/${Date.now()}.webp`;
  const uploaded = await r2.put(key, TINY_WEBP, { contentType: 'image/webp', cacheControl: 'no-store' });
  console.log(`✔ uploaded ${key} (etag ${uploaded.etag})`);

  if (!(await r2.exists(key))) throw new Error('object not found right after upload');
  console.log('✔ object exists (HEAD)');

  try {
    const res = await fetch(uploaded.url);
    const body = Buffer.from(await res.arrayBuffer());
    if (res.status !== 200) {
      throw new Error(`public URL returned ${res.status} — enable public access (custom domain or r2.dev) on the bucket`);
    }
    if (!body.equals(TINY_WEBP)) throw new Error('public URL returned different bytes');
    console.log(`✔ public URL serves the image (${res.headers.get('content-type')}) → ${uploaded.url}`);
  } finally {
    await r2.remove(key);
    console.log('✔ cleaned up');
  }

  console.log('\n🎉 Cloudflare R2 is ready for product images.');
}

main().catch((error: unknown) => {
  console.error('\n❌ storage-check failed:', error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
