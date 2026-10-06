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
    for (const preset of ['standard', 'diwali', 'pongal', 'christmas', 'valentine', 'puthandu', 'eid', 'national', 'vinayagar', 'navaratri', 'karthigai']) {
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

describe('brand colour setting (app.brand)', () => {
  beforeEach(() => stored.clear());

  it('starts as the Jeya green', async () => {
    expect((await adminSettingsService.all())['app.brand']).toEqual({ color: '#1B7A3E' });
  });

  it('saves any #RRGGBB colour, upper-cased, served to the customer app', async () => {
    await expect(adminSettingsService.set('app.brand', { color: ' #1e4fa8 ' })).resolves.toEqual({ color: '#1E4FA8' });
    expect(stored.get('app.brand')).toEqual({ value: { color: '#1E4FA8' }, isPublic: true });
  });

  it.each([['a name', { color: 'blue' }], ['short hex', { color: '#14f' }], ['extra keys', { color: '#1E4FA8', x: 1 }], ['nothing', {}]])(
    'rejects %s',
    async (_case, value) => {
      await expect(adminSettingsService.set('app.brand', value)).rejects.toThrow();
      expect(stored.has('app.brand')).toBe(false);
    },
  );
});

describe('home banners (home.banners)', () => {
  beforeEach(() => stored.clear());
  const base = process.env.R2_PUBLIC_BASE_URL ?? 'https://cdn.example.com';
  const banner = (over: Record<string, unknown> = {}) => ({
    id: 'banner-1',
    active: true,
    image: `${base}/banners/0123456789abcdef.webp`,
    tag: 'DIWALI',
    title: 'Sweets & snacks',
    subtitle: 'Murukku, laddoo & more',
    cta: 'Shop now',
    background: '#fff4dc',
    link: { type: 'search', value: 'sweets' },
    startsAt: null,
    endsAt: null,
    ...over,
  });

  it('starts empty (the app keeps its built-in banners)', async () => {
    expect((await adminSettingsService.all())['home.banners']).toEqual([]);
  });

  it('saves banners in order, served to the customer app', async () => {
    const saved = (await adminSettingsService.set('home.banners', [
      banner(),
      banner({ id: 'banner-2', image: null, tag: '  ', link: { type: 'category', value: 'staples' } }),
      banner({ id: 'banner-3', title: null, link: { type: 'product', value: 'jeya-select-ponni-raw-rice-1-kg' } }),
    ])) as Array<{ background: string | null; tag: string | null }>;
    expect(saved).toHaveLength(3);
    expect(saved[0]?.background).toBe('#FFF4DC');
    expect(saved[1]?.tag).toBeNull();
    expect(stored.get('home.banners')?.isPublic).toBe(true);
  });

  it.each([
    ['no image and no title', [banner({ image: null, title: null })]],
    ['an image from elsewhere', [banner({ image: 'https://evil.example.com/x.webp' })]],
    ['a search with no words', [banner({ link: { type: 'search', value: ' ' } })]],
    ['a bad category', [banner({ link: { type: 'category', value: 'Rice & Dal' } })]],
    ['a link type we do not support', [banner({ link: { type: 'url', value: 'https://x.y' } })]],
    ['end before start', [banner({ startsAt: '2026-10-20T00:00:00+05:30', endsAt: '2026-10-19T00:00:00+05:30' })]],
    ['duplicate ids', [banner(), banner()]],
    ['too many', Array.from({ length: 9 }, (_, i) => banner({ id: `banner-${i}x` }))],
  ])('rejects %s', async (_case, value) => {
    await expect(adminSettingsService.set('home.banners', value)).rejects.toThrow();
    expect(stored.has('home.banners')).toBe(false);
  });
});
