import { beforeEach, describe, expect, it, vi } from 'vitest';
import { adminSettingsService } from './admin-settings.service';

// The settings service only needs the config store; keep it in memory (no database).
// vi.mock is hoisted above the imports, so the service picks up this fake.
const stored = vi.hoisted(() => new Map<string, { value: unknown; isPublic: boolean }>());
vi.mock('../app-config/app-config.service', async (original) => {
  const actual = await original<typeof import('../app-config/app-config.service')>();
  return {
    ...actual,
    appConfigService: {
      getRaw: async (key: string) => stored.get(key)?.value,
      set: async (key: string, value: unknown, meta: { isPublic: boolean }) => {
        stored.set(key, { value, isPublic: meta.isPublic });
      },
    },
  };
});

describe('festival theme setting (app.theme)', () => {
  beforeEach(() => stored.clear());

  it('starts as the everyday look', async () => {
    const all = await adminSettingsService.all();
    expect(all['app.theme']).toEqual({ preset: 'standard', startsAt: null, endsAt: null, greeting: null });
  });

  it('saves exactly what the store app sends, served to the customer app', async () => {
    // Staff app: dates are local midnight / 23:59:59 sent as UTC ISO (Dart toUtc().toIso8601String()).
    const value = { preset: 'diwali', startsAt: '2026-10-31T18:30:00.000Z', endsAt: '2026-11-10T18:29:59.000Z', greeting: 'Festive offers on sweets' };
    await expect(adminSettingsService.set('app.theme', value)).resolves.toEqual(value);
    expect(stored.get('app.theme')).toEqual({ value, isPublic: true });
  });

  it('offers every festival the customer app has art for', async () => {
    for (const preset of ['standard', 'diwali', 'pongal', 'christmas']) {
      await expect(adminSettingsService.set('app.theme', { preset, startsAt: null, endsAt: null, greeting: null })).resolves.toMatchObject({ preset });
    }
  });

  it('accepts open-ended dates and trims the message', async () => {
    const saved = await adminSettingsService.set('app.theme', { preset: 'diwali', startsAt: null, endsAt: null, greeting: '  Happy Deepavali!  ' });
    expect(saved).toEqual({ preset: 'diwali', startsAt: null, endsAt: null, greeting: 'Happy Deepavali!' });
  });

  it.each([
    ['an end before the start', { preset: 'diwali', startsAt: '2026-11-10T00:00:00.000Z', endsAt: '2026-11-01T00:00:00.000Z', greeting: null }],
    ['a preset the app has no art for', { preset: 'holi', startsAt: null, endsAt: null, greeting: null }],
    ['a message over 120 characters', { preset: 'diwali', startsAt: null, endsAt: null, greeting: 'x'.repeat(121) }],
    ['a date that is not a time', { preset: 'diwali', startsAt: '1 Nov', endsAt: null, greeting: null }],
    ['unknown fields', { preset: 'diwali', startsAt: null, endsAt: null, greeting: null, colour: 'red' }],
  ])('rejects %s', async (_case, value) => {
    await expect(adminSettingsService.set('app.theme', value)).rejects.toThrow();
    expect(stored.has('app.theme')).toBe(false);
  });
});
