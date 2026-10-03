/**
 * Jeya Hyper Store — database schema (single source of truth).
 *
 * Conventions
 * - Column names are snake_case in Postgres (drizzle `casing: 'snake_case'`), camelCase in TS.
 * - Money is numeric(12,2) and surfaces in TS as a string. Never parse it into a JS float
 *   for arithmetic; do sums in SQL or with integer paise.
 * - Quantities are numeric(12,3) so loose items (1.250 kg of onions) work.
 * - User-facing / guessable-sensitive rows (users, orders, payments) use UUID keys.
 *   High-volume catalog rows use bigint identity keys.
 * - Products and categories are never hard-deleted (order history references them);
 *   use `is_active = false`.
 */
import { relations, sql, type SQL } from 'drizzle-orm';
import {
  bigint,
  boolean,
  check,
  customType,
  date,
  index,
  integer,
  jsonb,
  numeric,
  pgEnum,
  pgSequence,
  pgTable,
  primaryKey,
  smallint,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
  type AnyPgColumn,
} from 'drizzle-orm/pg-core';

/* ───────────────────────────── Helpers ───────────────────────────── */

const tsvector = customType<{ data: string }>({
  dataType: () => 'tsvector',
});

const money = () => numeric({ precision: 12, scale: 2 });
const quantity = () => numeric({ precision: 12, scale: 3 });
const tstz = () => timestamp({ withTimezone: true, mode: 'date' });

const timestamps = {
  createdAt: tstz().notNull().defaultNow(),
  updatedAt: tstz()
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
};

/* ────────────────────────────── Enums ────────────────────────────── */

export const userRole = pgEnum('user_role', ['customer', 'staff', 'admin']);

export const otpChannel = pgEnum('otp_channel', ['whatsapp', 'sms']);

export const productUnit = pgEnum('product_unit', ['pcs', 'kg', 'g', 'l', 'ml', 'pack', 'dozen']);

export const orderStatus = pgEnum('order_status', [
  'pending_payment', // created, waiting for gateway capture (stock reserved)
  'placed', // paid (or COD) — waiting for store to accept
  'confirmed', // store accepted; GoFrugal bill being / been created
  'packing',
  'ready_for_delivery',
  'out_for_delivery',
  'delivered',
  'cancelled',
  'payment_failed', // reservation expired / payment never captured
]);

export const paymentStatus = pgEnum('payment_status', [
  'pending',
  'paid',
  'failed',
  'partially_refunded',
  'refunded',
]);

/** On orders: 'cod' or 'online' (prepaid). Payment rows record the concrete method (upi/card/…). */
export const paymentMethod = pgEnum('payment_method', ['upi', 'card', 'netbanking', 'wallet', 'cod', 'online']);

export const paymentProvider = pgEnum('payment_provider', ['razorpay', 'cashfree']);

export const paymentAttemptStatus = pgEnum('payment_attempt_status', [
  'created',
  'authorized',
  'captured',
  'failed',
]);

export const refundStatus = pgEnum('refund_status', ['pending', 'processed', 'failed']);

export const gofrugalSyncStatus = pgEnum('gofrugal_sync_status', [
  'not_required', // e.g. cancelled before confirmation
  'pending',
  'in_progress',
  'synced',
  'failed', // exhausted retries → needs manual action in admin
]);

export const syncRunStatus = pgEnum('sync_run_status', ['idle', 'running', 'success', 'failed']);

/** Back-office roles (Jeya Staff app) — separate from customer accounts. */
export const staffRole = pgEnum('staff_role', ['staff', 'admin']);

export const alertLevel = pgEnum('alert_level', ['info', 'warning', 'critical']);

/* ───────────────────────────── Users & auth ───────────────────────────── */

export const users = pgTable(
  'users',
  {
    id: uuid().primaryKey().defaultRandom(),
    /** E.164 without '+', e.g. 919876543210. */
    phone: varchar({ length: 15 }).notNull(),
    name: varchar({ length: 120 }),
    email: varchar({ length: 254 }),
    role: userRole().notNull().default('customer'),
    fcmToken: text(),
    isBlocked: boolean().notNull().default(false),
    lastLoginAt: tstz(),
    ...timestamps,
    /** Soft-delete for store-mandated account deletion; PII is scrubbed by the service. */
    deletedAt: tstz(),
  },
  (t) => [
    // A deleted account must not block the same phone from signing up again.
    uniqueIndex('users_phone_active_uq').on(t.phone).where(sql`${t.deletedAt} IS NULL`),
    index('users_role_idx').on(t.role),
    check('users_phone_digits_ck', sql`${t.phone} ~ '^[0-9]{10,15}$'`),
  ],
);

export const userSessions = pgTable(
  'user_sessions',
  {
    id: uuid().primaryKey().defaultRandom(),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** SHA-256 of the refresh token — the raw token is never stored. */
    refreshTokenHash: varchar({ length: 64 }).notNull(),
    /** The token this one replaced, still honoured for a short grace window (app closed mid-refresh). */
    previousRefreshTokenHash: varchar({ length: 64 }),
    rotatedAt: tstz(),
    deviceId: varchar({ length: 128 }),
    deviceInfo: varchar({ length: 255 }),
    ipAddress: varchar({ length: 45 }),
    expiresAt: tstz().notNull(),
    revokedAt: tstz(),
    lastUsedAt: tstz(),
    createdAt: tstz().notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('user_sessions_token_hash_uq').on(t.refreshTokenHash),
    index('user_sessions_prev_token_hash_idx').on(t.previousRefreshTokenHash),
    index('user_sessions_user_idx').on(t.userId),
  ],
);

export const otpRequests = pgTable(
  'otp_requests',
  {
    id: uuid().primaryKey().defaultRandom(),
    phone: varchar({ length: 15 }).notNull(),
    /** HMAC/SHA-256 of the OTP — never store the plain code. */
    otpHash: varchar({ length: 64 }).notNull(),
    channel: otpChannel().notNull(),
    /** Wrong guesses against this OTP; service locks it at a threshold. */
    attempts: smallint().notNull().default(0),
    providerMessageId: varchar({ length: 128 }),
    ipAddress: varchar({ length: 45 }),
    expiresAt: tstz().notNull(),
    consumedAt: tstz(),
    createdAt: tstz().notNull().defaultNow(),
  },
  (t) => [
    // Rate-limit lookups: "how many OTPs for this phone in the last N minutes".
    index('otp_requests_phone_created_idx').on(t.phone, t.createdAt.desc()),
    index('otp_requests_ip_created_idx').on(t.ipAddress, t.createdAt.desc()),
    check('otp_requests_attempts_ck', sql`${t.attempts} >= 0`),
  ],
);

/* ───────────────────────────── Staff (Jeya Staff app) ───────────────────────────── */

/**
 * Store staff and admins. Deliberately separate from `users` (customers): different
 * login (username + password), different JWT audience, no customer data mixed in.
 */
export const staffUsers = pgTable(
  'staff_users',
  {
    id: uuid().primaryKey().defaultRandom(),
    /** Lower-case login name, e.g. "ravi.packing". */
    username: varchar({ length: 40 }).notNull(),
    name: varchar({ length: 120 }).notNull(),
    phone: varchar({ length: 15 }),
    role: staffRole().notNull().default('staff'),
    /** scrypt$N$r$p$salt$hash — never the password itself. */
    passwordHash: text().notNull(),
    /** Set when an admin creates the account or resets the password. */
    mustChangePassword: boolean().notNull().default(true),
    passwordChangedAt: tstz(),
    isActive: boolean().notNull().default(true),
    failedLoginCount: smallint().notNull().default(0),
    lockedUntil: tstz(),
    lastLoginAt: tstz(),
    createdBy: uuid().references((): AnyPgColumn => staffUsers.id, { onDelete: 'set null' }),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('staff_users_username_uq').on(t.username),
    check('staff_users_username_ck', sql`${t.username} ~ '^[a-z0-9][a-z0-9._-]{2,39}$'`),
    check('staff_users_failed_ck', sql`${t.failedLoginCount} >= 0`),
  ],
);

export const staffSessions = pgTable(
  'staff_sessions',
  {
    id: uuid().primaryKey().defaultRandom(),
    staffId: uuid()
      .notNull()
      .references(() => staffUsers.id, { onDelete: 'cascade' }),
    refreshTokenHash: varchar({ length: 64 }).notNull(),
    /** The token this one replaced, still honoured for a short grace window (app closed mid-refresh). */
    previousRefreshTokenHash: varchar({ length: 64 }),
    rotatedAt: tstz(),
    deviceInfo: varchar({ length: 255 }),
    ipAddress: varchar({ length: 45 }),
    expiresAt: tstz().notNull(),
    revokedAt: tstz(),
    lastUsedAt: tstz(),
    createdAt: tstz().notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('staff_sessions_token_hash_uq').on(t.refreshTokenHash),
    index('staff_sessions_prev_token_hash_idx').on(t.previousRefreshTokenHash),
    index('staff_sessions_staff_idx').on(t.staffId),
  ],
);

/* ───────────────────────────── Addresses & serviceability ───────────────────────────── */

export const serviceablePincodes = pgTable(
  'serviceable_pincodes',
  {
    pincode: varchar({ length: 6 }).primaryKey(),
    areaName: varchar({ length: 120 }).notNull(),
    deliveryFee: money().notNull().default('0'),
    minOrderAmount: money().notNull().default('0'),
    freeDeliveryAbove: money(),
    isActive: boolean().notNull().default(true),
    ...timestamps,
  },
  (t) => [
    check('serviceable_pincodes_format_ck', sql`${t.pincode} ~ '^[1-9][0-9]{5}$'`),
    check('serviceable_pincodes_fee_ck', sql`${t.deliveryFee} >= 0 AND ${t.minOrderAmount} >= 0`),
  ],
);

export const addresses = pgTable(
  'addresses',
  {
    id: uuid().primaryKey().defaultRandom(),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    label: varchar({ length: 30 }), // "Home", "Shop"
    recipientName: varchar({ length: 120 }).notNull(),
    phone: varchar({ length: 15 }).notNull(),
    pincode: varchar({ length: 6 }).notNull(),
    line1: varchar({ length: 255 }).notNull(),
    line2: varchar({ length: 255 }),
    landmark: varchar({ length: 255 }),
    city: varchar({ length: 100 }).notNull(),
    state: varchar({ length: 100 }).notNull().default('Tamil Nadu'),
    latitude: numeric({ precision: 9, scale: 6 }),
    longitude: numeric({ precision: 9, scale: 6 }),
    isDefault: boolean().notNull().default(false),
    ...timestamps,
    deletedAt: tstz(),
  },
  (t) => [
    index('addresses_user_idx').on(t.userId).where(sql`${t.deletedAt} IS NULL`),
    // Exactly one default address per user (among non-deleted).
    uniqueIndex('addresses_one_default_per_user_uq')
      .on(t.userId)
      .where(sql`${t.isDefault} = true AND ${t.deletedAt} IS NULL`),
    check('addresses_pincode_ck', sql`${t.pincode} ~ '^[1-9][0-9]{5}$'`),
  ],
);

/* ───────────────────────────── Catalog ───────────────────────────── */

export const categories = pgTable(
  'categories',
  {
    id: integer().primaryKey().generatedAlwaysAsIdentity(),
    gofrugalCatId: varchar({ length: 64 }),
    name: varchar({ length: 150 }).notNull(),
    slug: varchar({ length: 170 }).notNull(),
    parentId: integer().references((): AnyPgColumn => categories.id, { onDelete: 'set null' }),
    imageUrl: text(),
    sortOrder: integer().notNull().default(0),
    isActive: boolean().notNull().default(true),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('categories_gofrugal_cat_id_uq').on(t.gofrugalCatId),
    uniqueIndex('categories_slug_uq').on(t.slug),
    index('categories_parent_idx').on(t.parentId, t.sortOrder),
    check('categories_not_own_parent_ck', sql`${t.parentId} IS NULL OR ${t.parentId} <> ${t.id}`),
  ],
);

export const products = pgTable(
  'products',
  {
    id: bigint({ mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
    gofrugalItemId: varchar({ length: 64 }).notNull(),
    itemCode: varchar({ length: 64 }).notNull(),
    barcode: varchar({ length: 64 }),
    name: varchar({ length: 255 }).notNull(),
    /** Tamil display name for search & UI; optional. */
    nameTa: varchar({ length: 255 }),
    slug: varchar({ length: 300 }).notNull(),
    brand: varchar({ length: 120 }),
    categoryId: integer().references(() => categories.id, { onDelete: 'set null' }),
    description: text(),

    mrp: money().notNull(),
    sellingPrice: money().notNull(),
    hsnCode: varchar({ length: 10 }),
    gstRate: numeric({ precision: 5, scale: 2 }).notNull().default('0'),

    /** Raw stock from GoFrugal. Can be negative — POS allows it, so no CHECK here. */
    stockQuantity: quantity().notNull().default('0'),
    /** Qty held by our open orders that GoFrugal hasn't billed yet. */
    reservedQuantity: quantity().notNull().default('0'),
    /** Treated as out-of-stock below this, to absorb the 15-min sync lag. */
    safetyStock: quantity().notNull().default('0'),

    unit: productUnit().notNull().default('pcs'),
    /** Pack size label shown to customers, e.g. "500 g", "1 L". */
    packSize: varchar({ length: 40 }),
    /** Sold by weight; packed qty may differ from ordered qty. */
    isLoose: boolean().notNull().default(false),
    minOrderQty: quantity().notNull().default('1'),
    qtyStep: quantity().notNull().default('1'),
    maxOrderQty: quantity(),

    imageUrl: text(),
    isActive: boolean().notNull().default(true),
    /** Pin popular SKUs to the top of listings. */
    sortRank: integer().notNull().default(0),

    /** GoFrugal's own last-modified timestamp (drives delta sync). */
    gofrugalUpdatedAt: tstz(),
    syncedAt: tstz(),
    ...timestamps,

    searchVector: tsvector()
      .notNull()
      .generatedAlwaysAs(
        // Raw column names on purpose: generated-column expressions can't be table-qualified.
        (): SQL => sql`
          setweight(to_tsvector('simple'::regconfig, coalesce("name", '')), 'A') ||
          setweight(to_tsvector('simple'::regconfig, coalesce("name_ta", '')), 'A') ||
          setweight(to_tsvector('simple'::regconfig, coalesce("brand", '')), 'B') ||
          setweight(to_tsvector('simple'::regconfig, coalesce("item_code", '')), 'C') ||
          setweight(to_tsvector('simple'::regconfig, coalesce("barcode", '')), 'C')`,
      ),
  },
  (t) => [
    uniqueIndex('products_gofrugal_item_id_uq').on(t.gofrugalItemId),
    uniqueIndex('products_slug_uq').on(t.slug),
    index('products_item_code_idx').on(t.itemCode),
    index('products_barcode_idx').on(t.barcode),
    // Category listing: WHERE category_id = ? AND is_active ORDER BY sort_rank DESC, name
    index('products_category_listing_idx')
      .on(t.categoryId, t.sortRank.desc(), t.name)
      .where(sql`${t.isActive} = true`),
    index('products_search_vector_idx').using('gin', t.searchVector),
    // Typo-tolerant search ("tomatto", "basmathi"); needs the pg_trgm extension.
    index('products_name_trgm_idx').using('gin', sql`${t.name} gin_trgm_ops`),
    index('products_updated_at_idx').on(t.updatedAt),
    check('products_prices_ck', sql`${t.mrp} >= 0 AND ${t.sellingPrice} >= 0`),
    check('products_gst_rate_ck', sql`${t.gstRate} >= 0 AND ${t.gstRate} <= 28`),
    check('products_reserved_ck', sql`${t.reservedQuantity} >= 0`),
    check('products_order_qty_ck', sql`${t.minOrderQty} > 0 AND ${t.qtyStep} > 0`),
  ],
);

/* ───────────────────────────── Cart ───────────────────────────── */

export const cartItems = pgTable(
  'cart_items',
  {
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    productId: bigint({ mode: 'number' })
      .notNull()
      .references(() => products.id, { onDelete: 'cascade' }),
    quantity: quantity().notNull(),
    ...timestamps,
  },
  (t) => [
    primaryKey({ columns: [t.userId, t.productId] }),
    check('cart_items_quantity_ck', sql`${t.quantity} > 0`),
  ],
);

/* ───────────────────────────── Orders ───────────────────────────── */

/** Feeds the human-facing order number JHS-<yymmdd>-<seq>; gaps are fine. */
export const orderNumberSeq = pgSequence('order_number_seq', { startWith: 1001, increment: 1 });

/** Immutable copy of the address at checkout time — addresses get edited/deleted later. */
export type DeliveryAddressSnapshot = {
  recipientName: string;
  phone: string;
  pincode: string;
  line1: string;
  line2: string | null;
  landmark: string | null;
  city: string;
  state: string;
  latitude: string | null;
  longitude: string | null;
};

export const orders = pgTable(
  'orders',
  {
    id: uuid().primaryKey().defaultRandom(),
    /** Human-facing, e.g. JHS-261018-0042. */
    orderNumber: varchar({ length: 32 }).notNull(),
    userId: uuid()
      .notNull()
      .references(() => users.id, { onDelete: 'restrict' }),
    addressId: uuid().references(() => addresses.id, { onDelete: 'set null' }),
    deliveryAddress: jsonb().$type<DeliveryAddressSnapshot>().notNull(),

    subtotal: money().notNull(),
    discountAmount: money().notNull().default('0'),
    deliveryFee: money().notNull().default('0'),
    taxTotal: money().notNull().default('0'),
    totalAmount: money().notNull(),
    /** Set after packing when loose-item weights change the bill. */
    finalAmount: money(),

    paymentStatus: paymentStatus().notNull().default('pending'),
    paymentMethod: paymentMethod().notNull(),
    orderStatus: orderStatus().notNull().default('pending_payment'),

    /** Client-generated UUID per checkout attempt — double-taps return the same order. */
    idempotencyKey: varchar({ length: 64 }).notNull(),

    deliverySlotStart: tstz(),
    deliverySlotEnd: tstz(),
    customerNote: varchar({ length: 500 }),

    /** Stock reservation is released by a sweeper if payment isn't captured by this time. */
    reservationExpiresAt: tstz(),

    gofrugalSyncStatus: gofrugalSyncStatus().notNull().default('pending'),
    gofrugalBillNo: varchar({ length: 64 }),
    /** Our reference sent to GoFrugal; lets reconciliation detect bills created on a timed-out call. */
    gofrugalOrderRef: varchar({ length: 64 }),
    gofrugalSyncAttempts: smallint().notNull().default(0),
    gofrugalLastError: text(),
    gofrugalSyncedAt: tstz(),

    pdfUrl: text(),
    receiptSentAt: tstz(),

    cancelledReason: varchar({ length: 255 }),
    /** COD: cash the delivery staff confirmed collecting. */
    codCollectedAmount: money(),
    codCollectedAt: tstz(),
    codCollectedBy: uuid().references(() => staffUsers.id, { onDelete: 'set null' }),
    placedAt: tstz(),
    /** Delivery promised to the customer at checkout (end of that IST day); stored so later setting changes don't move it. */
    promisedBy: tstz(),
    deliveredAt: tstz(),
    cancelledAt: tstz(),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('orders_order_number_uq').on(t.orderNumber),
    uniqueIndex('orders_user_idempotency_uq').on(t.userId, t.idempotencyKey),
    uniqueIndex('orders_gofrugal_bill_no_uq').on(t.gofrugalBillNo),
    uniqueIndex('orders_gofrugal_order_ref_uq').on(t.gofrugalOrderRef),
    index('orders_user_created_idx').on(t.userId, t.createdAt.desc()),
    index('orders_status_created_idx').on(t.orderStatus, t.createdAt.desc()),
    // Worker queue scan: only rows that still need pushing to GoFrugal.
    index('orders_gofrugal_pending_idx')
      .on(t.gofrugalSyncStatus, t.updatedAt)
      .where(sql`${t.gofrugalSyncStatus} IN ('pending', 'in_progress', 'failed')`),
    // Reservation sweeper scan.
    index('orders_reservation_expiry_idx')
      .on(t.reservationExpiresAt)
      .where(sql`${t.orderStatus} = 'pending_payment'`),
    check(
      'orders_amounts_ck',
      sql`${t.subtotal} >= 0 AND ${t.discountAmount} >= 0 AND ${t.deliveryFee} >= 0
          AND ${t.taxTotal} >= 0 AND ${t.totalAmount} >= 0`,
    ),
    check(
      'orders_slot_ck',
      sql`${t.deliverySlotStart} IS NULL OR ${t.deliverySlotEnd} IS NULL OR ${t.deliverySlotEnd} > ${t.deliverySlotStart}`,
    ),
  ],
);

export const orderItems = pgTable(
  'order_items',
  {
    id: bigint({ mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
    orderId: uuid()
      .notNull()
      .references(() => orders.id, { onDelete: 'cascade' }),
    productId: bigint({ mode: 'number' })
      .notNull()
      .references(() => products.id, { onDelete: 'restrict' }),

    // Snapshot of the product at purchase time (prices/names change on every sync).
    itemCode: varchar({ length: 64 }).notNull(),
    gofrugalItemId: varchar({ length: 64 }).notNull(),
    productName: varchar({ length: 255 }).notNull(),
    unit: productUnit().notNull(),
    mrp: money().notNull(),
    unitPrice: money().notNull(),
    gstRate: numeric({ precision: 5, scale: 2 }).notNull().default('0'),
    hsnCode: varchar({ length: 10 }),

    quantity: quantity().notNull(),
    /** Actual packed qty for loose items / short-picks; NULL until packed. */
    packedQuantity: quantity(),
    totalPrice: money().notNull(),

    createdAt: tstz().notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('order_items_order_product_uq').on(t.orderId, t.productId),
    index('order_items_product_idx').on(t.productId),
    check('order_items_quantity_ck', sql`${t.quantity} > 0`),
    check('order_items_packed_ck', sql`${t.packedQuantity} IS NULL OR ${t.packedQuantity} >= 0`),
    check('order_items_prices_ck', sql`${t.unitPrice} >= 0 AND ${t.totalPrice} >= 0`),
  ],
);

export const orderStatusHistory = pgTable(
  'order_status_history',
  {
    id: bigint({ mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
    orderId: uuid()
      .notNull()
      .references(() => orders.id, { onDelete: 'cascade' }),
    fromStatus: orderStatus(),
    toStatus: orderStatus().notNull(),
    /** Customer who made the change (place / cancel). */
    changedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    /** Staff member who made the change. Both NULL = system (webhook, sweeper, sync). */
    changedByStaff: uuid().references(() => staffUsers.id, { onDelete: 'set null' }),
    note: varchar({ length: 500 }),
    createdAt: tstz().notNull().defaultNow(),
  },
  (t) => [index('order_status_history_order_idx').on(t.orderId, t.createdAt)],
);

/* ───────────────────────────── Payments ───────────────────────────── */

export const payments = pgTable(
  'payments',
  {
    id: uuid().primaryKey().defaultRandom(),
    orderId: uuid()
      .notNull()
      .references(() => orders.id, { onDelete: 'restrict' }),
    provider: paymentProvider().notNull(),
    /** Gateway order id (Razorpay `order_xxx` / Cashfree `order_id`). */
    providerOrderId: varchar({ length: 64 }).notNull(),
    providerPaymentId: varchar({ length: 64 }),
    amount: money().notNull(),
    currency: varchar({ length: 3 }).notNull().default('INR'),
    status: paymentAttemptStatus().notNull().default('created'),
    method: paymentMethod(),
    errorCode: varchar({ length: 64 }),
    errorDescription: text(),
    capturedAt: tstz(),
    /** Gateway's charge for this payment and the GST on it (from the captured payment entity). */
    gatewayFee: money(),
    gatewayTax: money(),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('payments_provider_order_uq').on(t.provider, t.providerOrderId),
    uniqueIndex('payments_provider_payment_uq').on(t.provider, t.providerPaymentId),
    index('payments_order_idx').on(t.orderId),
    // Reconciliation cron: attempts stuck before capture.
    index('payments_unsettled_idx')
      .on(t.createdAt)
      .where(sql`${t.status} IN ('created', 'authorized')`),
    check('payments_amount_ck', sql`${t.amount} > 0`),
  ],
);

export const paymentWebhookEvents = pgTable(
  'payment_webhook_events',
  {
    id: bigint({ mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
    provider: paymentProvider().notNull(),
    /** Gateway's event id (Razorpay `x-razorpay-event-id`) — dedupes retries. */
    eventId: varchar({ length: 128 }).notNull(),
    eventType: varchar({ length: 64 }).notNull(),
    payload: jsonb().notNull(),
    processedAt: tstz(),
    processingError: text(),
    receivedAt: tstz().notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('payment_webhook_events_event_uq').on(t.provider, t.eventId),
    index('payment_webhook_events_unprocessed_idx')
      .on(t.receivedAt)
      .where(sql`${t.processedAt} IS NULL`),
  ],
);

export const refunds = pgTable(
  'refunds',
  {
    id: uuid().primaryKey().defaultRandom(),
    paymentId: uuid()
      .notNull()
      .references(() => payments.id, { onDelete: 'restrict' }),
    orderId: uuid()
      .notNull()
      .references(() => orders.id, { onDelete: 'restrict' }),
    amount: money().notNull(),
    reason: varchar({ length: 255 }).notNull(),
    providerRefundId: varchar({ length: 64 }),
    status: refundStatus().notNull().default('pending'),
    initiatedBy: uuid().references(() => users.id, { onDelete: 'set null' }),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('refunds_provider_refund_uq').on(t.providerRefundId),
    index('refunds_order_idx').on(t.orderId),
    check('refunds_amount_ck', sql`${t.amount} > 0`),
  ],
);

/* ───────────────────────────── Sync & config ───────────────────────────── */

export const syncState = pgTable('sync_state', {
  /** e.g. 'gofrugal_items', 'gofrugal_categories', 'gofrugal_stock'. */
  key: varchar({ length: 64 }).primaryKey(),
  /** High-water mark sent as the "modified since" filter on the next delta pull. */
  watermark: tstz(),
  status: syncRunStatus().notNull().default('idle'),
  lastRunStartedAt: tstz(),
  lastRunFinishedAt: tstz(),
  lastSuccessAt: tstz(),
  lastError: text(),
  itemsProcessed: integer().notNull().default(0),
  consecutiveFailures: integer().notNull().default(0),
  updatedAt: tstz()
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});

/**
 * Remote config & feature flags served to the app — lets us flip payment keys,
 * the reviewer demo login, min app version, etc. without an app re-submission.
 */
export const appConfig = pgTable('app_config', {
  key: varchar({ length: 64 }).primaryKey(),
  value: jsonb().notNull(),
  /** Safe to expose via the public /config endpoint. */
  isPublic: boolean().notNull().default(false),
  description: varchar({ length: 255 }),
  updatedAt: tstz()
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});

/* ───────────────────────────── Usage & alerts (free-tier budget) ───────────────────────────── */

/**
 * One row per IST calendar day. Traffic columns are added to all day (wire bytes, TLS
 * included — see infra/traffic.ts); size columns hold the latest sample of the day.
 */
export const usageDaily = pgTable('usage_daily', {
  day: date({ mode: 'string' }).primaryKey(),
  /** Supabase → API (Supabase egress quota). */
  dbEgressBytes: bigint({ mode: 'number' }).notNull().default(0),
  /** API → Supabase (counts toward Render outbound). */
  dbIngressBytes: bigint({ mode: 'number' }).notNull().default(0),
  /** API → clients via Render's proxy (Render outbound). */
  httpOutBytes: bigint({ mode: 'number' }).notNull().default(0),
  httpInBytes: bigint({ mode: 'number' }).notNull().default(0),
  httpRequests: integer().notNull().default(0),
  /** API → R2 uploads (Render outbound) and the Class A operations we made. */
  r2UploadBytes: bigint({ mode: 'number' }).notNull().default(0),
  r2ClassAOps: integer().notNull().default(0),
  dbSizeBytes: bigint({ mode: 'number' }),
  r2StorageBytes: bigint({ mode: 'number' }),
  r2ObjectCount: integer(),
  peakRssBytes: bigint({ mode: 'number' }),
  updatedAt: tstz()
    .notNull()
    .defaultNow()
    .$onUpdate(() => new Date()),
});

/** Budget / health alerts for admins. At most one open (unresolved) alert per metric. */
export const adminAlerts = pgTable(
  'admin_alerts',
  {
    id: bigint({ mode: 'number' }).primaryKey().generatedAlwaysAsIdentity(),
    metric: varchar({ length: 64 }).notNull(),
    level: alertLevel().notNull(),
    title: varchar({ length: 160 }).notNull(),
    message: varchar({ length: 1000 }).notNull(),
    data: jsonb(),
    /** Last time this alert was pushed out (email); critical alerts repeat daily. */
    notifiedAt: tstz(),
    resolvedAt: tstz(),
    acknowledgedAt: tstz(),
    acknowledgedBy: uuid().references(() => staffUsers.id, { onDelete: 'set null' }),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('admin_alerts_open_metric_uq').on(t.metric).where(sql`${t.resolvedAt} IS NULL`),
    index('admin_alerts_created_idx').on(t.createdAt.desc()),
  ],
);

/* ───────────────────────────── Relations (for db.query.*) ───────────────────────────── */

export const usersRelations = relations(users, ({ many }) => ({
  addresses: many(addresses),
  sessions: many(userSessions),
  orders: many(orders),
  cartItems: many(cartItems),
}));

export const userSessionsRelations = relations(userSessions, ({ one }) => ({
  user: one(users, { fields: [userSessions.userId], references: [users.id] }),
}));

export const addressesRelations = relations(addresses, ({ one }) => ({
  user: one(users, { fields: [addresses.userId], references: [users.id] }),
}));

export const categoriesRelations = relations(categories, ({ one, many }) => ({
  parent: one(categories, {
    fields: [categories.parentId],
    references: [categories.id],
    relationName: 'category_parent',
  }),
  children: many(categories, { relationName: 'category_parent' }),
  products: many(products),
}));

export const productsRelations = relations(products, ({ one }) => ({
  category: one(categories, { fields: [products.categoryId], references: [categories.id] }),
}));

export const cartItemsRelations = relations(cartItems, ({ one }) => ({
  user: one(users, { fields: [cartItems.userId], references: [users.id] }),
  product: one(products, { fields: [cartItems.productId], references: [products.id] }),
}));

export const ordersRelations = relations(orders, ({ one, many }) => ({
  user: one(users, { fields: [orders.userId], references: [users.id] }),
  address: one(addresses, { fields: [orders.addressId], references: [addresses.id] }),
  items: many(orderItems),
  statusHistory: many(orderStatusHistory),
  payments: many(payments),
  refunds: many(refunds),
}));

export const orderItemsRelations = relations(orderItems, ({ one }) => ({
  order: one(orders, { fields: [orderItems.orderId], references: [orders.id] }),
  product: one(products, { fields: [orderItems.productId], references: [products.id] }),
}));

export const staffUsersRelations = relations(staffUsers, ({ many }) => ({
  sessions: many(staffSessions),
}));

export const staffSessionsRelations = relations(staffSessions, ({ one }) => ({
  staff: one(staffUsers, { fields: [staffSessions.staffId], references: [staffUsers.id] }),
}));

export const orderStatusHistoryRelations = relations(orderStatusHistory, ({ one }) => ({
  order: one(orders, { fields: [orderStatusHistory.orderId], references: [orders.id] }),
  changedByStaffUser: one(staffUsers, { fields: [orderStatusHistory.changedByStaff], references: [staffUsers.id] }),
  changedByUser: one(users, { fields: [orderStatusHistory.changedBy], references: [users.id] }),
}));

export const paymentsRelations = relations(payments, ({ one, many }) => ({
  order: one(orders, { fields: [payments.orderId], references: [orders.id] }),
  refunds: many(refunds),
}));

export const refundsRelations = relations(refunds, ({ one }) => ({
  payment: one(payments, { fields: [refunds.paymentId], references: [payments.id] }),
  order: one(orders, { fields: [refunds.orderId], references: [orders.id] }),
}));

/* ───────────────────────────── Inferred types ───────────────────────────── */

export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type UserSession = typeof userSessions.$inferSelect;
export type OtpRequest = typeof otpRequests.$inferSelect;
export type Address = typeof addresses.$inferSelect;
export type NewAddress = typeof addresses.$inferInsert;
export type ServiceablePincode = typeof serviceablePincodes.$inferSelect;
export type Category = typeof categories.$inferSelect;
export type NewCategory = typeof categories.$inferInsert;
export type Product = typeof products.$inferSelect;
export type NewProduct = typeof products.$inferInsert;
export type CartItem = typeof cartItems.$inferSelect;
export type Order = typeof orders.$inferSelect;
export type NewOrder = typeof orders.$inferInsert;
export type OrderItem = typeof orderItems.$inferSelect;
export type NewOrderItem = typeof orderItems.$inferInsert;
export type OrderStatusHistory = typeof orderStatusHistory.$inferSelect;
export type Payment = typeof payments.$inferSelect;
export type PaymentWebhookEvent = typeof paymentWebhookEvents.$inferSelect;
export type Refund = typeof refunds.$inferSelect;
export type SyncState = typeof syncState.$inferSelect;
export type AppConfig = typeof appConfig.$inferSelect;
export type StaffUser = typeof staffUsers.$inferSelect;
export type NewStaffUser = typeof staffUsers.$inferInsert;
export type StaffRole = (typeof staffRole.enumValues)[number];
export type UsageDaily = typeof usageDaily.$inferSelect;
export type AdminAlert = typeof adminAlerts.$inferSelect;
export type AlertLevel = (typeof alertLevel.enumValues)[number];

export type OrderStatus = (typeof orderStatus.enumValues)[number];
export type PaymentStatus = (typeof paymentStatus.enumValues)[number];
export type PaymentMethod = (typeof paymentMethod.enumValues)[number];
export type UserRole = (typeof userRole.enumValues)[number];
