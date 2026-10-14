import { afterEach, describe, expect, it, vi } from 'vitest';
import { loginCodeMessage, sendLoginCode, WhatsAppError, type WhatsAppConfig } from './whatsapp.client';

const config: WhatsAppConfig = {
  token: 'x'.repeat(60),
  phoneNumberId: '1320653831138892',
  businessAccountId: '4062669760702363',
  template: 'login_code',
  language: 'en',
  graphVersion: 'v25.0',
};

afterEach(() => vi.unstubAllGlobals());

describe('WhatsApp login code', () => {
  it('puts the code in the body and the Copy code button', () => {
    const message = loginCodeMessage(config, '919876543210', '482913');
    expect(message.to).toBe('919876543210');
    expect(message.template).toEqual({
      name: 'login_code',
      language: { code: 'en' },
      components: [
        { type: 'body', parameters: [{ type: 'text', text: '482913' }] },
        { type: 'button', sub_type: 'url', index: '0', parameters: [{ type: 'text', text: '482913' }] },
      ],
    });
  });

  it('posts to the phone number id and returns the message id', async () => {
    const fetchMock = vi.fn(async () => new Response(JSON.stringify({ messages: [{ id: 'wamid.ABC' }] }), { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);
    await expect(sendLoginCode(config, '919876543210', '111222')).resolves.toBe('wamid.ABC');
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://graph.facebook.com/v25.0/1320653831138892/messages');
    expect((init.headers as Record<string, string>).Authorization).toBe(`Bearer ${config.token}`);
  });

  it('explains Meta refusals in plain words', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => new Response(JSON.stringify({ error: { code: 190, message: 'Invalid OAuth access token' } }), { status: 401 })),
    );
    const error = await sendLoginCode(config, '919876543210', '111222').catch((e: unknown) => e);
    expect(error).toBeInstanceOf(WhatsAppError);
    expect((error as WhatsAppError).metaCode).toBe(190);
    expect((error as WhatsAppError).friendly).toMatch(/token/);
  });
});
