# Online payments — Razorpay (v1)

Flutter package: [`razorpay_flutter`](https://pub.dev/packages/razorpay_flutter). Keys never live in the app —
the backend returns the public `keyId` per payment.

## Flow

1. `POST /checkout/quote` → show total; check `quote.paymentMethods.online`.
2. `POST /orders` with `"paymentMethod": "online"` → order `status: "pending_payment"` (stock held).
3. `POST /orders/:id/payment` →
   ```json
   { "payment": { "provider": "razorpay", "testMode": true, "keyId": "rzp_test_…", "razorpayOrderId": "order_…",
                  "amount": 10000, "currency": "INR", "name": "Jeya Hyper Store",
                  "description": "Order JHS-261002-1009", "prefill": { "contact": "+919999999999", "name": "…" },
                  "expiresAt": "…" } }
   ```
   Open Razorpay with these exact values (`amount` is in **paise**; `order_id: razorpayOrderId`).
   Calling it again reuses the same Razorpay order — safe after an app restart.
4. On Razorpay **success**: `POST /orders/:id/payment/confirm`
   `{ "razorpayOrderId", "razorpayPaymentId", "razorpaySignature" }` (from the success callback)
   - `200 { status: "paid", orderStatus: "placed" }` → show success.
   - `202 { status: "processing" }` → show "Confirming payment…" and poll `GET /orders/:id` every 3 s (≤ 60 s).
5. On Razorpay **failure / dismiss**: let the user tap "Try again" (repeat step 3) until `expiresAt`.
   After that the order becomes `payment_failed` and stock is released.

## What the server guarantees

- Paid only after **signature check + Razorpay confirms `captured` for the exact amount**.
- Webhook (`/v1/webhooks/razorpay`) and a reconciler also mark orders paid, so closing the app
  mid-payment is safe. Any number of duplicate notifications change nothing.
- Paid after the hold expired → stock re-reserved, or **auto-refund** if it's gone.
- `POST /orders/:id/cancel` on a paid order (before the store confirms) → **full refund**
  (`paymentStatus: "refunded"`).

## Test mode (store review)

Razorpay test keys are active. Test with **Netbanking → any bank → Success** (no real money).
Switch to live keys on Render before launch — no app change needed.
