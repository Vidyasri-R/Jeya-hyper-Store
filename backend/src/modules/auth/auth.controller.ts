import type { Request, Response } from 'express';
import { parseBody } from '../../common/validate';
import { logoutSchema, refreshSchema, requestOtpSchema, verifyOtpSchema } from './auth.schemas';
import { authService } from './auth.service';

const context = (req: Request) => ({ ipAddress: req.ip ?? null });

export const authController = {
  async requestOtp(req: Request, res: Response) {
    const { phone } = parseBody(requestOtpSchema, req);
    res.status(202).json(await authService.requestOtp(phone, context(req)));
  },

  async verifyOtp(req: Request, res: Response) {
    const input = parseBody(verifyOtpSchema, req);
    res.json(await authService.verifyOtp(input, context(req)));
  },

  async refresh(req: Request, res: Response) {
    const { refreshToken } = parseBody(refreshSchema, req);
    res.json(await authService.refresh(refreshToken));
  },

  async logout(req: Request, res: Response) {
    const { refreshToken } = parseBody(logoutSchema, req);
    await authService.logout(refreshToken);
    res.status(204).end();
  },
};
