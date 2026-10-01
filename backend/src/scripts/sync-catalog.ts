/**
 * Run a catalogue sync from the CLI:
 *   npm run sync:catalog            (delta; becomes full on the very first run)
 *   npm run sync:catalog -- full    (full resync + deactivate items missing from the POS)
 */
import { closeDb } from '../db/client';
import { catalogSyncService, type SyncMode } from '../modules/sync/catalog-sync.service';

const arg = process.argv[2] ?? 'delta';
if (arg !== 'delta' && arg !== 'full') {
  console.error('usage: npm run sync:catalog -- [delta|full]');
  process.exit(2);
}

catalogSyncService
  .run(arg as SyncMode)
  .then((result) => {
    console.log(JSON.stringify(result, null, 2));
    if (result.status === 'skipped') process.exitCode = 3;
  })
  .catch((error: unknown) => {
    console.error('❌ sync failed:', error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => closeDb());
