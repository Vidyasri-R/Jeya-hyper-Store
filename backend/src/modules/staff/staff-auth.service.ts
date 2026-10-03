import { randomToken, sha256Hex } from '../../common/crypto';
import { AppError } from '../../common/errors';
import { dummyPasswordHash, hashPassword, passwordProblem, verifyPassword } from '../../common/password';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import type { StaffUser } from '../../db/schema';
import { staffRepository, type StaffSessionState } from './staff.repository';
import type { StaffLoginInput } from './staff.schemas';
import { signStaffToken, STAFF_ACCESS_TTL_SEC } from './staff-tokens';

const MAX_FAILED_LOGINS = 5;
const LOCK_MINUTES = 15;
const STAFF_REFRESH_TTL_DAYS = 30;
/** Staff requests re-check the session in the DB; this keeps a busy order board from doing it on every poll. */
const SESSION_CACHE_MS = 15_000;

type RequestContext = { ipAddress: string | null };

export type PublicStaff = {
  id: string;
  username: string;
  name: string;
  phone: string | null;
  role: StaffUser['role'];
  mustChangePassword: boolean;
  isActive: boolean;
  lastLoginAt: Date | null;
};

export type StaffTokens = {
  accessToken: string;
  accessTokenExpiresIn: number;
  refreshToken: string;
  refreshTokenExpiresAt: Date;
};

export function toPublicStaff(staff: StaffUser): PublicStaff {
  return {
    id: staff.id,
    username: staff.username,
    name: staff.name,
    phone: staff.phone,
    role: staff.role,
    mustChangePassword: staff.mustChangePassword,
    isActive: staff.isActive,
    lastLoginAt: staff.lastLoginAt,
  };
}

const sessionCache = new Map<string, { state: StaffSessionState | null; at: number }>();

function refreshExpiry(): Date {
  return new Date(Date.now() + STAFF_REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);
}

const invalidCredentials = () => new AppError('UNAUTHORIZED', 'Incorrect username or password', { reason: 'credentials_invalid' });

async function issueSession(staff: StaffUser, meta: { deviceInfo?: string | undefined; ipAddress: string | null }): Promise<StaffTokens> {
  const refreshToken = randomToken();
  const refreshTokenExpiresAt = refreshExpiry();
  const session = await staffRepository.createSession(db, {
    staffId: staff.id,
    refreshTokenHash: sha256Hex(refreshToken),
    deviceInfo: meta.deviceInfo ?? null,
    ipAddress: meta.ipAddress,
    expiresAt: refreshTokenExpiresAt,
  });
  return {
    accessToken: signStaffToken({ staffId: staff.id, role: staff.role, sessionId: session.id }),
    accessTokenExpiresIn: STAFF_ACCESS_TTL_SEC,
    refreshToken,
    refreshTokenExpiresAt,
  };
}

export const staffAuthService = {
  async login(input: StaffLoginInput, ctx: RequestContext) {
    const staff = await staffRepository.findByUsername(db, input.username);
    if (!staff) {
      // Same cost as a real check, so response time doesn't reveal which usernames exist.
      await verifyPassword(input.password, await dummyPasswordHash());
      throw invalidCredentials();
    }

    if (staff.lockedUntil && staff.lockedUntil.getTime() > Date.now()) {
      const retryAfterSec = Math.ceil((staff.lockedUntil.getTime() - Date.now()) / 1000);
      throw new AppError('RATE_LIMITED', `Too many wrong attempts. Try again in ${Math.ceil(retryAfterSec / 60)} min, or ask the admin to reset the password.`, {
        reason: 'account_locked',
        retryAfterSec,
      });
    }

    if (!(await verifyPassword(input.password, staff.passwordHash))) {
      const { lockedUntil } = await staffRepository.recordFailedLogin(db, staff.id, MAX_FAILED_LOGINS, LOCK_MINUTES);
      logger.warn({ staffId: staff.id, ip: ctx.ipAddress, locked: Boolean(lockedUntil && lockedUntil.getTime() > Date.now()) }, 'staff login failed');
      if (lockedUntil && lockedUntil.getTime() > Date.now()) {
        throw new AppError('RATE_LIMITED', `Too many wrong attempts. Try again in ${LOCK_MINUTES} min, or ask the admin to reset the password.`, {
          reason: 'account_locked',
          retryAfterSec: LOCK_MINUTES * 60,
        });
      }
      throw invalidCredentials();
    }

    // Only revealed to someone who knows the password.
    if (!staff.isActive) throw new AppError('FORBIDDEN', 'This account is disabled. Please contact the store admin.', { reason: 'account_disabled' });

    await staffRepository.recordSuccessfulLogin(db, staff.id);
    const tokens = await issueSession(staff, { deviceInfo: input.deviceInfo, ...ctx });
    logger.info({ staffId: staff.id, role: staff.role }, 'staff signed in');
    return { ...tokens, staff: toPublicStaff(staff) };
  },

  async refresh(refreshToken: string): Promise<StaffTokens & { staff: PublicStaff }> {
    const nextToken = randomToken();
    const nextExpiresAt = refreshExpiry();
    const session = await staffRepository.rotateSession(db, sha256Hex(refreshToken), sha256Hex(nextToken), nextExpiresAt);
    const staff = session ? await staffRepository.findById(db, session.staffId) : null;
    if (!session || !staff?.isActive) {
      throw new AppError('UNAUTHORIZED', 'Session expired. Please log in again.', { reason: 'refresh_invalid' });
    }
    return {
      // Role is re-read, so a promotion/demotion applies from the next refresh.
      accessToken: signStaffToken({ staffId: staff.id, role: staff.role, sessionId: session.id }),
      accessTokenExpiresIn: STAFF_ACCESS_TTL_SEC,
      refreshToken: nextToken,
      refreshTokenExpiresAt: nextExpiresAt,
      staff: toPublicStaff(staff),
    };
  },

  async logout(refreshToken: string): Promise<void> {
    const sessionId = await staffRepository.revokeSessionByHash(db, sha256Hex(refreshToken));
    if (sessionId) sessionCache.delete(sessionId);
  },

  async me(staffId: string): Promise<PublicStaff> {
    const staff = await staffRepository.findById(db, staffId);
    if (!staff) throw AppError.notFound('Staff account');
    return toPublicStaff(staff);
  },

  /** Signs out every device (including this one) and returns a fresh session for this device. */
  async changePassword(staffId: string, currentPassword: string, newPassword: string, ctx: RequestContext & { deviceInfo?: string }) {
    const staff = await staffRepository.findById(db, staffId);
    if (!staff?.isActive) throw new AppError('UNAUTHORIZED', 'Not authenticated');
    if (!(await verifyPassword(currentPassword, staff.passwordHash))) {
      throw new AppError('UNAUTHORIZED', 'Current password is incorrect', { reason: 'current_password_invalid' });
    }
    const problem = passwordProblem(newPassword, staff.username);
    if (problem) throw new AppError('VALIDATION_FAILED', problem, [{ path: 'newPassword', message: problem }]);
    if (await verifyPassword(newPassword, staff.passwordHash)) {
      throw new AppError('VALIDATION_FAILED', 'Choose a password different from the current one', [{ path: 'newPassword', message: 'Same as the current password' }]);
    }

    const passwordHash = await hashPassword(newPassword); // ~100 ms of CPU: keep it outside the transaction
    const updated = await db.transaction(async (tx) => {
      const row = await staffRepository.update(tx, staffId, {
        passwordHash,
        mustChangePassword: false,
        passwordChangedAt: new Date(),
        failedLoginCount: 0,
        lockedUntil: null,
      });
      await staffRepository.revokeAllSessions(tx, staffId);
      return row!;
    });
    staffAuthService.forgetSessions();
    logger.info({ staffId }, 'staff password changed');
    return { ...(await issueSession(updated, ctx)), staff: toPublicStaff(updated) };
  },

  /** Live session check behind requireStaff (cached briefly per session). */
  async sessionState(sessionId: string): Promise<StaffSessionState | null> {
    const hit = sessionCache.get(sessionId);
    if (hit && Date.now() - hit.at < SESSION_CACHE_MS) return hit.state;
    const state = await staffRepository.sessionState(db, sessionId);
    if (sessionCache.size > 500) sessionCache.clear();
    sessionCache.set(sessionId, { state, at: Date.now() });
    return state;
  },

  /** After disable / role change / password reset, so they apply immediately on this instance. */
  forgetSessions(): void {
    sessionCache.clear();
  },
};
