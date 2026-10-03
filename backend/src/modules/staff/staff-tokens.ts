import { createHmac } from 'node:crypto';
import jwt from 'jsonwebtoken';
import { AppError } from '../../common/errors';
import { env } from '../../config/env';
import { staffRole, type StaffRole } from '../../db/schema';

/**
 * Staff tokens use a key DERIVED from JWT_ACCESS_SECRET plus a different audience,
 * so a customer token can never authenticate against staff/admin APIs (and vice versa),
 * without adding another secret to manage on Render.
 */
const STAFF_SECRET = createHmac('sha256', env.JWT_ACCESS_SECRET).update('jeya-staff-access-v1').digest('base64url');
const ISSUER = 'jeya-api';
const AUDIENCE = 'jeya-staff';
export const STAFF_ACCESS_TTL_SEC = 30 * 60;

export type StaffClaims = { staffId: string; role: StaffRole; sessionId: string };

export function signStaffToken(claims: StaffClaims): string {
  return jwt.sign({ role: claims.role, sid: claims.sessionId, typ: 'staff' }, STAFF_SECRET, {
    algorithm: 'HS256',
    subject: claims.staffId,
    issuer: ISSUER,
    audience: AUDIENCE,
    expiresIn: STAFF_ACCESS_TTL_SEC,
  });
}

export function verifyStaffToken(token: string): StaffClaims {
  let payload: string | jwt.JwtPayload;
  try {
    payload = jwt.verify(token, STAFF_SECRET, { algorithms: ['HS256'], issuer: ISSUER, audience: AUDIENCE });
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      throw new AppError('UNAUTHORIZED', 'Session expired', { reason: 'token_expired' });
    }
    throw new AppError('UNAUTHORIZED', 'Invalid staff token', { reason: 'token_invalid' });
  }
  if (
    typeof payload === 'string' ||
    payload.typ !== 'staff' ||
    typeof payload.sub !== 'string' ||
    typeof payload.sid !== 'string' ||
    !staffRole.enumValues.includes(payload.role)
  ) {
    throw new AppError('UNAUTHORIZED', 'Invalid staff token', { reason: 'token_invalid' });
  }
  return { staffId: payload.sub, role: payload.role as StaffRole, sessionId: payload.sid };
}
