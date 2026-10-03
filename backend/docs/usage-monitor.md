# Usage & bills monitor (free-tier budget)

The whole stack is meant to cost **$7/month**: Render Starter + Supabase Free + Cloudflare R2
Free. The API measures its own usage, compares it with each plan's limits and tells the admin
before anything costs extra or gets restricted.

## Limits it watches (October 2026)

| Service | Plan | Limit watched | What happens past it |
| --- | --- | --- | --- |
| Render | Starter $7 on the Hobby workspace | **5 GB outbound bandwidth / month** | $0.15 per extra GB |
| Render | | 512 MB memory | server restarts |
| Render | | 500 build minutes / month (shown, not measured) | $5 per extra 1,000 min |
| Supabase | Free | **500 MB database** | project can be made read-only → orders stop |
| Supabase | Free | **5 GB egress / month** | grace period, then restrictions |
| Cloudflare R2 | Free | 10 GB storage, 1M Class A, 10M Class B ops / month | $0.015/GB, $4.50/M, $0.36/M |
| Razorpay | per transaction | fees reported from each captured payment | — |

Supabase Free also has **no automatic backups** (we run our own — see *Backups* below) and
pauses projects after a week without activity (the hourly monitor query keeps it awake).

Limits and prices live in app_config `usage.limits` (Admin → Settings) so they can be updated
without a deploy if a provider changes pricing.

## How it measures

- **Wire bytes, TLS included** (`src/infra/traffic.ts`): every database connection is a counted
  socket, so Supabase egress (bytes received from the pooler) and our SQL (bytes sent, which
  Render bills as outbound) are exact. HTTP responses through Render's proxy are counted on the
  server sockets. R2 uploads and listing operations are counted in `infra/r2.ts`.
- Flushed into `usage_daily` (one row per IST day) every 5 minutes; database size
  (`pg_database_size`, what Supabase measures) hourly; R2 storage twice a day by listing the
  bucket (~30 Class A ops for 30k images).
- Optional `CLOUDFLARE_API_TOKEN` (permission **Account Analytics: Read**) switches R2 numbers
  to Cloudflare's own analytics, including Class B reads from customers' phones.

Measured costs that shaped the code:
- A new database connection costs ~16 KB (TLS handshake + auth). Connections are kept open
  10 minutes idle / 2 hours max instead of 20 s / 30 min, and the pool is 5.
- A catalogue delta sync run costs ~3 KB in / 7 KB out (~8 MB egress per month at 15-minute runs).
- Listing / search / product pages are cached in memory for 60 s; the order board's 20-second
  poll is answered from memory unless an order changed.

## Alerts

Hourly, every metric gets a level:

- **warning** at 70% used, or a month-end projection over 100% (after the 3rd day of the month)
- **critical** at 90% used, or a projection over 150%

Also: catalogue sync failing 3+ runs in a row (critical at 8).

One open alert per metric (`admin_alerts`). New and escalated alerts are emailed at once;
critical ones are re-sent every 24 h until resolved; an alert closes by itself when the metric
recovers. Admins see open alerts on the order board banner and under Admin → Usage & bills.

A morning digest (9:00 IST) summarises every bill for the month so far.

## Email setup (optional, free with Gmail)

Add these in Render → jeya-api → Environment:

| Key | Value |
| --- | --- |
| `ALERT_EMAILS` | who gets alerts, comma-separated |
| `SMTP_HOST` | `smtp.gmail.com` |
| `SMTP_PORT` | `465` |
| `SMTP_USER` | the Gmail address that sends |
| `SMTP_PASS` | a Google **App password** (Google Account → Security → 2-Step Verification → App passwords) |

Without them everything still works; alerts are only in the app.

## Nightly clean-up (03:00 IST)

Keeps the 500 MB database for business data: deletes OTP requests and expired sessions older
than 30 days, processed payment webhooks older than 90 days, resolved alerts older than 180 days
and usage rows older than 400 days. Orders, payments, refunds and customers are never touched.

## API (admin)

- `GET /v1/admin/usage` — month report: `services[]` with `metrics[]` (`used`, `limit`, `percent`,
  `projected`, `level`, `note`), costs so far / projected (USD and INR), `alerts`, `daily[]`,
  `largestTables`, `notifications.email`.
- `POST /v1/admin/usage/refresh` — re-measure now and re-check alerts.
- `GET /v1/admin/alerts`, `POST /v1/admin/alerts/:id/ack`.

## Backups (Supabase Free has none)

Every night at **2 AM IST** the server exports the business data to the private R2 bucket
**`jeya-backups`** (no public access; the app's R2 key `jeya-api-backend` may use it):

- **Monthly full** (first run of each month): staff accounts, customers, addresses, store
  settings, delivery areas, categories, products, orders + lines + status history, payments,
  refunds.
- **Daily incremental**: only rows changed since the previous run (10-minute overlap), so a
  backup costs a few KB of Supabase egress, not the whole database.
- Files: `db/<YYYY-MM>/<full|incremental>-<YYYYMMDD-HHMMSS>/<table>.ndjson.gz` + `manifest.json`
  (row counts and SHA-256 per file; a set without a manifest never finished and is ignored).
- R2 deletes sets after **100 days** (bucket lifecycle rule) → about three months of history,
  well inside the free 10 GB.
- Not backed up on purpose: sessions, OTPs, carts, webhook logs, usage rows (short-lived or
  rebuilt). Product photos already live in R2.

Commands (from `backend/`, with the production `.env`):

```bash
npm run backup:run                 # back up now (also: Admin → Usage & bills → Back up now)
npm run backup:run -- --full
npm run backup:verify              # restore the latest chain into a scratch schema, compare, drop it
```

`backup:verify` proves the backups restore without touching live tables — run it after schema
changes. A real disaster restore = run the migrations on a new database, then
`backupService.restore(chain, 'public', <client for that database>)`.

Alerts: a warning when backups aren't configured or the last success is older than 36 h (or a
run failed), critical after 72 h. Status and a "Back up now" button are on the Usage & bills
screen; API: `GET /v1/admin/backups`, `POST /v1/admin/backups/run`.

