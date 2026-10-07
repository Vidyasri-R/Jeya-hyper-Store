CREATE TABLE "product_barcodes" (
	"barcode" varchar(64) PRIMARY KEY NOT NULL,
	"product_id" bigint NOT NULL
);
--> statement-breakpoint
ALTER TABLE "products" DROP CONSTRAINT "products_gst_rate_ck";--> statement-breakpoint
ALTER TABLE "product_barcodes" ADD CONSTRAINT "product_barcodes_product_id_products_id_fk" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "product_barcodes_product_idx" ON "product_barcodes" USING btree ("product_id");--> statement-breakpoint
ALTER TABLE "products" ADD CONSTRAINT "products_gst_rate_ck" CHECK ("products"."gst_rate" >= 0 AND "products"."gst_rate" <= 40);