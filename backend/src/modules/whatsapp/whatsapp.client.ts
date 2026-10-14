import { env } from '../../config/env';

/**
 * WhatsApp Cloud API (Meta Graph) — only what the shop needs: the `login_code` authentication
 * template and a status read for the store app. The token is a permanent system-user token.
 */

const TIMEOUT_MS = 10_000;

export type WhatsAppConfig = {
  token: string;
  phoneNumberId: string;
  businessAccountId: string | null;
  template: string;
  language: string;
  graphVersion: string;
};

export function whatsappConfig(): WhatsAppConfig | null {
  if (!env.WHATSAPP_TOKEN || !env.WHATSAPP_PHONE_NUMBER_ID) return null;
  return {
    token: env.WHATSAPP_TOKEN,
    phoneNumberId: env.WHATSAPP_PHONE_NUMBER_ID,
    businessAccountId: env.WHATSAPP_BUSINESS_ACCOUNT_ID ?? null,
    template: env.WHATSAPP_OTP_TEMPLATE,
    language: env.WHATSAPP_OTP_LANGUAGE,
    graphVersion: env.WHATSAPP_GRAPH_VERSION,
  };
}

/** A refusal from Meta, with a sentence the store app can show as it is. */
export class WhatsAppError extends Error {
  constructor(
    message: string,
    readonly metaCode: number | null,
    readonly friendly: string,
  ) {
    super(message);
    this.name = 'WhatsAppError';
  }
}

/** Meta error codes we can explain to the admin (others show Meta's own message). */
const FRIENDLY: Record<number, string> = {
  190: 'The WhatsApp token is wrong or was revoked — make a new one for the system user jhs-api.',
  200: 'The WhatsApp token is missing a permission — tick whatsapp_business_messaging when you generate it.',
  10: 'The WhatsApp token is missing a permission — tick whatsapp_business_messaging when you generate it.',
  100: 'Meta rejected the request — check the Phone number ID.',
  131026: 'This number can’t receive WhatsApp messages (not on WhatsApp, or an old WhatsApp version).',
  131030: 'This number isn’t in the test number’s recipient list.',
  131042: 'Meta has a payment problem with the WhatsApp account — check the card in WhatsApp Manager.',
  131047: 'WhatsApp only allows a template message here.',
  131056: 'Too many messages to this number in a short time — wait a minute.',
  130429: 'WhatsApp is limiting how fast we send — try again in a minute.',
  131048: 'WhatsApp limited this number for spam reports — check the quality rating in WhatsApp Manager.',
  132000: 'The login_code template expects a different number of values.',
  132001: 'The login_code template wasn’t found in this language — check WhatsApp Manager → Message templates.',
  133010: 'The business phone number isn’t registered with the WhatsApp API yet.',
  368: 'Meta has temporarily blocked the WhatsApp account — check Account overview in WhatsApp Manager.',
};

type GraphError = { error?: { message?: string; code?: number; error_data?: { details?: string } } };

async function graph<T>(config: WhatsAppConfig, path: string, init?: { method: 'POST'; body: unknown }): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`https://graph.facebook.com/${config.graphVersion}/${path}`, {
      method: init?.method ?? 'GET',
      headers: { Authorization: `Bearer ${config.token}`, ...(init ? { 'Content-Type': 'application/json' } : {}) },
      body: init ? JSON.stringify(init.body) : null,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (error) {
    throw new WhatsAppError(`WhatsApp request failed: ${(error as Error).message}`, null, 'Could not reach WhatsApp — try again.');
  }
  const body = (await response.json().catch(() => ({}))) as T & GraphError;
  if (!response.ok || body.error) {
    const code = body.error?.code ?? null;
    const detail = body.error?.error_data?.details ?? body.error?.message ?? `HTTP ${response.status}`;
    throw new WhatsAppError(`WhatsApp ${code ?? response.status}: ${detail}`, code, (code !== null && FRIENDLY[code]) || detail);
  }
  return body;
}

/** The request body for the authentication template: the code fills the text and the Copy code button. */
export function loginCodeMessage(config: Pick<WhatsAppConfig, 'template' | 'language'>, phone: string, code: string) {
  return {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to: phone,
    type: 'template',
    template: {
      name: config.template,
      language: { code: config.language },
      components: [
        { type: 'body', parameters: [{ type: 'text', text: code }] },
        { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: code }] },
      ],
    },
  };
}

/** Sends the login code; returns Meta's message id. [phone] = "91" + 10 digits. */
export async function sendLoginCode(config: WhatsAppConfig, phone: string, code: string): Promise<string | null> {
  const result = await graph<{ messages?: { id?: string }[] }>(config, `${config.phoneNumberId}/messages`, {
    method: 'POST',
    body: loginCodeMessage(config, phone, code),
  });
  return result.messages?.[0]?.id ?? null;
}

export type WhatsAppNumberStatus = {
  displayPhoneNumber: string | null;
  verifiedName: string | null;
  nameStatus: string | null;
  qualityRating: string | null;
  messagingLimit: string | null;
};

export type WhatsAppTemplateStatus = { name: string; language: string; status: string; category: string | null };

/** What the store app shows: the sending number and whether the login template is approved. */
export async function accountStatus(config: WhatsAppConfig): Promise<{ number: WhatsAppNumberStatus; templates: WhatsAppTemplateStatus[] }> {
  const number = await graph<{
    display_phone_number?: string;
    verified_name?: string;
    name_status?: string;
    quality_rating?: string;
    messaging_limit_tier?: string;
  }>(config, `${config.phoneNumberId}?fields=display_phone_number,verified_name,name_status,quality_rating,messaging_limit_tier`);
  const templates = config.businessAccountId
    ? (
        await graph<{ data?: { name: string; language: string; status: string; category?: string }[] }>(
          config,
          `${config.businessAccountId}/message_templates?name=${encodeURIComponent(config.template)}&fields=name,language,status,category`,
        )
      ).data ?? []
    : [];
  return {
    number: {
      displayPhoneNumber: number.display_phone_number ?? null,
      verifiedName: number.verified_name ?? null,
      nameStatus: number.name_status ?? null,
      qualityRating: number.quality_rating ?? null,
      messagingLimit: number.messaging_limit_tier ?? null,
    },
    templates: templates
      .filter((t) => t.name === config.template)
      .map((t) => ({ name: t.name, language: t.language, status: t.status, category: t.category ?? null })),
  };
}
