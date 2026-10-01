import { Router } from 'express';
import { authOf, requireAuth } from '../../common/auth.middleware';
import { parseBody, parseParams } from '../../common/validate';
import { addressIdParams, createAddressSchema, updateAddressSchema } from './addresses.schemas';
import { addressesService } from './addresses.service';

export const addressesRouter = Router();

addressesRouter.use(requireAuth);

addressesRouter.get('/', async (req, res) => {
  res.json({ addresses: await addressesService.list(authOf(req).userId) });
});

addressesRouter.post('/', async (req, res) => {
  const input = parseBody(createAddressSchema, req);
  res.status(201).json({ address: await addressesService.create(authOf(req).userId, input) });
});

addressesRouter.patch('/:id', async (req, res) => {
  const { id } = parseParams(addressIdParams, req);
  const input = parseBody(updateAddressSchema, req);
  res.json({ address: await addressesService.update(authOf(req).userId, id, input) });
});

addressesRouter.delete('/:id', async (req, res) => {
  const { id } = parseParams(addressIdParams, req);
  await addressesService.remove(authOf(req).userId, id);
  res.status(204).end();
});
