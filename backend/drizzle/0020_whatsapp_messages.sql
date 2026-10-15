CREATE TABLE "whatsapp_messages" (
	"id" bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY (sequence name "whatsapp_messages_id_seq" INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1),
	"ref_key" varchar(80) NOT NULL,
	"kind" varchar(40) NOT NULL,
	"order_id" uuid,
	"phone" varchar(15) NOT NULL,
	"template" varchar(64) NOT NULL,
	"status" varchar(16) DEFAULT 'sending' NOT NULL,
	"provider_message_id" varchar(128),
	"error" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "whatsapp_messages" ADD CONSTRAINT "whatsapp_messages_order_id_orders_id_fk" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "whatsapp_messages_ref_uq" ON "whatsapp_messages" USING btree ("ref_key");--> statement-breakpoint
CREATE INDEX "whatsapp_messages_created_idx" ON "whatsapp_messages" USING btree ("created_at");