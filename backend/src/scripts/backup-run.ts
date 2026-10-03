/**
 * Back up the database to R2 now (the server also does this nightly at 2 AM IST):
 *
 *   npm run backup:run            (full on the first run of a month, else incremental)
 *   npm run backup:run -- --full
 */
import { closeDb } from '../db/client';
import { backupService } from '../modules/backup/backup.service';

backupService
  .run(process.argv.includes('--full') ? 'full' : 'auto')
  .then((result) => console.log(result.status === 'success' ? `✔ ${result.kind} backup ${result.key}: ${result.rows} rows, ${(result.bytes / 1024).toFixed(1)} KB` : `– skipped (${result.reason})`))
  .catch((error: unknown) => {
    console.error('❌ backup failed:', error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => closeDb());
