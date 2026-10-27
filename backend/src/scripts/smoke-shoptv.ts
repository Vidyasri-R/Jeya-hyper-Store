/**
 * Shop TV end to end against the real database and R2 (in-process API):
 *
 *   npm run smoke:shoptv
 *
 * A throw-away admin pairs a throw-away TV, uploads a poster (streamed), sets the break rules, and
 * checks what the TV and the shop phone get. Deletes everything it made (settings are restored).
 */
import { randomBytes } from 'node:crypto';
import type { AddressInfo } from 'node:net';
import { eq, like } from 'drizzle-orm';
import { createApp } from '../app';
import { hashPassword } from '../common/password';
import { closeDb, db } from '../db/client';
import { appConfig, shopMedia, shopScreens, staffUsers } from '../db/schema';
import { r2 } from '../infra/r2';
import { SHOP_TV_KEY } from '../modules/shop-tv/shop-tv.service';

type Json = Record<string, any>; // eslint-disable-line @typescript-eslint/no-explicit-any
let base = '';
let failures = 0;
const tag = randomBytes(3).toString('hex');

async function call(method: string, path: string, opts: { body?: unknown; token?: string; device?: string; raw?: { bytes: Buffer; type: string } } = {}) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: {
      ...(opts.body !== undefined ? { 'content-type': 'application/json' } : {}),
      ...(opts.raw ? { 'content-type': opts.raw.type } : {}),
      ...(opts.token ? { authorization: `Bearer ${opts.token}` } : {}),
      ...(opts.device ? { 'x-device-key': opts.device } : {}),
    },
    ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
    ...(opts.raw ? { body: new Uint8Array(opts.raw.bytes) } : {}),
  });
  const text = await res.text();
  return { status: res.status, json: (text ? JSON.parse(text) : {}) as Json };
}

function check(label: string, ok: boolean, detail?: unknown) {
  if (ok) console.log(`  ✔ ${label}`);
  else {
    failures++;
    console.log(`  ✘ ${label}`, detail === undefined ? '' : JSON.stringify(detail).slice(0, 500));
  }
}

async function main() {
  const server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  console.log(`Shop TV smoke test → in-process API (${base}) on the real database\n`);

  const [savedSettings] = await db.select().from(appConfig).where(eq(appConfig.key, SHOP_TV_KEY));
  const pass = `${randomBytes(9).toString('base64url')}7a`;
  await db.insert(staffUsers).values({ username: `smoke-tvadmin-${tag}`, name: 'Smoke TV Admin', role: 'admin', passwordHash: await hashPassword(pass), mustChangePassword: false });
  const device = randomBytes(24).toString('base64url');
  const mediaIds: string[] = [];

  try {
    const login = await call('POST', '/v1/staff/auth/login', { body: { username: `smoke-tvadmin-${tag}`, password: pass } });
    const admin = login.json.accessToken as string;

    console.log('Pairing');
    const unknown = await call('GET', '/v1/shoptv/state', { device });
    check('unknown TV refused', unknown.status === 401, unknown.json);
    const reg = await call('POST', '/v1/shoptv/register', { body: { deviceKey: device } });
    check('TV gets a 6-digit code', reg.status === 200 && /^\d{6}$/.test(reg.json.code ?? ''), reg.json);
    const waiting = await call('GET', '/v1/shoptv/state', { device });
    check('not paired yet → same code', waiting.json.paired === false && waiting.json.code === reg.json.code, waiting.json);
    const wrong = await call('POST', '/v1/admin/shoptv/screens/pair', { token: admin, body: { code: '000000', name: 'x' } });
    check('wrong code refused', wrong.status === 404, wrong.json);
    const paired = await call('POST', '/v1/admin/shoptv/screens/pair', { token: admin, body: { code: reg.json.code, name: `Smoke TV ${tag}` } });
    check('admin pairs the TV', paired.status === 201, paired.json);

    console.log('\nAds');
    const sharp = (await import('sharp')).default;
    const poster = await sharp({ create: { width: 1920, height: 1080, channels: 3, background: '#0e7a3b' } }).png().toBuffer();
    const up = await call('PUT', `/v1/admin/shoptv/media?title=${encodeURIComponent(`Smoke poster ${tag}`)}`, { token: admin, raw: { bytes: poster, type: 'image/png' } });
    if (up.json.media?.id) mediaIds.push(up.json.media.id);
    check('poster streamed to storage', up.status === 201 && up.json.media?.mediaType === 'image' && up.json.media?.bytes === poster.length, up.json);
    const file = up.json.media?.url ? await fetch(up.json.media.url) : null;
    check('file is on the CDN', file?.status === 200, file?.status);
    const bad = await call('PUT', '/v1/admin/shoptv/media?title=x', { token: admin, raw: { bytes: Buffer.from('hello'), type: 'text/plain' } });
    check('other file types refused', bad.status === 400, bad.json);

    const settings = await call('PUT', '/v1/admin/shoptv/settings', {
      token: admin,
      body: { value: { breakEveryMinutes: { min: 1, max: 2 }, itemsPerBreak: { min: 1, max: 1 }, openTime: '00:00', closeTime: '23:59', imageSeconds: 8, adSound: 'phone', tvVolume: 80, phoneVolume: 100, cctv: { mode: 'pages', channelCount: 36, cameras: [], pageSize: 9, pageSeconds: 15 }, panel: { headline: 'Order on the app', offer: 'Free delivery above ₹999', qrUrl: 'https://jeyahyperstore.in' } } },
    });
    check('break rules saved', settings.status === 200, settings.json);
    const badSettings = await call('PUT', '/v1/admin/shoptv/settings', { token: admin, body: { value: { openTime: '9am' } } });
    check('invalid rules refused', badSettings.status === 422, badSettings.json);

    console.log('\nWhat the TV and the phone get');
    const state = await call('GET', '/v1/shoptv/state', { device });
    const breaks = (state.json.breaks as Json[]) ?? [];
    check('TV gets settings, files and the next breaks', state.json.paired === true && (state.json.media as Json[]).some((m) => m.id === mediaIds[0]) && breaks.length > 0, { paired: state.json.paired, breaks: breaks.length });
    const phone = await call('GET', '/v1/staff/shop-audio', { token: admin });
    check('shop phone gets the same plan', phone.status === 200 && JSON.stringify(phone.json.breaks) === JSON.stringify(state.json.breaks), { phone: phone.json.breaks?.length, tv: breaks.length });
    const report = await call('POST', `/v1/shoptv/media/${mediaIds[0]}/report`, { device, body: { durationMs: 12000, aspect: 1.778 } });
    check('TV reports what it measured', report.status === 204, report.json);
    const hb = await call('POST', '/v1/shoptv/heartbeat', { device, body: { status: { mode: 'cctv', cctvOk: true }, appVersion: '1.0.0' } });
    check('heartbeat', hb.status === 204, hb.json);
    const overview = await call('GET', '/v1/admin/shoptv', { token: admin });
    const screen = (overview.json.screens as Json[]).find((s) => s.name === `Smoke TV ${tag}`);
    check('admin sees the TV online with its status', screen?.online === true && screen?.status?.cctvOk === true, screen);
    const off = await call('PATCH', `/v1/admin/shoptv/media/${mediaIds[0]}`, { token: admin, body: { isActive: false } });
    const afterOff = await call('GET', '/v1/shoptv/state', { device });
    check('switched-off ad leaves the plan', off.status === 200 && !(afterOff.json.media as Json[]).some((m) => m.id === mediaIds[0]), afterOff.json.breaks?.length);
    const del = await call('DELETE', `/v1/admin/shoptv/media/${mediaIds[0]}`, { token: admin });
    const key = up.json.media?.url ? r2.keyFromUrl(up.json.media.url) : null;
    check('deleted (database + storage)', del.status === 204 && key !== null && !(await r2.exists(key)), del.json);
    if (del.status === 204) mediaIds.length = 0;
    const removed = await call('DELETE', `/v1/admin/shoptv/screens/${screen?.id}`, { token: admin });
    const back = await call('GET', '/v1/shoptv/state', { device });
    check('removed TV is unknown again', removed.status === 204 && back.status === 401, back.json);
  } finally {
    for (const id of mediaIds) {
      const [row] = await db.delete(shopMedia).where(eq(shopMedia.id, id)).returning();
      const key = row ? r2.keyFromUrl(row.url) : null;
      if (key) await r2.remove(key).catch(() => undefined);
    }
    await db.delete(shopScreens).where(like(shopScreens.name, `Smoke TV ${tag}%`));
    await db.delete(appConfig).where(eq(appConfig.key, SHOP_TV_KEY));
    if (savedSettings) await db.insert(appConfig).values(savedSettings);
    await db.delete(staffUsers).where(like(staffUsers.username, `smoke-tvadmin-${tag}`));
    console.log('\nCleaned up the test TV, ad, settings and admin.');
    server.close();
    await closeDb();
  }
  console.log(failures === 0 ? '\n🎉 Shop TV works end to end.' : `\n❌ ${failures} check(s) failed.`);
  process.exitCode = failures === 0 ? 0 : 1;
}

main().catch((error: unknown) => {
  console.error('❌ smoke test crashed:', error);
  process.exitCode = 1;
});
