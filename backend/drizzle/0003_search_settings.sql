-- Database-wide default for the `<%` (word_similarity) operator used by product search.
-- Set here instead of per-query SET LOCAL so a search is one round trip, not four
-- (BEGIN / SET / SELECT / COMMIT). 0.4 lets "poni rise" match "Ponni Raw Rice" (0.42).
-- Applies to new connections; `npm run db:check` verifies it.
-- Calling a pg_trgm function first loads its library, which registers the GUC;
-- without that, non-superusers (Supabase's `postgres`) get "permission denied".
DO $$
BEGIN
  PERFORM extensions.similarity('a', 'b');
  EXECUTE format('ALTER DATABASE %I SET pg_trgm.word_similarity_threshold = 0.4', current_database());
END
$$;
