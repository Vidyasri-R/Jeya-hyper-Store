ALTER TABLE "products" ADD COLUMN "variant_group" varchar(160);--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "variant_label" varchar(80);--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "is_variant_leader" boolean DEFAULT true NOT NULL;--> statement-breakpoint
CREATE INDEX "products_variant_group_idx" ON "products" USING btree ("variant_group") WHERE "products"."variant_group" IS NOT NULL;