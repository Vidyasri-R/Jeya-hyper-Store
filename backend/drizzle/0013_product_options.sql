ALTER TABLE "cart_items" ADD COLUMN "choices" jsonb;--> statement-breakpoint
ALTER TABLE "order_items" ADD COLUMN "choices" jsonb;--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "options" jsonb;