# Jeya Staff

Order board and back office for Jeya Hyper Store — one app, two roles:

- **Staff**: order board (New → Packing → Packed → Out for delivery → Delivered), packing with
  weighed quantities, cash collection, cancellations, new-order chime.
- **Admin**: everything above plus Sales, product Photos, Staff accounts, Store settings and
  **Usage & bills** (free-tier budget monitor).

Runs on Android phones and in a browser on the store computer (wide screens get list + detail
side by side). API: `backend/docs/staff-api.md`.

## Run

```bash
flutter run                                   # production API
flutter run --dart-define=API_BASE_URL=http://localhost:4000/v1   # local API (adb reverse tcp:4000 tcp:4000)
flutter test
```

## Build

```bash
flutter build apk --release --split-per-abi   # app-arm64-v8a-release.apk (~20 MB) for staff phones
flutter build web --release                   # static site in build/web
```

The first admin is created from the backend: `cd backend && npm run staff:create-admin`.
