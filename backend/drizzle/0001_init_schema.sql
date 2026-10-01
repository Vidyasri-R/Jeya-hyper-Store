CREATE TYPE "public"."gofrugal_sync_status" AS ENUM('not_required', 'pending', 'in_progress', 'synced', 'failed');--> statement-breakpoint
CREATE TYPE "public"."order_status" AS ENUM('pending_payment', 'placed', 'confirmed', 'packing', 'ready_for_delivery', 'out_for_delivery', 'delivered', 'cancelled', 'payment_failed');--> statement-breakpoint
CREATE TYPE "public"."otp_channel" AS ENUM('whatsapp', 'sms');--> statement-breakpoint
CREATE TYPE "public"."payment_attempt_status" AS ENUM('created', 'authorized', 'captured', 'failed');--> statement-breakpoint
CREATE TYPE "public"."payment_method" AS ENUM('upi', 'card', 'netbanking', 'wallet', 'cod');--> statement-breakpoint
CREATE TYPE "public"."payment_provider" AS ENUM('razorpay', 'cashfree');--> statement-breakpoint
CREATE TYPE "public"."payment_status" AS ENUM('pending', 'paid', 'failed', 'partially_refunded', 'refunded');--> statement-breakpoint
CREATE TYPE "public"."product_unit" AS ENUM('pcs', 'kg', 'g', 'l', 'ml', 'pack', 'dozen');--> statement-breakpoint
CREATE TYPE "public"."refund_status" AS ENUM('pending', 'processed', 'failed');--> statement-breakpoint
CREATE TYPE "public"."sync_run_status" AS ENUM('idle', 'running', 'success', 'failed');--> statement-breakpoint
CREATE TYPE "public"."user_role" AS ENUM('customer', 'staff', 'admin');--> statement-breakpoint
CREATE TABLE "addresses" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"label" varchar(30),
	"recipient_name" varchar(120) NOT NULL,
	"phone" varchar(15) NOT NULL,
	"pincode" varchar(6) NOT NULL,
	"line1" varchar(255) NOT NULL,
	"line2" varchar(255),
	"landmark" varchar(255),
	"city" varchar(100) NOT NULL,
	"state" varchar(100) DEFAULT 'Tamil Nadu' NOT NULL,
	"latitude" numeric(9, 6),
	"longitude" numeric(9, 6),
	"is_default" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "addresses_pincode_ck" CHECK ("addresses"."pincode" ~ '^[1-9][0-9]{5}$')
);
--> statement-breakpoint
CREATE TABLE "app_config" (
	"key" varchar(64) PRIMARY KEY NOT NULL,
	"value" jsonb NOT NULL,
	"is_public" boolean DEFAULT false NOT NULL,
	"description" varchar(255),
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "cart_items" (
	"user_id" uuid NOT NULL,
	"product_id" bigint NOT NULL,
	"quantity" numeric(12, 3) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "cart_items_user_id_product_id_pk" PRIMARY KEY("user_id","product_id"),
	CONSTRAINT "cart_items_quantity_ck" CHECK ("cart_items"."quantity" > 0)
);
--> statement-breakpoint
CREATE TABLE "categories" (
	"id" integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "categories_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START WITH 1 CACHE 1),
	"gofrugal_cat_id" varchar(64),
	"name" varchar(150) NOT NULL,
	"slug" varchar(170) NOT NULL,
	"parent_id" integer,
	"image_url" text,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "categories_not_own_parent_ck" CHECK ("categories"."parent_id" IS NULL OR "categories"."parent_id" <> "categories"."id")
);
--> statement-breakpoint
CREATE TABLE "order_items" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "order_items_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"order_id" uuid NOT NULL,
	"product_id" bigint NOT NULL,
	"item_code" varchar(64) NOT NULL,
	"gofrugal_item_id" varchar(64) NOT NULL,
	"product_name" varchar(255) NOT NULL,
	"unit" "product_unit" NOT NULL,
	"mrp" numeric(12, 2) NOT NULL,
	"unit_price" numeric(12, 2) NOT NULL,
	"gst_rate" numeric(5, 2) DEFAULT '0' NOT NULL,
	"hsn_code" varchar(10),
	"quantity" numeric(12, 3) NOT NULL,
	"packed_quantity" numeric(12, 3),
	"total_price" numeric(12, 2) NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "order_items_quantity_ck" CHECK ("order_items"."quantity" > 0),
	CONSTRAINT "order_items_packed_ck" CHECK ("order_items"."packed_quantity" IS NULL OR "order_items"."packed_quantity" >= 0),
	CONSTRAINT "order_items_prices_ck" CHECK ("order_items"."unit_price" >= 0 AND "order_items"."total_price" >= 0)
);
--> statement-breakpoint
CREATE TABLE "order_status_history" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "order_status_history_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"order_id" uuid NOT NULL,
	"from_status" "order_status",
	"to_status" "order_status" NOT NULL,
	"changed_by" uuid,
	"note" varchar(500),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"order_number" varchar(32) NOT NULL,
	"user_id" uuid NOT NULL,
	"address_id" uuid,
	"delivery_address" jsonb NOT NULL,
	"subtotal" numeric(12, 2) NOT NULL,
	"discount_amount" numeric(12, 2) DEFAULT '0' NOT NULL,
	"delivery_fee" numeric(12, 2) DEFAULT '0' NOT NULL,
	"tax_total" numeric(12, 2) DEFAULT '0' NOT NULL,
	"total_amount" numeric(12, 2) NOT NULL,
	"final_amount" numeric(12, 2),
	"payment_status" "payment_status" DEFAULT 'pending' NOT NULL,
	"payment_method" "payment_method" NOT NULL,
	"order_status" "order_status" DEFAULT 'pending_payment' NOT NULL,
	"idempotency_key" varchar(64) NOT NULL,
	"delivery_slot_start" timestamp with time zone,
	"delivery_slot_end" timestamp with time zone,
	"customer_note" varchar(500),
	"reservation_expires_at" timestamp with time zone,
	"gofrugal_sync_status" "gofrugal_sync_status" DEFAULT 'pending' NOT NULL,
	"gofrugal_bill_no" varchar(64),
	"gofrugal_order_ref" varchar(64),
	"gofrugal_sync_attempts" smallint DEFAULT 0 NOT NULL,
	"gofrugal_last_error" text,
	"gofrugal_synced_at" timestamp with time zone,
	"pdf_url" text,
	"receipt_sent_at" timestamp with time zone,
	"cancelled_reason" varchar(255),
	"placed_at" timestamp with time zone,
	"delivered_at" timestamp with time zone,
	"cancelled_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "orders_amounts_ck" CHECK ("orders"."subtotal" >= 0 AND "orders"."discount_amount" >= 0 AND "orders"."delivery_fee" >= 0
          AND "orders"."tax_total" >= 0 AND "orders"."total_amount" >= 0),
	CONSTRAINT "orders_slot_ck" CHECK ("orders"."delivery_slot_start" IS NULL OR "orders"."delivery_slot_end" IS NULL OR "orders"."delivery_slot_end" > "orders"."delivery_slot_start")
);
--> statement-breakpoint
CREATE TABLE "otp_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phone" varchar(15) NOT NULL,
	"otp_hash" varchar(64) NOT NULL,
	"channel" "otp_channel" NOT NULL,
	"attempts" smallint DEFAULT 0 NOT NULL,
	"provider_message_id" varchar(128),
	"ip_address" varchar(45),
	"expires_at" timestamp with time zone NOT NULL,
	"consumed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "otp_requests_attempts_ck" CHECK ("otp_requests"."attempts" >= 0)
);
--> statement-breakpoint
CREATE TABLE "payment_webhook_events" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "payment_webhook_events_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"provider" "payment_provider" NOT NULL,
	"event_id" varchar(128) NOT NULL,
	"event_type" varchar(64) NOT NULL,
	"payload" jsonb NOT NULL,
	"processed_at" timestamp with time zone,
	"processing_error" text,
	"received_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "payments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"order_id" uuid NOT NULL,
	"provider" "payment_provider" NOT NULL,
	"provider_order_id" varchar(64) NOT NULL,
	"provider_payment_id" varchar(64),
	"amount" numeric(12, 2) NOT NULL,
	"currency" varchar(3) DEFAULT 'INR' NOT NULL,
	"status" "payment_attempt_status" DEFAULT 'created' NOT NULL,
	"method" "payment_method",
	"error_code" varchar(64),
	"error_description" text,
	"captured_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "payments_amount_ck" CHECK ("payments"."amount" > 0)
);
--> statement-breakpoint
CREATE TABLE "products" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "products_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"gofrugal_item_id" varchar(64) NOT NULL,
	"item_code" varchar(64) NOT NULL,
	"barcode" varchar(64),
	"name" varchar(255) NOT NULL,
	"name_ta" varchar(255),
	"slug" varchar(300) NOT NULL,
	"brand" varchar(120),
	"category_id" integer,
	"description" text,
	"mrp" numeric(12, 2) NOT NULL,
	"selling_price" numeric(12, 2) NOT NULL,
	"hsn_code" varchar(10),
	"gst_rate" numeric(5, 2) DEFAULT '0' NOT NULL,
	"stock_quantity" numeric(12, 3) DEFAULT '0' NOT NULL,
	"reserved_quantity" numeric(12, 3) DEFAULT '0' NOT NULL,
	"safety_stock" numeric(12, 3) DEFAULT '0' NOT NULL,
	"unit" "product_unit" DEFAULT 'pcs' NOT NULL,
	"pack_size" varchar(40),
	"is_loose" boolean DEFAULT false NOT NULL,
	"min_order_qty" numeric(12, 3) DEFAULT '1' NOT NULL,
	"qty_step" numeric(12, 3) DEFAULT '1' NOT NULL,
	"max_order_qty" numeric(12, 3),
	"image_url" text,
	"is_active" boolean DEFAULT true NOT NULL,
	"sort_rank" integer DEFAULT 0 NOT NULL,
	"gofrugal_updated_at" timestamp with time zone,
	"synced_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"search_vector" "tsvector" GENERATED ALWAYS AS (
          setweight(to_tsvector('simple'::regconfig, coalesce("name", '')), 'A') ||
          setweight(to_tsvector('simple'::regconfig, coalesce("name_ta", '')), 'A') ||
          setweight(to_tsvector('simple'::regconfig, coalesce("brand", '')), 'B') ||
          setweight(to_tsvector('simple'::regconfig, coalesce("item_code", '')), 'C') ||
          setweight(to_tsvector('simple'::regconfig, coalesce("barcode", '')), 'C')) STORED NOT NULL,
	CONSTRAINT "products_prices_ck" CHECK ("products"."mrp" >= 0 AND "products"."selling_price" >= 0),
	CONSTRAINT "products_gst_rate_ck" CHECK ("products"."gst_rate" >= 0 AND "products"."gst_rate" <= 28),
	CONSTRAINT "products_reserved_ck" CHECK ("products"."reserved_quantity" >= 0),
	CONSTRAINT "products_order_qty_ck" CHECK ("products"."min_order_qty" > 0 AND "products"."qty_step" > 0)
);
--> statement-breakpoint
CREATE TABLE "refunds" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"payment_id" uuid NOT NULL,
	"order_id" uuid NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"reason" varchar(255) NOT NULL,
	"provider_refund_id" varchar(64),
	"status" "refund_status" DEFAULT 'pending' NOT NULL,
	"initiated_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "refunds_amount_ck" CHECK ("refunds"."amount" > 0)
);
--> statement-breakpoint
CREATE TABLE "serviceable_pincodes" (
	"pincode" varchar(6) PRIMARY KEY NOT NULL,
	"area_name" varchar(120) NOT NULL,
	"delivery_fee" numeric(12, 2) DEFAULT '0' NOT NULL,
	"min_order_amount" numeric(12, 2) DEFAULT '0' NOT NULL,
	"free_delivery_above" numeric(12, 2),
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "serviceable_pincodes_format_ck" CHECK ("serviceable_pincodes"."pincode" ~ '^[1-9][0-9]{5}$'),
	CONSTRAINT "serviceable_pincodes_fee_ck" CHECK ("serviceable_pincodes"."delivery_fee" >= 0 AND "serviceable_pincodes"."min_order_amount" >= 0)
);
--> statement-breakpoint
CREATE TABLE "sync_state" (
	"key" varchar(64) PRIMARY KEY NOT NULL,
	"watermark" timestamp with time zone,
	"status" "sync_run_status" DEFAULT 'idle' NOT NULL,
	"last_run_started_at" timestamp with time zone,
	"last_run_finished_at" timestamp with time zone,
	"last_success_at" timestamp with time zone,
	"last_error" text,
	"items_processed" integer DEFAULT 0 NOT NULL,
	"consecutive_failures" integer DEFAULT 0 NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "user_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"refresh_token_hash" varchar(64) NOT NULL,
	"device_id" varchar(128),
	"device_info" varchar(255),
	"ip_address" varchar(45),
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"last_used_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"phone" varchar(15) NOT NULL,
	"name" varchar(120),
	"email" varchar(254),
	"role" "user_role" DEFAULT 'customer' NOT NULL,
	"fcm_token" text,
	"is_blocked" boolean DEFAULT false NOT NULL,
	"last_login_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "users_phone_digits_ck" CHECK ("users"."phone" ~ '^[0-9]{10,15}$')
);
--> statement-breakpoint
ALTER TABLE "addresses" ADD CONSTRAINT "addresses_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cart_items" ADD CONSTRAINT "cart_items_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "cart_items" ADD CONSTRAINT "cart_items_product_id_products_id_fk" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "categories" ADD CONSTRAINT "categories_parent_id_categories_id_fk" FOREIGN KEY ("parent_id") REFERENCES "public"."categories"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_product_id_products_id_fk" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_changed_by_users_id_fk" FOREIGN KEY ("changed_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "orders" ADD CONSTRAINT "orders_address_id_addresses_id_fk" FOREIGN KEY ("address_id") REFERENCES "public"."addresses"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payments" ADD CONSTRAINT "payments_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "products" ADD CONSTRAINT "products_category_id_categories_id_fk" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_payment_id_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."payments"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE restrict ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_initiated_by_users_id_fk" FOREIGN KEY ("initiated_by") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_sessions" ADD CONSTRAINT "user_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "addresses_user_idx" ON "addresses" USING btree ("user_id") WHERE "addresses"."deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "addresses_one_default_per_user_uq" ON "addresses" USING btree ("user_id") WHERE "addresses"."is_default" = true AND "addresses"."deleted_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "categories_gofrugal_cat_id_uq" ON "categories" USING btree ("gofrugal_cat_id");--> statement-breakpoint
CREATE UNIQUE INDEX "categories_slug_uq" ON "categories" USING btree ("slug");--> statement-breakpoint
CREATE INDEX "categories_parent_idx" ON "categories" USING btree ("parent_id","sort_order");--> statement-breakpoint
CREATE UNIQUE INDEX "order_items_order_product_uq" ON "order_items" USING btree ("order_id","product_id");--> statement-breakpoint
CREATE INDEX "order_items_product_idx" ON "order_items" USING btree ("product_id");--> statement-breakpoint
CREATE INDEX "order_status_history_order_idx" ON "order_status_history" USING btree ("order_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "orders_order_number_uq" ON "orders" USING btree ("order_number");--> statement-breakpoint
CREATE UNIQUE INDEX "orders_user_idempotency_uq" ON "orders" USING btree ("user_id","idempotency_key");--> statement-breakpoint
CREATE UNIQUE INDEX "orders_gofrugal_bill_no_uq" ON "orders" USING btree ("gofrugal_bill_no");--> statement-breakpoint
CREATE UNIQUE INDEX "orders_gofrugal_order_ref_uq" ON "orders" USING btree ("gofrugal_order_ref");--> statement-breakpoint
CREATE INDEX "orders_user_created_idx" ON "orders" USING btree ("user_id","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "orders_status_created_idx" ON "orders" USING btree ("order_status","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "orders_gofrugal_pending_idx" ON "orders" USING btree ("gofrugal_sync_status","updated_at") WHERE "orders"."gofrugal_sync_status" IN ('pending', 'in_progress', 'failed');--> statement-breakpoint
CREATE INDEX "orders_reservation_expiry_idx" ON "orders" USING btree ("reservation_expires_at") WHERE "orders"."order_status" = 'pending_payment';--> statement-breakpoint
CREATE INDEX "otp_requests_phone_created_idx" ON "otp_requests" USING btree ("phone","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "otp_requests_ip_created_idx" ON "otp_requests" USING btree ("ip_address","created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE UNIQUE INDEX "payment_webhook_events_event_uq" ON "payment_webhook_events" USING btree ("provider","event_id");--> statement-breakpoint
CREATE INDEX "payment_webhook_events_unprocessed_idx" ON "payment_webhook_events" USING btree ("received_at") WHERE "payment_webhook_events"."processed_at" IS NULL;--> statement-breakpoint
CREATE UNIQUE INDEX "payments_provider_order_uq" ON "payments" USING btree ("provider","provider_order_id");--> statement-breakpoint
CREATE UNIQUE INDEX "payments_provider_payment_uq" ON "payments" USING btree ("provider","provider_payment_id");--> statement-breakpoint
CREATE INDEX "payments_order_idx" ON "payments" USING btree ("order_id");--> statement-breakpoint
CREATE INDEX "payments_unsettled_idx" ON "payments" USING btree ("created_at") WHERE "payments"."status" IN ('created', 'authorized');--> statement-breakpoint
CREATE UNIQUE INDEX "products_gofrugal_item_id_uq" ON "products" USING btree ("gofrugal_item_id");--> statement-breakpoint
CREATE UNIQUE INDEX "products_slug_uq" ON "products" USING btree ("slug");--> statement-breakpoint
CREATE INDEX "products_item_code_idx" ON "products" USING btree ("item_code");--> statement-breakpoint
CREATE INDEX "products_barcode_idx" ON "products" USING btree ("barcode");--> statement-breakpoint
CREATE INDEX "products_category_listing_idx" ON "products" USING btree ("category_id","sort_rank" DESC NULLS LAST,"name") WHERE "products"."is_active" = true;--> statement-breakpoint
CREATE INDEX "products_search_vector_idx" ON "products" USING gin ("search_vector");--> statement-breakpoint
CREATE INDEX "products_name_trgm_idx" ON "products" USING gin ("name" gin_trgm_ops);--> statement-breakpoint
CREATE INDEX "products_updated_at_idx" ON "products" USING btree ("updated_at");--> statement-breakpoint
CREATE UNIQUE INDEX "refunds_provider_refund_uq" ON "refunds" USING btree ("provider_refund_id");--> statement-breakpoint
CREATE INDEX "refunds_order_idx" ON "refunds" USING btree ("order_id");--> statement-breakpoint
CREATE UNIQUE INDEX "user_sessions_token_hash_uq" ON "user_sessions" USING btree ("refresh_token_hash");--> statement-breakpoint
CREATE INDEX "user_sessions_user_idx" ON "user_sessions" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "users_phone_active_uq" ON "users" USING btree ("phone") WHERE "users"."deleted_at" IS NULL;--> statement-breakpoint
CREATE INDEX "users_role_idx" ON "users" USING btree ("role");