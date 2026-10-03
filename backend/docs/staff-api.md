# Jeya Staff API (store staff & admin app)

Base URL: `https://jeya-api.onrender.com/v1`. All bodies are JSON unless noted. Money is a
string with 2 decimals (`"249.50"`), quantities are strings (`"0.75"`).

Staff accounts are **separate from customer accounts**: a customer token is rejected by every
`/staff` and `/admin` route and vice versa.

## Auth

| Method & path | Body | Result |
| --- | --- | --- |
| `POST /staff/auth/login` | `{ username, password, deviceInfo? }` | `{ accessToken, accessTokenExpiresIn (1800), refreshToken, refreshTokenExpiresAt, staff }` |
| `POST /staff/auth/refresh` | `{ refreshToken }` | new token pair + `staff` (rotates; the old refresh token dies) |
| `POST /staff/auth/logout` | `{ refreshToken }` | 204 |
| `GET /staff/me` | | `{ staff }` |
| `POST /staff/me/password` | `{ currentPassword, newPassword }` | fresh token pair + `staff`; every other device is signed out |

`staff = { id, username, name, phone, role: 'staff' | 'admin', mustChangePassword, isActive, lastLoginAt }`

- Wrong username or password → 401 `credentials_invalid` (same answer for both).
- 5 wrong passwords → account locked 15 min → 429 `account_locked` with `retryAfterSec`
  (an admin's password reset unlocks it).
- Disabled account → 403 `account_disabled`.
- While `mustChangePassword` is true (new account / after an admin reset), every route except
  `/staff/me` and `/staff/me/password` answers 403 `password_change_required`.
- Access tokens last 30 min; refresh tokens 30 days. Disabling an account or resetting its
  password ends its sessions within ~15 s (401 `session_revoked`).
- New password rules: 8+ characters, a letter and a number, not containing the username.

## Order board (staff and admins)

### `GET /staff/orders/summary` — poll every ~20 s while the board is open

```json
{ "counts": { "new": 2, "packing": 1, "ready": 0, "out": 1, "unpaid": 0, "deliveredToday": 7 },
  "latestPlacedAt": "2026-10-03T05:12:09.000Z", "version": 41,
  "alerts": { "open": 1, "worst": "warning" } }
```

Served from memory unless an order changed, so polling is cheap. Play the new-order sound when
`counts.new` goes up or `latestPlacedAt` changes. `alerts` is `null` for non-admins.

### `GET /staff/orders?tab=new&q=&cursor=&limit=30`

Tabs: `new` (placed), `packing` (confirmed + packing), `ready`, `out`, `unpaid` (awaiting online
payment), `delivered`, `cancelled`, `all`. Active tabs list **oldest first**; delivered /
cancelled / all list newest first. `q` (2+ chars) searches every tab: order number or its last
digits (`1011`), customer phone digits, or name.

Each order: `{ id, orderNumber, status, paymentMethod, paymentStatus, totalAmount, finalAmount,
amountDue, recipientName, phone, area, hasNote, itemCount, placedAt, promisedBy, createdAt, updatedAt }`.
`promisedBy` = the delivery date promised to the customer (end of that IST day) — the app shows
"By today / By tomorrow", and "Late" once it has passed.
`nextCursor` pages on.

### `GET /staff/orders/:id`

Everything needed to pack and deliver: `items[]` (name, itemCode, barcode, packSize, isLoose,
imageUrl, quantity, packedQuantity, unitPrice, totalPrice), `customer`, `deliveryAddress`,
`mapsUrl` (Google Maps link from the pin), `customerNote`, `amountToCollect` (cash for COD, else
`"0.00"`), `history[]` (`{ status, note, at, by }` — staff name, "Customer" or "System"),
`payments[]`, `refunds[]`, `cod`, and `actions: { next: { to, label } | null, canCancel }`.

### `POST /staff/orders/:id/advance`

`{ from, to, note?, packedItems?, codCollectedAmount? }` → `{ order }` (the full detail).

`from` is the status the screen showed; if someone else already moved the order you get
409 `order_changed` (refresh). Repeating the same tap after a network error is harmless.

| from → to | Label | Extra |
| --- | --- | --- |
| placed → packing (or → confirmed) | Start packing / Accept | |
| confirmed → packing | Start packing | |
| packing → ready_for_delivery | Mark packed | `packedItems: [{ productId, packedQuantity }]` for items packed **less** than ordered (weighed loose items, out-of-stock). Omitted items = packed in full. Can't exceed the ordered quantity. The order's `finalAmount` drops accordingly. |
| ready_for_delivery → out_for_delivery | Out for delivery | |
| out_for_delivery → delivered | Mark delivered | COD: `codCollectedAmount` required; if it differs from `amountToCollect` add a `note`. Prepaid orders packed short get the difference refunded automatically. |

The customer app shows: Ordered → Packed → Out for delivery → Delivered.

### `POST /staff/orders/:id/cancel`

`{ from, reason }` (reason 3–200 chars, shown to the customer). Stock is released; a paid online
order is refunded in full automatically.

## Admin only (`role: 'admin'`; staff get 403 `admin_only`)

### Staff accounts
- `GET /admin/staff` → `{ staff: [...staff, isLocked, createdAt] }`
- `POST /admin/staff` `{ username, name, phone?, role }` → 201 `{ staff, temporaryPassword }`
  (show it once; the person must change it at first login)
- `PATCH /admin/staff/:id` `{ name?, phone?, role?, isActive? }` — you can't disable/demote
  yourself, and there must always be one active admin (409).
- `POST /admin/staff/:id/reset-password` → `{ temporaryPassword }` (unlocks, signs out everywhere)

### Store settings
- `GET /admin/settings` → `{ settings: { "delivery.rules", "checkout.payment_methods",
  "store.info", "app.maintenance", "auth.demo_login_enabled", "app.min_supported_version",
  "usage.limits" } }`
- `PUT /admin/settings/:key` `{ value }` — validated per key (422 with field errors);
  customer app picks it up within a minute.

### Products (photos and store-owned fields)
- `GET /admin/products?q=&filter=all|no_image|with_image|inactive&cursor=&limit=30`
  → `{ products, nextCursor, counts: { active, withImage } }`
- `PATCH /admin/products/:id` `{ nameTa?, description?, sortRank? (0–1000, higher = shown first), safetyStock? }`
- `PUT /admin/products/:id/image` — **body is the image bytes**, `Content-Type: image/jpeg |
  image/png | image/webp`, ≤ 8 MB. Resize on the phone first (≤ 1600 px, JPEG 85%). The server
  stores an 800 px WebP (~30–60 KB) in R2 → `{ imageUrl, bytes }`.
- `DELETE /admin/products/:id/image` → 204

### Sales dashboard
`GET /admin/dashboard?days=1|7|30|90` → `{ totals: { orders, sales, averageOrderValue, codSales,
onlineSales, delivered, cancelled, customers }, previous: { orders, sales }, daily[], topProducts[] }`
(IST days; sales = accepted orders at their final amount, cancellations excluded).

### Usage & bills — see `usage-monitor.md`
- `GET /admin/usage`, `POST /admin/usage/refresh`, `GET /admin/alerts`, `POST /admin/alerts/:id/ack`

### Backups — see `usage-monitor.md`
- `GET /admin/backups` → `{ configured, lastSuccessAt, lastError, last, sets[] }`
- `POST /admin/backups/run` → runs a backup now (full on the first run of a month)

### Web app
The same app runs at **https://jeya-staff.pages.dev** (Cloudflare Pages, free; the API allows
that origin via `CORS_ORIGINS`). Redeploy after changes:
`cd staff_app && flutter build web --release && npx wrangler@4 pages deploy build/web --project-name jeya-staff --branch main`.

### POS sync
- `POST /admin/sync/catalog` `{ mode: 'delta' | 'full' }`, `GET /admin/sync/status`

## First admin

The first admin is created on a computer with the backend checked out:

```bash
cd backend && npm run staff:create-admin
```

It asks for the username, name and password (typed hidden). Every other account is created
from the app.
