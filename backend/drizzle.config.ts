import 'dotenv/config';
import { defineConfig } from 'drizzle-kit';

const directUrl = process.env.DIRECT_DATABASE_URL;

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/db/schema.ts',
  out: './drizzle',
  casing: 'snake_case',
  strict: true,
  verbose: true,
  // Only needed for `drizzle-kit studio` / `push`; `generate` works offline.
  ...(directUrl ? { dbCredentials: { url: directUrl } } : {}),
});
