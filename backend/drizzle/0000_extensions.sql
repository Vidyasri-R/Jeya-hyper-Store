-- Must run before the schema migration: products_name_trgm_idx uses gin_trgm_ops.
-- Supabase convention is to keep extensions out of `public`; the `extensions`
-- schema is on the default search_path for the postgres role.
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;
