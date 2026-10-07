ALTER TYPE "public"."staff_role" ADD VALUE 'photos';--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "photo_priority" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "photo_assignee_id" uuid;--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "photo_assigned_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "photo_by_id" uuid;--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "photo_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "products" ADD CONSTRAINT "products_photo_assignee_id_staff_users_id_fk" FOREIGN KEY ("photo_assignee_id") REFERENCES "public"."staff_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "products" ADD CONSTRAINT "products_photo_by_id_staff_users_id_fk" FOREIGN KEY ("photo_by_id") REFERENCES "public"."staff_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "products_photo_queue_idx" ON "products" USING btree ("photo_assignee_id","photo_priority" DESC NULLS LAST,"id") WHERE "products"."is_active" = true AND "products"."image_url" IS NULL;