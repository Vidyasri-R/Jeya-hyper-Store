import { randomUUID } from 'node:crypto';
import { maskPhone } from '../../common/phone';
import { env } from '../../config/env';
import { logger } from '../../config/logger';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';
import { sendLoginCode, whatsappConfig, type WhatsAppConfig } from '../whatsapp/whatsapp.client';

export type OtpDelivery = { providerMessageId: string | null };

/** Pluggable OTP delivery: WhatsApp (Meta Cloud API `login_code` template) or the dev console. */
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

/** The `login_code` authentication template from the shop's WhatsApp Business number. */
class WhatsAppOtpSender implements OtpSender {
  readonly provider = 'whatsapp';
  readonly channel = 'whatsapp' as const;
  readonly deliversToPhone = true;

  constructor(private readonly config: WhatsAppConfig) {}

  async send(phone: string, code: string): Promise<OtpDelivery> {
    return { providerMessageId: await sendLoginCode(this.config, phone, code) };
  }
}

const consoleSender = new ConsoleOtpSender();
const whatsapp = whatsappConfig();
const whatsappSender = whatsapp ? new WhatsAppOtpSender(whatsapp) : null;

/** Admin switch (store app → More → WhatsApp login); OTP_PROVIDER is only the fallback. */
export async function whatsappLoginOn(): Promise<boolean> {
  return appConfigService.getBoolean(CONFIG_KEYS.WHATSAPP_LOGIN, env.OTP_PROVIDER === 'whatsapp');
}

/** WhatsApp when it's switched on and configured; otherwise the console sender. */
export async function currentOtpSender(): Promise<OtpSender> {
  if (!(await whatsappLoginOn())) return consoleSender;
  if (whatsappSender) return whatsappSender;
  logger.error('WhatsApp login is on but WHATSAPP_TOKEN / WHATSAPP_PHONE_NUMBER_ID are missing');
  return consoleSender;
}
