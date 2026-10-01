import jwt from 'jsonwebtoken';
import { AppError } from '../../common/errors';
import { env } from '../../config/env';
import { userRole, type UserRole } from '../../db/schema';

const ISSUER = 'jeya-api';
const AUDIENCE = 'jeya-app';

export type AccessTokenClaims = {
  userId: string;
  role: UserRole;
  sessionId: string;
};

export function signAccessToken(claims: AccessTokenClaims): string {
  return jwt.sign({ role: claims.role, sid: claims.sessionId, typ: 'access' }, env.JWT_ACCESS_SECRET, {
    algorithm: 'HS256',
    subject: claims.userId,
    issuer: ISSUER,
    audience: AUDIENCE,
    expiresIn: env.ACCESS_TOKEN_TTL_SEC,
  });
}

export function verifyAccessToken(token: string): AccessTokenClaims {
  let payload: string | jwt.JwtPayload;
  try {
    payload = jwt.verify(token, env.JWT_ACCESS_SECRET, {
      algorithms: ['HS256'],
      issuer: ISSUER,
      audience: AUDIENCE,
    });
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw new AppError('UNAUTHORIZED', 'Access token expired', { reason: 'token_expired' });
    }
    throw new AppError('UNAUTHORIZED', 'Invalid access token', { reason: 'token_invalid' });
  }

  if (
    typeof payload === 'string' ||
    payload.typ !== 'access' ||
    typeof payload.sub !== 'string' ||
    typeof payload.sid !== 'string' ||
    !userRole.enumValues.includes(payload.role)
  ) {
    throw new AppError('UNAUTHORIZED', 'Invalid access token', { reason: 'token_invalid' });
  }

  return { userId: payload.sub, role: payload.role as UserRole, sessionId: payload.sid };
}
