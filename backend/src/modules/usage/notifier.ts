import nodemailer from 'nodemailer';
import { env } from '../../config/env';
import { logger } from '../../config/logger';

/**
 * Pushes admin alerts outside the app. Email over SMTP for now (Gmail + an App password costs
 * nothing); WhatsApp / push notifications plug in here once those channels exist.
 * Everything is also always visible in the Jeya Staff app (admin → Usage & bills).
 */
const transport =
  env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS && env.ALERT_EMAILS.length > 0
    ? nodemailer.createTransport({
        host: env.SMTP_HOST,
        port: env.SMTP_PORT,
        secure: env.SMTP_PORT === 465,
        auth: { user: env.SMTP_USER, pass: env.SMTP_PASS },
        connectionTimeout: 15_000,
        greetingTimeout: 15_000,
        socketTimeout: 20_000,
      })
    : null;

export const notifier = {
  channels(): { email: boolean } {
    return { email: transport !== null };
  },

  /** Returns true when at least one channel accepted the message. Never throws. */
  async send(subject: string, lines: string[]): Promise<boolean> {
    if (!transport) return false;
    try {
      await transport.sendMail({
        from: env.SMTP_FROM ?? `Jeya Hyper Store <${env.SMTP_USER}>`,
        to: env.ALERT_EMAILS.join(', '),
        subject: `[Jeya] ${subject}`,
        text: [...lines, '', '— Jeya Hyper Store usage monitor. Details: Jeya Staff app → Admin → Usage & bills.'].join('\n'),
      });
      return true;
    } catch (error) {
      logger.error({ err: error }, 'alert email failed');
      return false;
    }
  },
};
