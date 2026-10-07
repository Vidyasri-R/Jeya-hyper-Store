# GoFrugal "Current Stock Detail" export — format and import rules

Analysed 2026-10-07 from `3030_Current_St_ock_Detail_1_2026_10_07_185421.csv` (9.6 MB, 79 columns).

## Shape
- Rows 1–3: store name, report title, company + GSTIN. Row 4: header. Row 5: totals. Data from row 6.
- 24,273 data rows = **batches** (one row per purchase receipt, Transaction No `MR…`), for **15,317 items** (Item Code).
  10,524 items have one batch; the rest 2–26.
- **Stock-only report:** every item listed has stock > 0. Items at zero stock are simply missing.

## Columns we use
| Column | Use |
| --- | --- |
| Item Code | product key (stable; photos attach to it) |
| Item Name | product name (often contains "MRP.10" / "RS.80" — strip for display) |
| DEPT | SUPER MARKET (8,677 items) · FIRST FLOOR (6,392: stationery, gifts, toys, plastics, fancy) · SECOND FLOOR (145: footwear) · SUPERMARKET (58, typo) · blank (45) |
| TYPE | 494 sub-groups, inconsistent (GIFT & TOYS / GIFTS AND TOYS, STATIONARY / STATIONERY, PLASTIC / PLASTICS, "Nill", blank) → mapped to website categories by an admin-editable table |
| BRAND | 15,263 items |
| MRP, Selling | per batch; 2,071 items have different prices across batches → use the **latest Transaction Date** batch |
| Current Stock | per batch; sum per item. 17 "… BULK" items have kg fractions (loose) |
| Sales Tax %, HSN_SAC Code | 0 / 5 / 12 / 18 / 40 (aerated drinks) |
| Status | 244 rows Inactive → don't list |
| EAN Code | 8,891 items — but 14,884 rows were saved by Excel in scientific notation (8.90408E+12) → **digits lost**; export straight to CSV without opening in Excel |

Unused / never imported: Purchase Price, Landing Cost, stock values, distributor name/GST (commercial data — must not reach the public catalogue).
Not usable: Barcode Value (unique per batch, not a product barcode), Short Name (unreliable), UOM (always 1), Regional name, weight (empty).

## Import rules
1. Skip the 3 title rows and the totals row; key on Item Code.
2. Per item: stock = sum of batches; MRP/selling = latest-dated batch; name/brand/type/tax from any row.
3. Item missing from today's file → **out of stock** (kept with its photos, hidden or "out of stock"), never deleted.
4. Inactive → hidden. Selling ≤ MRP checked (no violations in this file).
5. Category = mapping table TYPE (+DEPT) → website category; unmapped TYPEs listed for the admin to assign.
6. Online orders reduce stock immediately; the next upload resets to the POS count.
