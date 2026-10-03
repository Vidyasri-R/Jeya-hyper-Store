import { describe, expect, it } from 'vitest';
import { AppError } from '../../common/errors';
import { temporaryPassword } from '../admin/admin-staff.service';
import { passwordProblem } from '../../common/password';
import { signAccessToken, verifyAccessToken } from '../auth/tokens';
import { signStaffToken, verifyStaffToken } from './staff-tokens';

const staff = { staffId: '0b6f3c2e-5d4a-4f1b-9c8d-7e6f5a4b3c2d', role: 'admin' as const, sessionId: '1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f' };

describe('staff tokens', () => {
  it('round-trips claims', () => {
    expect(verifyStaffToken(signStaffToken(staff))).toEqual(staff);
  });

  it('never accepts a customer token as a staff token, or the reverse', () => {
    const customer = signAccessToken({ userId: staff.staffId, role: 'admin', sessionId: staff.sessionId });
    expect(() => verifyStaffToken(customer)).toThrow(AppError);
    expect(() => verifyAccessToken(signStaffToken(staff))).toThrow(AppError);
  });
});

describe('temporary passwords', () => {
  it('are readable, unambiguous and pass the password rules', () => {
    for (let i = 0; i < 200; i++) {
      const password = temporaryPassword();
      expect(password).toMatch(/^[a-hjkmnp-z2-9]{4}-[a-hjkmnp-z2-9]{4}-[a-hjkmnp-z2-9]{4}$/);
      expect(passwordProblem(password, 'ravi')).toBeNull();
    }
  });
});
