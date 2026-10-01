import jwt from 'jsonwebtoken';
import { describe, expect, it } from 'vitest';
import { randomNumericCode, safeEqual } from '../../common/crypto';
import { AppError } from '../../common/errors';
import { signAccessToken, verifyAccessToken } from './tokens';

const claims = { userId: '6f1c1d0e-3a1b-4c5d-8e9f-0a1b2c3d4e5f', role: 'customer' as const, sessionId: 's-1' };

function expectUnauthorized(fn: () => unknown, reason: string) {
  try {
    fn();
    expect.unreachable('should have thrown');
  } catch (error) {
    expect(error).toBeInstanceOf(AppError);
    expect((error as AppError).status).toBe(401);
    expect((error as AppError).details).toMatchObject({ reason });
  }
}

describe('access tokens', () => {
  it('round-trips claims', () => {
    expect(verifyAccessToken(signAccessToken(claims))).toEqual(claims);
  });

  it('rejects a token signed with another secret', () => {
    const forged = jwt.sign({ role: 'admin', sid: 'x', typ: 'access' }, 'attacker-secret-attacker-secret-1234', {
      subject: claims.userId,
      issuer: 'jeya-api',
      audience: 'jeya-app',
    });
    expectUnauthorized(() => verifyAccessToken(forged), 'token_invalid');
  });

  it('rejects alg=none', () => {
    const unsigned = jwt.sign({ role: 'admin', sid: 'x', typ: 'access' }, '', {
      algorithm: 'none',
      subject: claims.userId,
      issuer: 'jeya-api',
      audience: 'jeya-app',
    });
    expectUnauthorized(() => verifyAccessToken(unsigned), 'token_invalid');
  });

  it('reports expiry distinctly so the app knows to refresh', () => {
    const expired = jwt.sign(
      { role: 'customer', sid: 's-1', typ: 'access', exp: Math.floor(Date.now() / 1000) - 10 },
      process.env.JWT_ACCESS_SECRET as string,
      { subject: claims.userId, issuer: 'jeya-api', audience: 'jeya-app' },
    );
    expectUnauthorized(() => verifyAccessToken(expired), 'token_expired');
  });

  it('rejects an unknown role', () => {
    const bad = jwt.sign({ role: 'superuser', sid: 's-1', typ: 'access' }, process.env.JWT_ACCESS_SECRET as string, {
      subject: claims.userId,
      issuer: 'jeya-api',
      audience: 'jeya-app',
    });
    expectUnauthorized(() => verifyAccessToken(bad), 'token_invalid');
  });
});

describe('crypto helpers', () => {
  it('generates zero-padded 6-digit codes', () => {
    for (let i = 0; i < 500; i++) expect(randomNumericCode(6)).toMatch(/^[0-9]{6}$/);
  });

  it('compares safely', () => {
    expect(safeEqual('123456', '123456')).toBe(true);
    expect(safeEqual('123456', '123457')).toBe(false);
    expect(safeEqual('123456', '12345')).toBe(false);
  });
});
