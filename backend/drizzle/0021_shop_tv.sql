CREATE TABLE "shop_media" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"kind" varchar(16) NOT NULL,
	"media_type" varchar(8) NOT NULL,
	"title" varchar(120) NOT NULL,
	"url" text NOT NULL,
	"content_type" varchar(60) NOT NULL,
	"bytes" integer NOT NULL,
	"duration_ms" integer,
	"aspect" numeric(6, 3),
	"is_active" boolean DEFAULT true NOT NULL,
	"starts_on" date,
	"ends_on" date,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "shop_screens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" varchar(60) DEFAULT 'Shop TV' NOT NULL,
	"device_key_hash" varchar(64) NOT NULL,
	"pair_code" varchar(6),
	"pair_code_expires_at" timestamp with time zone,
	"paired_at" timestamp with time zone,
	"last_seen_at" timestamp with time zone,
	"status" jsonb,
	"app_version" varchar(20),
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "shop_media" ADD CONSTRAINT "shop_media_created_by_staff_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."staff_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "shop_media_active_idx" ON "shop_media" USING btree ("is_active","sort_order");--> statement-breakpoint
CREATE UNIQUE INDEX "shop_screens_device_uq" ON "shop_screens" USING btree ("device_key_hash");--> statement-breakpoint
CREATE UNIQUE INDEX "shop_screens_code_uq" ON "shop_screens" USING btree ("pair_code");