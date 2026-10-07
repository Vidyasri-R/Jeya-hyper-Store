/**
 * Publishes a Jeya Staff APK for direct download (staff.jeyahyperstore.in/download/):
 *   apps/jeya-staff/jeya-staff-<version>-<build>.apk   (never changes, cached for a year)
 *   apps/jeya-staff/latest.json                         (always re-checked; the app and page read it)
 * Run by staff_app/tool/release_apk.sh — not by hand.
 *   tsx src/scripts/publish-staff-apk.ts <apk> <versionName> <versionCode> [notes]
 */
import 'dotenv/config';
import { readFileSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { r2 } from '../infra/r2';

async function main() {
  const [apk, versionName, versionCodeRaw, notes] = process.argv.slice(2);
  const versionCode = Number(versionCodeRaw);
  if (!apk || !versionName || !/^\d+\.\d+\.\d+$/.test(versionName) || !Number.isInteger(versionCode) || versionCode < 1) {
    throw new Error('usage: publish-staff-apk <apk> <versionName x.y.z> <versionCode> [notes]');
  }
  if (!r2.isConfigured()) throw new Error('R2 is not configured (backend/.env)');
  const body = readFileSync(apk);
  const sha256 = createHash('sha256').update(body).digest('hex');
  const key = `apps/jeya-staff/jeya-staff-${versionName}-${versionCode}.apk`;
  const stored = await r2.put(key, body, { contentType: 'application/vnd.android.package-archive', metadata: { sha256 } });
  const latest = {
    versionName,
    versionCode,
    url: stored.url,
    bytes: statSync(apk).size,
    sha256,
    notes: notes ?? null,
    publishedAt: new Date().toISOString(),
  };
  const manifest = await r2.put('apps/jeya-staff/latest.json', Buffer.from(JSON.stringify(latest, null, 2)), {
    contentType: 'application/json',
    cacheControl: 'no-cache',
  });
  console.log(`APK:    ${stored.url} (${(latest.bytes / 1e6).toFixed(1)} MB)`);
  console.log(`Latest: ${manifest.url}`);
}

main().then(
  () => process.exit(0),
  (error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exit(1);
  },
);
