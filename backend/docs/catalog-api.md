# Catalogue API (v1)

Public — no auth header needed. Responses carry `Cache-Control` (60–300 s), so the
app's HTTP cache / a CDN can serve repeat browsing.

**Money and quantities are strings** (`"68.50"`, `"0.25"`) — parse with a decimal
type in Dart (e.g. `package:decimal`), never `double`, so totals don't drift.

## Categories

`GET /categories` → tree of active categories that contain products.

```json
{ "categories": [ { "id": 1, "name": "Staples", "slug": "staples-12", "imageUrl": null, "productCount": 70,
    "children": [ { "id": 2, "name": "Rice & Rice Products", "slug": "rice-and-rice-products-13", "productCount": 18, "children": [] } ] } ] }
```

`productCount` includes sub-categories. `imageUrl: null` → show a category placeholder.

## Product listing & search

`GET /products`

| Param | Values | Notes |
|-------|--------|-------|
| `category` | category `slug` | Includes all sub-categories |
| `q` | text, ≤100 chars | Switches to search mode (typo-tolerant, Tamil tokens, barcode / item code) |
| `sort` | listing: `popular` (default), `price_asc`, `price_desc`, `name_asc` · search: `relevance` (default), `price_asc`, `price_desc` | |
| `inStock` | `true` | Hide out-of-stock |
| `limit` | 1–50, default 20 | |
| `cursor` | from previous `nextCursor` | Opaque — don't build or parse it |

```json
{ "items": [ ProductCard ], "nextCursor": "eyJ2Ijo…" | null, "sort": "popular" }
```

Infinite scroll: request again with `cursor=nextCursor` until it's `null`.
Search results stop after 1,000 items (refine the query instead).

### ProductCard

| Field | Example | Notes |
|-------|---------|-------|
| `id`, `slug`, `name`, `nameTa`, `brand`, `categoryId` | | `nameTa` = Tamil name when available |
| `mrp`, `sellingPrice` | `"75.00"`, `"68.50"` | Strike through `mrp` when `discountPercent > 0` |
| `discountPercent` | `9` | Integer |
| `unit`, `packSize` | `"kg"`, `"500 g"` | `packSize` null for loose items |
| `isLoose` | `true` | Sold by weight — show a weight stepper ("0.25 kg") |
| `minOrderQty`, `qtyStep` | `"0.25"`, `"0.25"` | Stepper starts at min, moves by step |
| `maxPurchasableQty` | `"10"` | Disable "+" at this value; `"0"` = can't add |
| `stockStatus` | `in_stock` / `low_stock` / `out_of_stock` | `low_stock` → "Only a few left" |
| `imageUrl` | `null` | Placeholder until product photos are uploaded |

Stock shown here can be up to ~60 s old; **checkout re-checks and reserves stock
atomically**, so the cart must handle "quantity reduced / item unavailable" responses.

## Product detail

`GET /products/:slug` → `{ product: ProductCard & { description, barcode, hsnCode, gstRate, breadcrumb: [{id,name,slug}] } }`
`404` if the product doesn't exist or was deactivated in the POS.

## Search suggestions (as-you-type)

`GET /search/suggest?q=sam` → `{ suggestions: [ { slug, name, imageUrl } ] }` (max 8).
Debounce in the app (~250 ms) and only call for `q.length >= 2`.

## Admin (staff/admin role)

| Call | |
|------|---|
| `POST /admin/sync/catalog` `{ "mode": "delta" \| "full" }` | Run a POS sync now (409 if one is already running) |
| `GET /admin/sync/status` | Watermark, last success/error, consecutive failures |
