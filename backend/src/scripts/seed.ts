/**
 * Idempotent seed for app_config: `npm run db:seed`
 *
 * Inserts defaults only where a key is missing — it never overwrites values
 * changed later in the dashboard/admin, so it's safe to run on every deploy.
 */
import { sql } from 'drizzle-orm';
import { closeDb, db } from '../db/client';
import { appConfig, serviceablePincodes } from '../db/schema';
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
    key: CONFIG_KEYS.PAYMENT_METHODS,
    value: { cod: true, online: false },
    isPublic: true,
    description: 'Payment options shown at checkout. Turn online on once Razorpay is live.',
  },
  {
    key: CONFIG_KEYS.STORE_INFO,
    value: { name: 'Jeya Hyper Store', city: 'Tiruchirappalli', supportPhone: null, supportWhatsApp: null },
    isPublic: true,
    description: 'Store contact details shown in the app.',
  },
];

/**
 * PLACEHOLDER delivery areas so checkout works end to end in development.
 * Replace with the store's real pincodes and fees before launch (edit rows in
 * Supabase → serviceable_pincodes; this seed never overwrites existing rows).
 */
const PLACEHOLDER_FEES = { deliveryFee: '30.00', minOrderAmount: '199.00', freeDeliveryAbove: '499.00' };
const placeholderPincodes = ['620001', '620002', '620008', '620017', '620018', '620021'].map((pincode) => ({
  pincode,
  areaName: `Tiruchirappalli ${pincode} (placeholder)`,
  ...PLACEHOLDER_FEES,
}));

async function main(): Promise<void> {
  const pincodes = await db
    .insert(serviceablePincodes)
    .values(placeholderPincodes)
    .onConflictDoNothing({ target: serviceablePincodes.pincode })
    .returning({ pincode: serviceablePincodes.pincode });
  console.log(`✔ seeded ${pincodes.length} new delivery pincode(s)${pincodes.length ? ` (placeholders: ${pincodes.map((row) => row.pincode).join(', ')})` : ''}`);

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
