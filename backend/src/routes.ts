import { Router } from 'express';
import { adminRouter } from './modules/admin/admin.routes';
import { appConfigRouter } from './modules/app-config/app-config.routes';
import { authRouter } from './modules/auth/auth.routes';
import { catalogRouter } from './modules/catalog/catalog.routes';
import { meRouter } from './modules/users/users.routes';

/** Versioned API — the app pins /v1, so breaking changes go to /v2 without a forced update. */
export const v1Router = Router();

v1Router.use('/config', appConfigRouter);
v1Router.use('/auth', authRouter);
v1Router.use('/me', meRouter);
v1Router.use('/admin', adminRouter);
v1Router.use('/', catalogRouter);
