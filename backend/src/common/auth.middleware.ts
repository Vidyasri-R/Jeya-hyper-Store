import type { NextFunction, Request, RequestHandler, Response } from 'express';
import type { UserRole } from '../db/schema';
import { verifyAccessToken } from '../modules/auth/tokens';
import { AppError } from './errors';

/**
 * Stateless JWT check — no DB hit. A revoked session's access token stays valid
 * until it expires (ACCESS_TOKEN_TTL_SEC, 15 min by default); refresh is what's blocked.
 */
export const requireAuth: RequestHandler = (req: Request, _res: Response, next: NextFunction) => {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new AppError('UNAUTHORIZED', 'Missing bearer token', { reason: 'token_missing' });
  }
  req.auth = verifyAccessToken(header.slice('Bearer '.length).trim());
  next();
};

export function requireRole(...roles: UserRole[]): RequestHandler {
  return (req, _res, next) => {
    if (!req.auth) throw new AppError('UNAUTHORIZED', 'Not authenticated');
    if (!roles.includes(req.auth.role)) throw new AppError('FORBIDDEN', 'Insufficient permissions');
    next();
  };
}

/** For handlers mounted behind requireAuth. */
export function authOf(req: Request): NonNullable<Request['auth']> {
  if (!req.auth) throw new AppError('UNAUTHORIZED', 'Not authenticated');
  return req.auth;
}
