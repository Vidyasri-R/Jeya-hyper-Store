import { Router } from 'express';
import { authOf, requireAuth } from '../../common/auth.middleware';
import { parseBody, parseParams } from '../../common/validate';
import { mergeCartSchema, productIdParams, setQuantitySchema } from './cart.schemas';
import { cartService } from './cart.service';

export const cartRouter = Router();

cartRouter.use(requireAuth);

cartRouter.get('/', async (req, res) => {
  res.json({ cart: await cartService.get(authOf(req).userId) });
});

cartRouter.put('/items/:productId', async (req, res) => {
  const { productId } = parseParams(productIdParams, req);
  const { quantity } = parseBody(setQuantitySchema, req);
  res.json({ cart: await cartService.setQuantity(authOf(req).userId, productId, quantity) });
});

cartRouter.delete('/items/:productId', async (req, res) => {
  const { productId } = parseParams(productIdParams, req);
  res.json({ cart: await cartService.remove(authOf(req).userId, productId) });
});

cartRouter.delete('/', async (req, res) => {
  await cartService.clear(authOf(req).userId);
  res.status(204).end();
});

cartRouter.post('/fix', async (req, res) => {
  res.json(await cartService.fix(authOf(req).userId));
});

cartRouter.post('/merge', async (req, res) => {
  const { items } = parseBody(mergeCartSchema, req);
  res.json(await cartService.merge(authOf(req).userId, items));
});
