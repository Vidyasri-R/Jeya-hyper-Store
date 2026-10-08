ALTER TABLE "products" ADD COLUMN "photo_check_reason" varchar(40);--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "photo_check_since" timestamp with time zone;