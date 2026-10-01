/**
 * End-to-end check of the reviewer demo login against a running API:
 *
 *   npm run smoke:auth                                  (http://localhost:4000)
 *   API_URL=https://<render-app>.onrender.com npm run smoke:auth
 *
 * Exercises exactly what an App Store / Play reviewer does, plus the negative
 * paths the app relies on. Run it before every store submission.
 */
const API_URL = (process.env.API_URL ?? 'http://localhost:4000').replace(/\/$/, '');
const DEMO_PHONE = process.env.DEMO_PHONE ?? '9999999999';
const DEMO_OTP = process.env.DEMO_OTP ?? '123456';

type Json = Record<string, unknown>;

async function call(method: string, path: string, body?: Json, token?: string) {
  const res = await fetch(`${API_URL}${path}`, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  return { status: res.status, json: (text ? JSON.parse(text) : {}) as Json };
}

let failures = 0;
function check(label: string, ok: boolean, detail?: unknown) {
  if (ok) console.log(`  ✔ ${label}`);
  else {
    failures++;
    console.log(`  ✘ ${label}`, detail ?? '');
  }
}

async function main() {
  console.log(`Auth smoke test → ${API_URL}\n`);

  const ready = await call('GET', '/health/ready');
  check('API + DB ready', ready.status === 200, ready.json);

  const config = await call('GET', '/v1/config');
  check('public config served', config.status === 200 && typeof config.json.config === 'object', config.json);
  check(
    'private flags not leaked in public config',
    !JSON.stringify(config.json).includes('demo_login'),
    config.json,
  );

  const badPhone = await call('POST', '/v1/auth/otp/request', { phone: '12345' });
  check('invalid phone rejected (422)', badPhone.status === 422, badPhone.json);

  const otpReq = await call('POST', '/v1/auth/otp/request', { phone: DEMO_PHONE });
  check('demo OTP request accepted (202)', otpReq.status === 202, otpReq.json);

  const wrong = await call('POST', '/v1/auth/otp/verify', { phone: DEMO_PHONE, otp: '000000' });
  check('wrong demo OTP rejected (401)', wrong.status === 401, wrong.json);

  const login = await call('POST', '/v1/auth/otp/verify', {
    phone: DEMO_PHONE,
    otp: DEMO_OTP,
    deviceId: 'smoke-test',
    deviceInfo: 'smoke-auth script',
  });
  check('demo login succeeds (200)', login.status === 200 && typeof login.json.accessToken === 'string', login.json);
  if (login.status !== 200) throw new Error('cannot continue without a session');

  const accessToken = login.json.accessToken as string;
  const refreshToken = login.json.refreshToken as string;

  const noAuth = await call('GET', '/v1/me');
  check('/me without token → 401', noAuth.status === 401, noAuth.json);

  const me = await call('GET', '/v1/me', undefined, accessToken);
  check('/me with token → 200', me.status === 200, me.json);

  const patch = await call('PATCH', '/v1/me', { name: 'App Reviewer' }, accessToken);
  check('profile update', patch.status === 200 && (patch.json.user as Json)?.name === 'App Reviewer', patch.json);

  const refreshed = await call('POST', '/v1/auth/refresh', { refreshToken });
  check('refresh rotates tokens', refreshed.status === 200 && refreshed.json.refreshToken !== refreshToken, refreshed.json);

  const replay = await call('POST', '/v1/auth/refresh', { refreshToken });
  check('old refresh token rejected after rotation (401)', replay.status === 401, replay.json);

  const logout = await call('POST', '/v1/auth/logout', { refreshToken: refreshed.json.refreshToken as string });
  check('logout (204)', logout.status === 204, logout.json);

  const afterLogout = await call('POST', '/v1/auth/refresh', { refreshToken: refreshed.json.refreshToken as string });
  check('refresh after logout rejected (401)', afterLogout.status === 401, afterLogout.json);

  console.log(failures === 0 ? '\n🎉 Demo login flow is healthy.' : `\n❌ ${failures} check(s) failed.`);
  process.exitCode = failures === 0 ? 0 : 1;
}

main().catch((error: unknown) => {
  console.error('\n❌ smoke test crashed:', error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
