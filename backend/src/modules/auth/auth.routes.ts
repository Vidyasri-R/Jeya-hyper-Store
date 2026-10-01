import { Router } from 'express';
import { rateLimit } from 'express-rate-limit';
import { AppError } from '../../common/errors';
import { authController } from './auth.controller';

/**
 * Coarse per-IP burst guard in front of the DB-backed OTP limits.
 * In-memory store is fine for a single Render instance; switch to the Redis
 * store once we scale horizontally (BullMQ brings Redis in Step 5).
 */
const authBurstLimiter = rateLimit({
  windowMs: 60_000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: (_req, _res, next) => next(new AppError('RATE_LIMITED', 'Too many requests. Slow down.')),
});

export const authRouter = Router();

authRouter.use(authBurstLimiter);
authRouter.post('/otp/request', authController.requestOtp);
authRouter.post('/otp/verify', authController.verifyOtp);
authRouter.post('/refresh', authController.refresh);
authRouter.post('/logout', authController.logout);
