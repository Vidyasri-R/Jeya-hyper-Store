CREATE TABLE "staff_alert_devices" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "staff_alert_devices_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"staff_id" uuid NOT NULL,
	"kind" varchar(16) NOT NULL,
	"key_hash" varchar(64),
	"endpoint" text,
	"p256dh" text,
	"auth" text,
	"label" varchar(160),
	"last_seen_at" timestamp with time zone,
	"failures" smallint DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "orders" ADD COLUMN "alerted_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "staff_alert_devices" ADD CONSTRAINT "staff_alert_devices_staff_id_staff_users_id_fk" FOREIGN KEY ("staff_id") REFERENCES "public"."staff_users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "staff_alert_devices_key_hash_uq" ON "staff_alert_devices" USING btree ("key_hash");--> statement-breakpoint
CREATE UNIQUE INDEX "staff_alert_devices_endpoint_uq" ON "staff_alert_devices" USING btree ("endpoint");--> statement-breakpoint
CREATE INDEX "staff_alert_devices_staff_idx" ON "staff_alert_devices" USING btree ("staff_id");--> statement-breakpoint
CREATE INDEX "orders_alerted_idx" ON "orders" USING btree ("alerted_at");--> statement-breakpoint
-- Orders from before alerts existed are not announced again.
UPDATE "orders" SET "alerted_at" = COALESCE("placed_at", "created_at") WHERE "order_status" <> 'pending_payment';
