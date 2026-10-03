CREATE TYPE "public"."alert_level" AS ENUM('info', 'warning', 'critical');--> statement-breakpoint
CREATE TABLE "admin_alerts" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "admin_alerts_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"metric" varchar(64) NOT NULL,
	"level" "alert_level" NOT NULL,
	"title" varchar(160) NOT NULL,
	"message" varchar(1000) NOT NULL,
	"data" jsonb,
	"notified_at" timestamp with time zone,
	"resolved_at" timestamp with time zone,
	"acknowledged_at" timestamp with time zone,
	"acknowledged_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "usage_daily" (
	"day" date PRIMARY KEY NOT NULL,
	"db_egress_bytes" bigint DEFAULT 0 NOT NULL,
	"db_ingress_bytes" bigint DEFAULT 0 NOT NULL,
	"http_out_bytes" bigint DEFAULT 0 NOT NULL,
	"http_in_bytes" bigint DEFAULT 0 NOT NULL,
	"http_requests" integer DEFAULT 0 NOT NULL,
	"r2_upload_bytes" bigint DEFAULT 0 NOT NULL,
	"r2_class_a_ops" integer DEFAULT 0 NOT NULL,
	"db_size_bytes" bigint,
	"r2_storage_bytes" bigint,
	"r2_object_count" integer,
	"peak_rss_bytes" bigint,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "payments" ADD COLUMN "gateway_fee" numeric(12, 2);--> statement-breakpoint
ALTER TABLE "payments" ADD COLUMN "gateway_tax" numeric(12, 2);--> statement-breakpoint
ALTER TABLE "admin_alerts" ADD CONSTRAINT "admin_alerts_acknowledged_by_staff_users_id_fk" FOREIGN KEY ("acknowledged_by") REFERENCES "public"."staff_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "admin_alerts_open_metric_uq" ON "admin_alerts" USING btree ("metric") WHERE "admin_alerts"."resolved_at" IS NULL;--> statement-breakpoint
CREATE INDEX "admin_alerts_created_idx" ON "admin_alerts" USING btree ("created_at" DESC NULLS LAST);--> statement-breakpoint
-- Supabase exposes `public` over PostgREST: lock the new tables like every other table.
ALTER TABLE "admin_alerts" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "usage_daily" ENABLE ROW LEVEL SECURITY;
