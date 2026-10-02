# GoFrugal RetailEasy e-commerce API — what we know

Status (2026-10-02): add-on **514 E-commerce API Integration** activated on **trial until 2026-10-26**
(client must buy before the 1 Nov launch). API key (X-Auth-Token) **not yet issued**.

## Where it runs

On-premise, on the store PC that hosts **RayMedi WebReporter** (same service as the GoAct dashboard):

```
http://localhost:8482/WebReporter/api/v1/
Header: X-Auth-Token: <API-KEY>          (docs show an 80-char hex key)
```

`GET /api/v1/items` without a key → **403 Forbidden** (confirmed on the store PC — the API is live).
Render cannot reach `localhost` → expose via **Cloudflare Tunnel** from that PC (HTTPS, no static IP).

## Endpoints (from GoFrugal KB)

| Method | Path | Use |
|--------|------|-----|
| GET | `/items` | All items with rate + stock |
| POST | `/salesOrders` | Push an online order into the POS |
| GET | `/salesOrders` | List sales orders (reconciliation) |
| GET | `/salesOrders/{id}` | One sales order (status / bill) |

**No documented** categories endpoint, pagination, or modified-since filter.

### Item fields

`itemId` (int), `itemName` (≤100), `locationId` (int), `itemTimeStamp` (numeric — possible delta-sync key),
`stock[]`: `stock` (qty), `mrp`, `salePrice`, `itemReferenceCode` (matrix variant id), `taxPercentage`,
`discountPercentage`.

- One item can have **several `stock[]` rows** (batches / MRPs). POS prices "from the last inward stock".
- Matrix items (size/colour) are distinguished by `itemReferenceCode`.

### Create sales order — `POST /salesOrders`

```json
{ "salesOrder": {
  "onlineReferenceNo": 1, "onlineChildReferenceNo": "1",
  "createdAt": "2013-11-22 13:00:00", "updatedAt": "2013-11-22 13:00:00",
  "status": "pending", "orderRemarks": "", "Channel": "", "courierPartner": "",
  "totalQuantity": 10, "totalAmount": 100, "paymentMode": 1, "totalTaxAmount": 2, "totalDiscountAmount": 0,
  "shippingId": "1", "shippingName": "…", "shippingAddress1": "…", "ShippingAddress2": "",
  "shippingPlace": "…", "shippingState": "Tamil Nadu", "shippingCountry": "india", "shippingPincode": 600042,
  "shippingPhone": "…", "shippingMobile": "…", "shippingEmail": "…", "shippingCharge": 0,
  "deliveryDate": "2013-11-22 13:00:00", "locationId": 1, "userId": "admin",
  "orderItems": [{ "rowNo": 1, "itemId": 1, "itemName": "lux", "itemReferenceCode": "",
                   "salePrice": 10, "quantity": 10, "itemAmount": 100, "taxPercentage": 2,
                   "discountPercentage": 0, "itemRemarks": "", "itemMarketPrice": "" }],
  "customerId": 1, "customerName": "…", "customerAddressLine1": "…", "customerCity": "…",
  "customerState": "…", "customerCountry": "india", "customerPincode": 600042, "customerMobile": "…"
}}
```

Response: `{ "result": { "status": "Success" | "error", "id": 1, "message"?: "…" } }`

**Idempotency plan:** send our order sequence as `onlineReferenceNo`; after a timeout, `GET /salesOrders`
and match on it before retrying, so a slow POS never gets a duplicate bill.

## Open questions for GoFrugal (human support)

1. Issue the X-Auth-Token for add-on 514 (and how to rotate it).
2. Does `/items` support paging / an `itemTimeStamp` (modified-since) filter? Full pull = 30k items.
3. How do we get **categories / item groups** (not in the item fields)?
4. Which `stock[]` row should an online store sell from (last inward?).
5. Valid `paymentMode` values (COD vs prepaid), meaning of `status`, and when a bill number exists.
6. Rate limits; price to convert add-on 514 to a subscription.

Sources: community.gofrugal.com KB — *Overview of API Integration*, *List all items*,
*Create a sales order*, *Retrieve a sales order*.
