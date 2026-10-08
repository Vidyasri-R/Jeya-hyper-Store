CREATE TABLE "customer_perks" (
	"phone" varchar(15) PRIMARY KEY NOT NULL,
	"name" varchar(120),
	"free_delivery" boolean DEFAULT false NOT NULL,
	"discount_percent" numeric(5, 2) DEFAULT '0' NOT NULL,
	"note" varchar(200),
	"is_active" boolean DEFAULT true NOT NULL,
	"updated_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "customer_perks_discount_ck" CHECK ("customer_perks"."discount_percent" >= 0 AND "customer_perks"."discount_percent" <= 50),
	CONSTRAINT "customer_perks_phone_ck" CHECK ("customer_perks"."phone" ~ '^[0-9]{10,15}$')
);
--> statement-breakpoint
CREATE TABLE "expenses" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "expenses_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"spent_on" date NOT NULL,
	"category" varchar(40) NOT NULL,
	"amount" numeric(12, 2) NOT NULL,
	"note" varchar(200),
	"created_by" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "expenses_amount_ck" CHECK ("expenses"."amount" > 0)
);
--> statement-breakpoint
ALTER TABLE "order_items" ADD COLUMN "unit_cost" numeric(12, 2);--> statement-breakpoint
ALTER TABLE "orders" ADD COLUMN "member_discount_percent" numeric(5, 2);--> statement-breakpoint
ALTER TABLE "orders" ADD COLUMN "member_free_delivery" boolean DEFAULT false NOT NULL;--> statement-breakpoint
ALTER TABLE "products" ADD COLUMN "cost_price" numeric(12, 2);--> statement-breakpoint
ALTER TABLE "customer_perks" ADD CONSTRAINT "customer_perks_updated_by_staff_users_id_fk" FOREIGN KEY ("updated_by") REFERENCES "public"."staff_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "expenses" ADD CONSTRAINT "expenses_created_by_staff_users_id_fk" FOREIGN KEY ("created_by") REFERENCES "public"."staff_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "expenses_spent_on_idx" ON "expenses" USING btree ("spent_on");