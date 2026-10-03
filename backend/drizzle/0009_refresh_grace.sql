ALTER TABLE "staff_sessions" ADD COLUMN "previous_refresh_token_hash" varchar(64);--> statement-breakpoint
ALTER TABLE "staff_sessions" ADD COLUMN "rotated_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "user_sessions" ADD COLUMN "previous_refresh_token_hash" varchar(64);--> statement-breakpoint
ALTER TABLE "user_sessions" ADD COLUMN "rotated_at" timestamp with time zone;--> statement-breakpoint
CREATE INDEX "staff_sessions_prev_token_hash_idx" ON "staff_sessions" USING btree ("previous_refresh_token_hash");--> statement-breakpoint
CREATE INDEX "user_sessions_prev_token_hash_idx" ON "user_sessions" USING btree ("previous_refresh_token_hash");