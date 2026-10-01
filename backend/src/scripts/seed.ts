/**
 * Idempotent seed for app_config: `npm run db:seed`
 *
 * Inserts defaults only where a key is missing — it never overwrites values
 * changed later in the dashboard/admin, so it's safe to run on every deploy.
 */
import { sql } from 'drizzle-orm';
import { closeDb, db } from '../db/client';
import { appConfig } from '../db/schema';
import { CONFIG_KEYS } from '../modules/app-config/app-config.service';

const defaults: (typeof appConfig.$inferInsert)[] = [
  {
    key: CONFIG_KEYS.DEMO_LOGIN_ENABLED,
    value: true,
    isPublic: false,
    description: 'Accept the fixed reviewer OTP for DEMO_LOGIN_PHONE. Turn OFF after store approval.',
  },
  {
    key: CONFIG_KEYS.MIN_APP_VERSION,
    value: { android: '1.0.0', ios: '1.0.0' },
    isPublic: true,
    description: 'App shows a force-update screen below this version.',
  },
  {
    key: CONFIG_KEYS.MAINTENANCE,
    value: { enabled: false, message: '' },
    isPublic: true,
    description: 'Show a maintenance banner and block checkout.',
  },
  {
    key: CONFIG_KEYS.STORE_INFO,
    value: { name: 'Jeya Hyper Store', city: 'Tiruchirappalli', supportPhone: null, supportWhatsApp: null },
    isPublic: true,
    description: 'Store contact details shown in the app.',
  },
];

async function main(): Promise<void> {
  const inserted = await db
    .insert(appConfig)
    .values(defaults)
    .onConflictDoNothing({ target: appConfig.key })
    .returning({ key: appConfig.key });

  const rows = await db
    .select({ key: appConfig.key, value: appConfig.value, isPublic: appConfig.isPublic })
    .from(appConfig)
    .orderBy(sql`${appConfig.key}`);

  console.log(`✔ seeded ${inserted.length} new key(s): ${inserted.map((row) => row.key).join(', ') || '(none)'}`);
  for (const row of rows) console.log(`  ${row.isPublic ? 'public ' : 'private'}  ${row.key} = ${JSON.stringify(row.value)}`);
}

main()
  .catch((error: unknown) => {
    console.error('❌ seed failed:', error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => closeDb());
