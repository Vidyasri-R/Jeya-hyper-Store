import type { Request, RequestHandler } from 'express';
import type { StaffRole } from '../db/schema';
import { staffAuthService } from '../modules/staff/staff-auth.service';
import { verifyStaffToken } from '../modules/staff/staff-tokens';
import { AppError } from './errors';

/**
 * Staff/admin auth (Jeya Staff app). Customer tokens are rejected (different key + audience).
 * Unlike customer auth this also checks the session in the DB (cached ~15 s), so disabling an
 * account or resetting its password locks the person out right away; the role comes from the
 * DB too, so a demotion applies immediately.
 */
function staffAuth(options: { allowPendingPasswordChange: boolean }): RequestHandler {
  return async (req, _res, next) => {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new AppError('UNAUTHORIZED', 'Missing bearer token', { reason: 'token_missing' });
    }
    const claims = verifyStaffToken(header.slice('Bearer '.length).trim());
    const state = await staffAuthService.sessionState(claims.sessionId);
    if (!state || state.staffId !== claims.staffId || !state.isActive) {
      throw new AppError('UNAUTHORIZED', 'Session expired. Please log in again.', { reason: 'session_revoked' });
    }
    if (state.mustChangePassword && !options.allowPendingPasswordChange) {
      throw new AppError('FORBIDDEN', 'Please set a new password first', { reason: 'password_change_required' });
    }
    req.staff = { staffId: state.staffId, role: state.role, sessionId: state.sessionId };
    next();
  };
}

export const requireStaff = staffAuth({ allowPendingPasswordChange: false });
/** Only for /staff/me and /staff/me/password — reachable before the first password change. */
export const requireStaffAllowingPasswordChange = staffAuth({ allowPendingPasswordChange: true });

export function requireStaffRole(...roles: StaffRole[]): RequestHandler {
  return (req, _res, next) => {
    if (!req.staff) throw new AppError('UNAUTHORIZED', 'Not authenticated');
    if (!roles.includes(req.staff.role)) throw new AppError('FORBIDDEN', 'Admin access required', { reason: 'admin_only' });
    next();
  };
}

export const requireAdmin = requireStaffRole('admin');

export function staffOf(req: Request): NonNullable<Request['staff']> {
  if (!req.staff) throw new AppError('UNAUTHORIZED', 'Not authenticated');
  return req.staff;
}
