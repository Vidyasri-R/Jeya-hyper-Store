import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['src/**/*.test.ts'],
    // Unit tests never touch a real DB; these just satisfy env validation.
    env: {
      NODE_ENV: 'test',
      LOG_LEVEL: 'silent',
      DATABASE_URL: 'postgresql://test:test@127.0.0.1:6543/test',
      DIRECT_DATABASE_URL: 'postgresql://test:test@127.0.0.1:5432/test',
      JWT_ACCESS_SECRET: 'test-access-secret-that-is-at-least-32-chars',
      OTP_PEPPER: 'test-otp-pepper-that-is-at-least-32-characters',
    },
  },
});
