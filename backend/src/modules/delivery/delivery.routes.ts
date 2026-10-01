import { Router } from 'express';
import { z } from 'zod';
import { parseParams, parseQuery } from '../../common/validate';
import { deliveryService } from './delivery.service';

export const deliveryRouter = Router();

const pincodeParams = z.object({ pincode: z.string().regex(/^[1-9][0-9]{5}$/, 'Enter a valid 6-digit pincode') });

/** "Do you deliver to 620017?" — public, used before login too (pincode-level, before a map pin exists). */
deliveryRouter.get('/pincodes/:pincode', async (req, res) => {
  const { pincode } = parseParams(pincodeParams, req);
  res.set('Cache-Control', 'public, max-age=300');
  res.json(deliveryService.toPublic(await deliveryService.quote({ pincode, latitude: null, longitude: null })));
});

const estimateQuery = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
});

/** Live fee preview while the customer drags the map pin on the address screen. */
deliveryRouter.get('/estimate', async (req, res) => {
  const { lat, lng } = parseQuery(estimateQuery, req);
  res.json(
    deliveryService.toPublic(
      await deliveryService.quote({ pincode: '000000', latitude: String(lat), longitude: String(lng) }),
    ),
  );
});

/** Fee bands + free-delivery threshold for the "Delivery charges" info sheet. */
deliveryRouter.get('/rules', async (_req, res) => {
  res.set('Cache-Control', 'public, max-age=300');
  res.json({ rules: await deliveryService.publicRules() });
});
