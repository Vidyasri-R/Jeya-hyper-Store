import { randomInt } from 'node:crypto';
import { AppError, PG_ERROR, pgErrorCode } from '../../common/errors';
import { hashPassword } from '../../common/password';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import type { StaffRole } from '../../db/schema';
import { staffRepository } from '../staff/staff.repository';
import { staffAuthService, toPublicStaff } from '../staff/staff-auth.service';

/** No look-alikes (0/o, 1/l/i) — read out over the phone or written on paper. */
const ALPHABET = 'abcdefghjkmnpqrstuvwxyz23456789';

/** e.g. "k7mq-p3wd-x9ta": shown once to the admin; the staff member must change it at first login. */
export function temporaryPassword(): string {
  for (;;) {
    const groups = Array.from({ length: 3 }, () => Array.from({ length: 4 }, () => ALPHABET[randomInt(ALPHABET.length)]).join(''));
    const candidate = groups.join('-');
    if (/[0-9]/.test(candidate) && /[a-z]/.test(candidate)) return candidate;
  }
}

async function adminAfterChangeGuard(targetId: string, change: { role?: StaffRole; isActive?: boolean }) {
  const target = await staffRepository.findById(db, targetId);
  if (!target) throw AppError.notFound('Staff account');
  const losesAdmin = target.role === 'admin' && target.isActive && ((change.role !== undefined && change.role !== 'admin') || change.isActive === false);
  if (losesAdmin && (await staffRepository.countActiveAdmins(db, targetId)) === 0) {
    throw new AppError('CONFLICT', 'There must always be at least one active admin', { reason: 'last_admin' });
  }
  return target;
}

export const adminStaffService = {
  async list() {
    const rows = await staffRepository.list(db);
    return rows.map((row) => ({
      ...toPublicStaff(row),
      isLocked: row.lockedUntil !== null && row.lockedUntil.getTime() > Date.now(),
      createdAt: row.createdAt,
    }));
  },

  async create(actorId: string, input: { username: string; name: string; phone?: string | null | undefined; role: StaffRole }) {
    const password = temporaryPassword();
    try {
      const staff = await staffRepository.insert(db, {
        username: input.username,
        name: input.name,
        phone: input.phone ?? null,
        role: input.role,
        passwordHash: await hashPassword(password),
        mustChangePassword: true,
        createdBy: actorId,
      });
      logger.info({ actorId, staffId: staff.id, role: staff.role }, 'staff account created');
      return { staff: toPublicStaff(staff), temporaryPassword: password };
    } catch (error) {
      if (pgErrorCode(error) === PG_ERROR.UNIQUE_VIOLATION) {
        throw new AppError('CONFLICT', 'That username is already taken', { reason: 'username_taken' });
      }
      throw error;
    }
  },

  async update(actorId: string, staffId: string, patch: { name?: string | undefined; phone?: string | null | undefined; role?: StaffRole | undefined; isActive?: boolean | undefined }) {
    if (staffId === actorId && (patch.isActive === false || patch.role === 'staff')) {
      throw new AppError('CONFLICT', "You can't disable or demote your own account", { reason: 'self_change' });
    }
    await adminAfterChangeGuard(staffId, { ...(patch.role ? { role: patch.role } : {}), ...(patch.isActive !== undefined ? { isActive: patch.isActive } : {}) });
    const updated = await db.transaction(async (tx) => {
      const row = await staffRepository.update(tx, staffId, {
        ...(patch.name !== undefined ? { name: patch.name } : {}),
        ...(patch.phone !== undefined ? { phone: patch.phone } : {}),
        ...(patch.role !== undefined ? { role: patch.role } : {}),
        ...(patch.isActive !== undefined ? { isActive: patch.isActive } : {}),
      });
      if (patch.isActive === false) await staffRepository.revokeAllSessions(tx, staffId);
      return row!;
    });
    staffAuthService.forgetSessions();
    logger.info({ actorId, staffId, patch: { ...patch, name: undefined, phone: undefined } }, 'staff account updated');
    return toPublicStaff(updated);
  },

  /** New temporary password, unlocks the account and signs it out everywhere. */
  async resetPassword(actorId: string, staffId: string) {
    const target = await staffRepository.findById(db, staffId);
    if (!target) throw AppError.notFound('Staff account');
    const password = temporaryPassword();
    const passwordHash = await hashPassword(password);
    await db.transaction(async (tx) => {
      await staffRepository.update(tx, staffId, { passwordHash, mustChangePassword: true, failedLoginCount: 0, lockedUntil: null });
      await staffRepository.revokeAllSessions(tx, staffId);
    });
    staffAuthService.forgetSessions();
    logger.warn({ actorId, staffId }, 'staff password reset by admin');
    return { temporaryPassword: password };
  },
};
