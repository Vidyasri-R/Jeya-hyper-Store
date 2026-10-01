# Auth & profile API (v1)

Base URL: `https://<render-app>.onrender.com/v1` (local: `http://localhost:4000/v1`)

All errors share one shape:

```json
{ "error": { "code": "UNAUTHORIZED", "message": "Incorrect OTP", "details": { "reason": "otp_incorrect", "attemptsRemaining": 3 }, "requestId": "…" } }
```

Branch on `error.details.reason` in the app, not on `message`.

## Login flow

| # | Call | Body | Success |
|---|------|------|---------|
| 1 | `POST /auth/otp/request` | `{ "phone": "9876543210" }` | `202 { phone, expiresInSec, resendAfterSec, channel }` |
| 2 | `POST /auth/otp/verify` | `{ "phone", "otp": "123456", "deviceId?", "deviceInfo?" }` | `200 { accessToken, accessTokenExpiresIn, refreshToken, refreshTokenExpiresAt, isNewUser, user }` |
| 3 | If `user.profileComplete == false` → name screen → `PATCH /me { "name" }` | | |

Phone accepts `9876543210`, `+91 98765 43210`, `09876543210`; stored as `919876543210`.

### Error reasons

| HTTP | `reason` | App behaviour |
|------|----------|---------------|
| 401 | `otp_incorrect` | Show "Incorrect OTP (n left)" using `attemptsRemaining` |
| 401 | `otp_expired` | Offer "Resend OTP" |
| 429 | `otp_locked` | Force a new OTP request |
| 429 | — (`retryAfterSec` in details, `Retry-After` header) | Disable Resend with a countdown |
| 503 | — | "OTP service unavailable" (production before WhatsApp is live) |
| 403 | — | Account blocked |

## Tokens

- **Access token**: JWT, 15 min. Send `Authorization: Bearer <token>`.
- **Refresh token**: opaque, 60 days, **rotates on every use** — always store the new one.
- `401` with `reason: token_expired` → call `POST /auth/refresh { refreshToken }` once, retry the request.
- `401` with `reason: refresh_invalid` → session is gone; go to login.
- ⚠️ **Serialise refreshes in the app** (one in-flight refresh, others await it). Two parallel
  refreshes with the same token = the second one fails and logs the user out.
- Logout: `POST /auth/logout { refreshToken }` → `204`.

## Profile

| Call | Notes |
|------|-------|
| `GET /me` | `{ user }` |
| `PATCH /me` | `{ name?, email? }` — `email: ""` or `null` clears it |
| `DELETE /me` | `204`. `409 orders_in_flight` if an order is still being delivered. Required by Apple 5.1.1(v) & Google Play. |

## Remote config

`GET /config` (public, cached 60 s) → `{ config: { "app.min_supported_version": { android, ios }, "app.maintenance": { enabled, message }, "store.info": {…} } }`

## Store reviewer login

- Phone **9999999999**, OTP **123456** — no message is sent.
- Live switch: `app_config` row `auth.demo_login_enabled` (`true`/`false`), picked up within 30 s, no redeploy.
  Turn it **off** after both stores approve:
  ```sql
  update app_config set value = 'false' where key = 'auth.demo_login_enabled';
  ```
- Verify before submission: `API_URL=https://<render-app>.onrender.com npm run smoke:auth`
