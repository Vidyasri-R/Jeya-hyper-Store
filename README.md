# Jeya Hyper Store — Online Store

Grocery e-commerce for Jeya Hyper Store: Flutter app (Android + iOS) backed by an
Express/TypeScript API, with 30,000 SKUs synced from GoFrugal RetailEasy POS.

| Path | What |
|------|------|
| `app/` | Flutter app (Android + iOS) — Riverpod, go_router, Razorpay |
| `backend/` | Express 5 + TypeScript API, Drizzle ORM, Supabase Postgres |
| `backend/docs/` | API references for the app team (auth, catalogue, checkout, payments) |
| `render.yaml` | Render Blueprint (Singapore, Starter) |
| `.github/workflows/` | CI: typecheck, tests, build, migration drift check |

## Infrastructure

| Service | Use | Region |
|---------|-----|--------|
| Supabase Postgres | Primary DB (Supavisor pooler 6543 for the API, 5432 for migrations) | ap-south-1 Mumbai |
| Render | API web service | Singapore |
| Cloudflare R2 | Product images (WebP), zero egress fees | APAC |
| Meta WhatsApp Cloud API | OTP + order notifications *(next)* | — |

## Backend quick start

```bash
cd backend
cp .env.example .env        # fill DATABASE_URL, DIRECT_DATABASE_URL, secrets
npm install
npm run db:migrate          # apply migrations
npm run db:seed             # app_config defaults (idempotent)
npm run db:check            # end-to-end DB smoke test
npm run dev                 # http://localhost:4000/health/ready
npm run smoke:auth          # reviewer demo-login flow (API must be running)
npm run storage:check       # Cloudflare R2 upload/public-URL test
npm run sync:catalog        # POS → DB catalogue sync (add `-- full` for a full resync)
npm test                    # unit tests
```

Requires Node 22 (`.nvmrc`).

## App quick start

```bash
cd app
flutter pub get
flutter run                                                   # talks to https://jeya-api.onrender.com/v1
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/v1  # Android emulator → local API
```

Package / bundle id: `com.jeyahyperstore.app`. Reviewer login: 9999999999 / OTP 123456.

## Schema changes

1. Edit `backend/src/db/schema.ts`
2. `npm run db:generate` → commit the new file in `backend/drizzle/`
3. Render runs `db:migrate:prod` before each deploy. CI fails if step 2 is skipped.

Every table must have row-level security enabled (Supabase exposes `public` over REST);
`npm run db:check` fails otherwise.
