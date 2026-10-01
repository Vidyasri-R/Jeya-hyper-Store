import { randomUUID } from 'node:crypto';
import { maskPhone } from '../../common/phone';
import { env } from '../../config/env';
import { logger } from '../../config/logger';

export type OtpDelivery = { providerMessageId: string | null };

/**
 * Pluggable OTP delivery. To add WhatsApp: implement this interface in a
 * WhatsAppOtpSender (Meta Cloud API authentication template), add 'whatsapp'
 * to OTP_PROVIDER in env.ts, and return it from createOtpSender().
 */
export interface OtpSender {
  readonly provider: string;
  readonly channel: 'whatsapp' | 'sms';
  /** True if this sender actually reaches the user's phone. */
  readonly deliversToPhone: boolean;
  send(phone: string, code: string, ttlSec: number): Promise<OtpDelivery>;
}

/** Development sender: prints the code to the server log. Never reaches a phone. */
class ConsoleOtpSender implements OtpSender {
  readonly provider = 'console';
  readonly channel = 'whatsapp' as const;
  readonly deliversToPhone = false;

  async send(phone: string, code: string, ttlSec: number): Promise<OtpDelivery> {
    logger.warn({ phone: maskPhone(phone), otp_dev_only: code, ttlSec }, '📟 [console OTP] code generated');
    return { providerMessageId: `console:${randomUUID()}` };
  }
}

function createOtpSender(): OtpSender {
  switch (env.OTP_PROVIDER) {
    case 'console':
      return new ConsoleOtpSender();
  }
}

export const otpSender: OtpSender = createOtpSender();
