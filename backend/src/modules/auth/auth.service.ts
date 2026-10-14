import { hmacSha256Hex, randomNumericCode, randomToken, safeEqual, sha256Hex } from '../../common/crypto';
import { AppError } from '../../common/errors';
import { maskPhone } from '../../common/phone';
import { env, isProduction } from '../../config/env';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import type { User } from '../../db/schema';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';
import { authRepository } from './auth.repository';
import type { VerifyOtpInput } from './auth.schemas';
import { currentOtpSender } from './otp-senders';
import { signAccessToken } from './tokens';

const OTP_LENGTH = 6;
const HOUR_MS = 60 * 60 * 1000;

type RequestContext = { ipAddress: string | null };

export type PublicUser = {
  id: string;
  phone: string;
  name: string | null;
  email: string | null;
  role: User['role'];
  profileComplete: boolean;
  createdAt: Date;
};

export type AuthTokens = {
  accessToken: string;
  accessTokenExpiresIn: number;
  refreshToken: string;
  refreshTokenExpiresAt: Date;
};

export function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    phone: user.phone,
    name: user.name,
    email: user.email,
    role: user.role,
    profileComplete: Boolean(user.name),
    createdAt: user.createdAt,
  };
}

function hashOtp(phone: string, code: string): string {
  return hmacSha256Hex(env.OTP_PEPPER, `${phone}:${code}`);
}

function refreshExpiry(): Date {
  return new Date(Date.now() + env.REFRESH_TOKEN_TTL_DAYS * 24 * HOUR_MS);
}

async function isDemoPhone(phone: string): Promise<boolean> {
  if (phone !== env.DEMO_LOGIN_PHONE) return false;
  return appConfigService.getBoolean(CONFIG_KEYS.DEMO_LOGIN_ENABLED, env.DEMO_LOGIN_ENABLED);
}

async function issueSession(
  user: User,
  meta: { deviceId?: string | undefined; deviceInfo?: string | undefined; ipAddress: string | null },
): Promise<AuthTokens> {
  const refreshToken = randomToken();
  const refreshTokenExpiresAt = refreshExpiry();
  const session = await authRepository.createSession(db, {
    userId: user.id,
    refreshTokenHash: sha256Hex(refreshToken),
    deviceId: meta.deviceId ?? null,
    deviceInfo: meta.deviceInfo ?? null,
    ipAddress: meta.ipAddress,
    expiresAt: refreshTokenExpiresAt,
  });

  return {
    accessToken: signAccessToken({ userId: user.id, role: user.role, sessionId: session.id }),
    accessTokenExpiresIn: env.ACCESS_TOKEN_TTL_SEC,
    refreshToken,
    refreshTokenExpiresAt,
  };
}

export const authService = {
  async requestOtp(phone: string, ctx: RequestContext) {
    const otpSender = await currentOtpSender();
    const response = {
      phone: maskPhone(phone),
      expiresInSec: env.OTP_TTL_SEC,
      resendAfterSec: env.OTP_RESEND_COOLDOWN_SEC,
      channel: otpSender.channel,
    };

    // Reviewer account: nothing is sent; the fixed demo code is accepted at verify.
    if (await isDemoPhone(phone)) {
      logger.warn({ phone: maskPhone(phone), ip: ctx.ipAddress }, 'demo login: OTP request (no message sent)');
      return response;
    }

    // Until a real provider is configured, production must not hand out codes via logs.
    if (isProduction && !otpSender.deliversToPhone) {
      throw new AppError('UPSTREAM_UNAVAILABLE', 'OTP login is not available yet. Please try again later.');
    }

    const code = randomNumericCode(OTP_LENGTH);

    const otp = await db.transaction(async (tx) => {
      await authRepository.lockPhone(tx, phone);

      const stats = await authRepository.otpIssueStats(tx, phone, ctx.ipAddress, new Date(Date.now() - HOUR_MS));

      if (stats.lastForPhone) {
        const elapsedSec = Math.floor((Date.now() - stats.lastForPhone.getTime()) / 1000);
        const waitSec = env.OTP_RESEND_COOLDOWN_SEC - elapsedSec;
        if (waitSec > 0) {
          throw new AppError('RATE_LIMITED', `Please wait ${waitSec}s before requesting another OTP`, {
            retryAfterSec: waitSec,
          });
        }
      }
      if (stats.phoneCount >= env.OTP_MAX_PER_PHONE_PER_HOUR) {
        throw new AppError('RATE_LIMITED', 'Too many OTP requests for this number. Try again in an hour.', {
          retryAfterSec: 3600,
        });
      }
      if (stats.ipCount >= env.OTP_MAX_PER_IP_PER_HOUR) {
        throw new AppError('RATE_LIMITED', 'Too many OTP requests. Try again later.', { retryAfterSec: 3600 });
      }

      await authRepository.expireActiveOtpsForPhone(tx, phone);
      return authRepository.insertOtp(tx, {
        phone,
        otpHash: hashOtp(phone, code),
        channel: otpSender.channel,
        ipAddress: ctx.ipAddress,
        expiresAt: new Date(Date.now() + env.OTP_TTL_SEC * 1000),
      });
    });

    // Send outside the transaction — never hold a DB connection across a network call.
    try {
      const delivery = await otpSender.send(phone, code, env.OTP_TTL_SEC);
      await authRepository.setOtpProviderMessageId(db, otp.id, delivery.providerMessageId);
    } catch (error) {
      logger.error({ err: error, phone: maskPhone(phone), provider: otpSender.provider }, 'OTP delivery failed');
      // Still counts toward rate limits (abuse protection), but can't be used.
      await authRepository.expireOtp(db, otp.id).catch(() => undefined);
      throw new AppError('UPSTREAM_UNAVAILABLE', 'Could not send OTP right now. Please try again.');
    }

    return response;
  },

  async verifyOtp(input: VerifyOtpInput, ctx: RequestContext) {
    const { phone, otp } = input;

    if (await isDemoPhone(phone)) {
      if (!safeEqual(otp, env.DEMO_LOGIN_OTP)) {
        throw new AppError('UNAUTHORIZED', 'Incorrect OTP', { reason: 'otp_incorrect' });
      }
      logger.warn({ phone: maskPhone(phone), ip: ctx.ipAddress }, 'demo login: signed in');
    } else {
      const active = await authRepository.findLatestActiveOtp(db, phone);
      if (!active) {
        throw new AppError('UNAUTHORIZED', 'OTP expired or not requested. Please request a new one.', {
          reason: 'otp_expired',
        });
      }
      if (active.attempts >= env.OTP_MAX_VERIFY_ATTEMPTS) {
        throw new AppError('RATE_LIMITED', 'Too many incorrect attempts. Please request a new OTP.', {
          reason: 'otp_locked',
        });
      }

      if (!safeEqual(hashOtp(phone, otp), active.otpHash)) {
        const attempts = await authRepository.incrementOtpAttempts(db, active.id);
        const remaining = Math.max(0, env.OTP_MAX_VERIFY_ATTEMPTS - attempts);
        throw new AppError(
          remaining === 0 ? 'RATE_LIMITED' : 'UNAUTHORIZED',
          remaining === 0 ? 'Too many incorrect attempts. Please request a new OTP.' : 'Incorrect OTP',
          { reason: remaining === 0 ? 'otp_locked' : 'otp_incorrect', attemptsRemaining: remaining },
        );
      }

      if (!(await authRepository.consumeOtp(db, active.id))) {
        throw new AppError('UNAUTHORIZED', 'OTP already used. Please request a new one.', { reason: 'otp_used' });
      }
    }

    const { user, isNewUser } = await authRepository.findOrCreateUserByPhone(db, phone);
    if (user.isBlocked) {
      throw new AppError('FORBIDDEN', 'This account has been blocked. Please contact the store.');
    }

    const tokens = await issueSession(user, { deviceId: input.deviceId, deviceInfo: input.deviceInfo, ...ctx });
    await authRepository.touchLastLogin(db, user.id);

    logger.info({ userId: user.id, isNewUser }, 'user signed in');
    return { ...tokens, isNewUser, user: toPublicUser(user) };
  },

  async refresh(refreshToken: string): Promise<AuthTokens> {
    const nextToken = randomToken();
    const nextExpiresAt = refreshExpiry();
    const session = await authRepository.rotateSession(db, sha256Hex(refreshToken), sha256Hex(nextToken), nextExpiresAt);
    if (!session) {
      throw new AppError('UNAUTHORIZED', 'Session expired. Please log in again.', { reason: 'refresh_invalid' });
    }

    // Role is re-read so a promotion/demotion takes effect on the next refresh.
    const current = await authRepository.findActiveUserById(db, session.userId);
    if (!current) {
      throw new AppError('UNAUTHORIZED', 'Session expired. Please log in again.', { reason: 'refresh_invalid' });
    }

    return {
      accessToken: signAccessToken({ userId: current.id, role: current.role, sessionId: session.id }),
      accessTokenExpiresIn: env.ACCESS_TOKEN_TTL_SEC,
      refreshToken: nextToken,
      refreshTokenExpiresAt: nextExpiresAt,
    };
  },

  async logout(refreshToken: string): Promise<void> {
    await authRepository.revokeSessionByHash(db, sha256Hex(refreshToken));
  },
};
