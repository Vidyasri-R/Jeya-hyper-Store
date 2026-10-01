import { Router } from 'express';
import { appConfigRouter } from './modules/app-config/app-config.routes';
import { authRouter } from './modules/auth/auth.routes';
import { meRouter } from './modules/users/users.routes';

/** Versioned API — the app pins /v1, so breaking changes go to /v2 without a forced update. */
export const v1Router = Router();

v1Router.use('/config', appConfigRouter);
v1Router.use('/auth', authRouter);
v1Router.use('/me', meRouter);
