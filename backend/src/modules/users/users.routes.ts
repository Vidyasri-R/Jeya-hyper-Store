import { Router } from 'express';
import { authOf, requireAuth } from '../../common/auth.middleware';
import { parseBody } from '../../common/validate';
import { updateProfileSchema } from './users.schemas';
import { usersService } from './users.service';

export const meRouter = Router();

meRouter.use(requireAuth);

meRouter.get('/', async (req, res) => {
  res.json({ user: await usersService.getMe(authOf(req).userId) });
});

meRouter.patch('/', async (req, res) => {
  const input = parseBody(updateProfileSchema, req);
  res.json({ user: await usersService.updateMe(authOf(req).userId, input) });
});

meRouter.delete('/', async (req, res) => {
  await usersService.deleteMe(authOf(req).userId);
  res.status(204).end();
});
