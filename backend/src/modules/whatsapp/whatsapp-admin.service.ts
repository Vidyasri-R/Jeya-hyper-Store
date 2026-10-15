import { randomNumericCode } from '../../common/crypto';
import { AppError } from '../../common/errors';
import { maskPhone } from '../../common/phone';
import { logger } from '../../config/logger';
import { appConfigService, CONFIG_KEYS } from '../app-config/app-config.service';
import { whatsappLoginOn } from '../auth/otp-senders';
import { ORDER_TEMPLATES, orderUpdates, orderUpdatesSetting } from './order-updates.service';
import { accountStatus, sendLoginCode, sendTemplate, templateShapes, whatsappConfig, WhatsAppError } from './whatsapp.client';

/** Made-up values for test messages (never a real customer). */
const SAMPLES: Record<string, { body: string[]; url?: string }> = {
  order_confirmed: { body: ['Priya', 'JHS-TEST-0001', '480', 'tomorrow, 17 Oct'], url: '00000000-0000-0000-0000-000000000000' },
  order_out_for_delivery: { body: ['Priya', 'JHS-TEST-0001', '₹480 (cash or UPI at your door)'], url: '00000000-0000-0000-0000-000000000000' },
  order_delivered: { body: ['Priya', 'JHS-TEST-0001'], url: '00000000-0000-0000-0000-000000000000' },
  order_cancelled: { body: ['Priya', 'JHS-TEST-0001', 'item out of stock', 'No payment was taken.'], url: '00000000-0000-0000-0000-000000000000' },
  refund_processed: { body: ['Priya', '480', 'JHS-TEST-0001'] },
};

export const TEST_TEMPLATES = ['login_code', ...ORDER_TEMPLATES] as const;

/** Store app → More → WhatsApp login: see the set-up, send yourself a test code, switch it on. */
export const whatsappAdminService = {
  async status() {
    const config = whatsappConfig();
    const base = {
      configured: config !== null,
      loginOn: await whatsappLoginOn(),
      orderUpdatesOn: (await orderUpdatesSetting()).on,
      template: config?.template ?? null,
      phoneNumberId: config?.phoneNumberId ?? null,
      recent: await orderUpdates.recent(15),
    };
    if (!config) return { ...base, account: null, orderTemplates: [], problem: null };
    try {
      const [account, all] = await Promise.all([accountStatus(config), templateShapes(config, true)]);
      const orderTemplates = ORDER_TEMPLATES.map((name) => {
        const found = all.filter((t) => t.name === name);
        return { name, status: found.find((t) => t.status === 'APPROVED')?.status ?? found[0]?.status ?? 'MISSING', language: found[0]?.language ?? null };
      });
      return { ...base, account, orderTemplates, problem: null };
    } catch (error) {
      if (!(error instanceof WhatsAppError)) throw error;
      return { ...base, account: null, orderTemplates: [], problem: error.friendly };
    }
  },

  /** A real login_code message with a throwaway code (it can't be used to sign in). */
  async sendTest(phone: string, template: (typeof TEST_TEMPLATES)[number] = 'login_code') {
    const config = whatsappConfig();
    if (!config) throw new AppError('BAD_REQUEST', 'Add WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID on Render first');
    const code = randomNumericCode(6);
    try {
      const sample = SAMPLES[template];
      const messageId = sample ? await sendTemplate(config, template, phone, sample.body, sample.url) : await sendLoginCode(config, phone, code);
      logger.info({ phone: maskPhone(phone), messageId, template }, 'WhatsApp test message sent');
      return { sent: true, code: sample ? null : code, messageId, template };
    } catch (error) {
      if (!(error instanceof WhatsAppError)) throw error;
      logger.warn({ err: error, phone: maskPhone(phone) }, 'WhatsApp test code failed');
      throw new AppError('BAD_REQUEST', error.friendly, { metaCode: error.metaCode });
    }
  },

  async setOrderUpdates(on: boolean) {
    if (on && !whatsappConfig()) throw new AppError('BAD_REQUEST', 'Add WHATSAPP_TOKEN and WHATSAPP_PHONE_NUMBER_ID on Render first');
    const next = await orderUpdates.set(on);
    if (on) void orderUpdates.check();
    return { orderUpdatesOn: next.on };
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
