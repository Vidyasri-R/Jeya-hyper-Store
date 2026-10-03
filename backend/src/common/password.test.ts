import { describe, expect, it } from 'vitest';
import { hashPassword, passwordProblem, verifyPassword } from './password';

describe('password hashing', () => {
  it('verifies the right password and rejects a wrong one', async () => {
    const stored = await hashPassword('Ponni-rice-2026');
    expect(stored).toMatch(/^scrypt\$32768\$8\$1\$[A-Za-z0-9+/=]+\$[A-Za-z0-9+/=]+$/);
    expect(await verifyPassword('Ponni-rice-2026', stored)).toBe(true);
    expect(await verifyPassword('ponni-rice-2026', stored)).toBe(false);
  });

  it('salts every hash', async () => {
    expect(await hashPassword('same-pass-123')).not.toBe(await hashPassword('same-pass-123'));
  });

  it('treats malformed stored values as a non-match instead of throwing', async () => {
    expect(await verifyPassword('anything1', 'plaintext')).toBe(false);
    expect(await verifyPassword('anything1', 'bcrypt$x$y')).toBe(false);
  });
});

describe('password rules', () => {
  it.each([
    ['short1', 'at least 8'],
    ['onlyletters', 'letter and one number'],
    ['12345678', 'letter and one number'],
    ['ravi.packing99', 'username'],
    ['password1', 'too easy'],
  ])('rejects %s', (password, message) => {
    expect(passwordProblem(password, 'ravi.packing')).toContain(message);
  });

  it('accepts a reasonable password', () => {
    expect(passwordProblem('Thillai-nagar-42', 'ravi.packing')).toBeNull();
  });
});
