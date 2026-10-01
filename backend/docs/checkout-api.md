# Addresses, delivery, cart, checkout & orders (v1)

All endpoints except `/delivery/*` need `Authorization: Bearer <accessToken>`.
Money and quantities are **strings** — use a decimal type in Dart.

## Delivery

Pricing (editable in Supabase → `app_config` → `delivery.rules`, live within 30 s):

- Order subtotal **≥ ₹999 → free delivery**.
- Below that, a fee by **road distance from the shop** (10.8127737, 78.6358536):
  `≤3 km ₹20 · ≤6 km ₹40 · ≤10 km ₹60` *(placeholder bands — confirm with the store)*.
  Road km ≈ straight-line km × 1.3.
- Beyond 10 km → not serviceable.
- Address without a map pin → priced by pincode (`serviceable_pincodes`).

| Call | Use |
|------|-----|
| `GET /delivery/rules` | Bands + free threshold for a "Delivery charges" sheet |
| `GET /delivery/estimate?lat=&lng=` | Live fee while the user drags the map pin |
| `GET /delivery/pincodes/:pincode` | Quick "do you deliver here?" before a pin exists |

Response: `{ serviceable: true, method: "distance"|"pincode", distanceKm, deliveryFee, minOrderAmount, freeDeliveryAbove }`
or `{ serviceable: false, reason: "out_of_range"|"pincode_not_served", distanceKm, maxDistanceKm }`.

**App: always capture a map pin (lat/lng) on the address form** — distance pricing needs it.

## Addresses — `/me/addresses`

`GET` list · `POST` create · `PATCH /:id` (send `isDefault: true` to make default) · `DELETE /:id`.
Fields: `label?, recipientName, phone, pincode, line1, line2?, landmark?, city, state?, latitude?, longitude?, isDefault?`.
Each address returns `serviceable`. First address becomes default automatically; max 10.

## Cart — `/cart`

| Call | |
|------|---|
| `GET /cart` | `{ cart: { items, summary } }` |
| `PUT /cart/items/:productId` `{ quantity: "1.5" }` | Set qty (`"0"` removes) |
| `DELETE /cart/items/:productId` · `DELETE /cart` | Remove one / clear |
| `POST /cart/merge` `{ items: [{ productId, quantity }] }` | After login, merge the guest cart kept on the phone (safe to retry) |
| `POST /cart/fix` | Apply all `suggestedQuantity` fixes at once |

Each line: `{ product: ProductCard, quantity, unitPrice, lineTotal, lineMrpTotal, issue, suggestedQuantity }`.
`issue`: `null` · `unavailable` · `out_of_stock` · `exceeds_stock` · `invalid_quantity` — show a banner
and offer "Fix cart". `summary.subtotal` only counts lines without issues.

`PUT` errors: `409 exceeds_stock` (details carry `maxPurchasableQty`), `400 invalid_quantity` (min/step), `409 cart_full` (100 lines).

## Checkout

1. `POST /checkout/quote { addressId }` → `{ quote: { items, totals: { subtotal, mrpTotal, savings, deliveryFee, freeDeliveryApplied, total }, delivery, freeDeliveryShortBy, paymentMethods, canPlaceOrder, blockers } }`
   - `freeDeliveryShortBy: "959.00"` → show "Add ₹959 more for FREE delivery".
   - `blockers[].reason`: `cart_empty`, `cart_needs_review`, `address_not_serviceable`, `below_minimum`.
2. `POST /orders` with:
   ```json
   { "addressId": "…", "paymentMethod": "cod", "idempotencyKey": "<uuid per checkout screen>", "expectedTotal": "376.00", "customerNote": "Ring the bell" }
   ```
   - **Generate `idempotencyKey` once when the checkout screen opens; reuse it on retries/double taps.** Same key → same order (`200`), new order → `201`.
   - `expectedTotal` = the `quote.totals.total` the user saw. If anything changed → `409 total_changed` with the new `total`; re-quote and ask the user to confirm.
   - `409 stock_changed` → someone bought the last units; refresh the cart.
   - `409 payment_method_unavailable` → online payments are off (`quote.paymentMethods`).
   - COD → `status: "placed"`. Online → `status: "pending_payment"`, stock held until `reservationExpiresAt` (15 min); Razorpay flow comes in Step 4b.

## Orders — `/orders`

`GET /orders?cursor=&limit=` (newest first) · `GET /orders/:id` (items + `statusHistory`) · `POST /orders/:id/cancel { reason? }`.
`canCancel` tells the app whether to show the Cancel button (before the store confirms; unpaid only).

Statuses: `pending_payment → placed → confirmed → packing → ready_for_delivery → out_for_delivery → delivered`, or `cancelled` / `payment_failed`.
