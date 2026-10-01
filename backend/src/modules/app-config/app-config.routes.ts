import { Router } from 'express';
import { appConfigService } from './app-config.service';

export const appConfigRouter = Router();

/** Public remote config the app reads at launch (min version, store info, maintenance banner). */
appConfigRouter.get('/', async (_req, res) => {
  res.set('Cache-Control', 'public, max-age=60');
  res.json({ config: await appConfigService.getPublicConfig() });
});
