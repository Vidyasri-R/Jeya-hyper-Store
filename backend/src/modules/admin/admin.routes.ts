import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, requireRole } from '../../common/auth.middleware';
import { parseBody } from '../../common/validate';
import { catalogSyncService } from '../sync/catalog-sync.service';

export const adminRouter = Router();

adminRouter.use(requireAuth, requireRole('admin', 'staff'));

const runSyncSchema = z.object({ mode: z.enum(['delta', 'full']).default('delta') });

/** Manual trigger (e.g. after a big price change in the POS). Waits for completion. */
adminRouter.post('/sync/catalog', async (req, res) => {
  const { mode } = parseBody(runSyncSchema, req);
  const result = await catalogSyncService.run(mode);
  res.status(result.status === 'skipped' ? 409 : 200).json({ result });
});

adminRouter.get('/sync/status', async (_req, res) => {
  res.json({ sync: await catalogSyncService.status() });
});
