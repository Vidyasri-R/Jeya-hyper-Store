CREATE TABLE "product_links" (
	"old_product_id" bigint NOT NULL,
	"new_product_id" bigint NOT NULL,
	"decision" varchar(12) NOT NULL,
	"decided_by" uuid,
	"decided_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "product_links_old_product_id_new_product_id_pk" PRIMARY KEY("old_product_id","new_product_id")
);
--> statement-breakpoint
ALTER TABLE "product_links" ADD CONSTRAINT "product_links_old_product_id_products_id_fk" FOREIGN KEY ("old_product_id") REFERENCES "public"."products"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "product_links" ADD CONSTRAINT "product_links_new_product_id_products_id_fk" FOREIGN KEY ("new_product_id") REFERENCES "public"."products"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "product_links" ADD CONSTRAINT "product_links_decided_by_staff_users_id_fk" FOREIGN KEY ("decided_by") REFERENCES "public"."staff_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "product_links_new_idx" ON "product_links" USING btree ("new_product_id");