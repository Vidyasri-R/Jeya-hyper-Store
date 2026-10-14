import { randomNumericCode } from '../../common/crypto';
import { AppError } from '../../common/errors';
import { maskPhone } from '../../common/phone';
import { logger } from '../../config/logger';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';
import { whatsappLoginOn } from '../auth/otp-senders';
import { accountStatus, sendLoginCode, whatsappConfig, WhatsAppError } from './whatsapp.client';

/** Store app → More → WhatsApp login: see the set-up, send yourself a test code, switch it on. */
export const whatsappAdminService = {
  async status() {
    const config = whatsappConfig();
    const base = {
      configured: config !== null,
      loginOn: await whatsappLoginOn(),
      template: config?.template ?? null,
      phoneNumberId: config?.phoneNumberId ?? null,
    };
    if (!config) return { ...base, account: null, problem: null };
    try {
      return { ...base, account: await accountStatus(config), problem: null };
    } catch (error) {
      if (!(error instanceof WhatsAppError)) throw error;
      return { ...base, account: null, problem: error.friendly };
    }
  },

  /** A real login_code message with a throwaway code (it can't be used to sign in). */
  async sendTest(phone: string) {
    const config = whatsappConfig();
    if (!config) throw new AppError('BAD_REQUEST', 'Add WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID on Render first');
    const code = randomNumericCode(6);
    try {
      const messageId = await sendLoginCode(config, phone, code);
      logger.info({ phone: maskPhone(phone), messageId }, 'WhatsApp test code sent');
      return { sent: true, code, messageId };
    } catch (error) {
      if (!(error instanceof WhatsAppError)) throw error;
      logger.warn({ err: error, phone: maskPhone(phone) }, 'WhatsApp test code failed');
      throw new AppError('BAD_REQUEST', error.friendly, { metaCode: error.metaCode });
    }
  },

  async setLogin(on: boolean) {
    if (on && !whatsappConfig()) throw new AppError('BAD_REQUEST', 'Add WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID on Render first');
    await appConfigService.set(CONFIG_KEYS.WHATSAPP_LOGIN, on, {
      isPublic: false,
      description: 'Send customer login codes by WhatsApp (login_code template). Off = login codes are not sent.',
    });
    return { loginOn: on };
  },
};
