import { shopTvRouter } from './modules/shop-tv/shop-tv.routes';
import { Router } from 'express';
import { addressesRouter } from './modules/addresses/addresses.routes';
import { adminRouter } from './modules/admin/admin.routes';
import { appConfigRouter } from './modules/app-config/app-config.routes';
import { authRouter } from './modules/auth/auth.routes';
import { cartRouter } from './modules/cart/cart.routes';
import { catalogRouter } from './modules/catalog/catalog.routes';
import { deliveryRouter } from './modules/delivery/delivery.routes';
import { checkoutRouter, ordersRouter } from './modules/orders/orders.routes';
import { orderPaymentRouter } from './modules/payments/payments.routes';
import { staffRouter } from './modules/staff/staff.routes';
import { meRouter } from './modules/users/users.routes';

/** Versioned API — the app pins /v1, so breaking changes go to /v2 without a forced update. */
export const v1Router = Router();

v1Router.use('/config', appConfigRouter);
v1Router.use('/auth', authRouter);
v1Router.use('/me/addresses', addressesRouter);
v1Router.use('/me', meRouter);
v1Router.use('/delivery', deliveryRouter);
v1Router.use('/cart', cartRouter);
v1Router.use('/checkout', checkoutRouter);
v1Router.use('/orders/:id/payment', orderPaymentRouter);
v1Router.use('/orders', ordersRouter);
v1Router.use('/staff', staffRouter);
v1Router.use('/admin', adminRouter);
v1Router.use('/shoptv', shopTvRouter);
v1Router.use('/', catalogRouter);
