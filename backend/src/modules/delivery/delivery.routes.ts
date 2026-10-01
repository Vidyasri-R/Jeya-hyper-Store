import { Router } from 'express';
import { z } from 'zod';
import { parseParams } from '../../common/validate';
import { deliveryService } from './delivery.service';

export const deliveryRouter = Router();

const pincodeParams = z.object({ pincode: z.string().regex(/^[1-9][0-9]{5}$/, 'Enter a valid 6-digit pincode') });

/** "Do you deliver to 620017?" — public, used before login too. */
deliveryRouter.get('/pincodes/:pincode', async (req, res) => {
  const { pincode } = parseParams(pincodeParams, req);
  const rule = await deliveryService.ruleFor(pincode);
  res.set('Cache-Control', 'public, max-age=300');
  res.json(rule ? { serviceable: true, ...deliveryService.toPublic(rule) } : { serviceable: false, pincode });
});
