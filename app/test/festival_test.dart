import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/core/festival.dart';
import 'package:jeya_hyper_store/core/festival_pack.dart';
import 'package:jeya_hyper_store/core/theme.dart';

void main() {
  final now = DateTime.utc(2026, 11, 5, 10).toLocal();
  Map<String, dynamic> theme({String preset = 'diwali', String? from, String? until, String? greeting}) =>
      {'preset': preset, 'startsAt': from, 'endsAt': until, 'greeting': greeting};

  group('FestivalTheme.activeFrom', () {
    test('everyday look when nothing is set or the preset is standard/unknown', () {
      expect(FestivalTheme.activeFrom(null, now), isNull);
      expect(FestivalTheme.activeFrom('diwali', now), isNull);
      expect(FestivalTheme.activeFrom(theme(preset: 'standard'), now), isNull);
      expect(FestivalTheme.activeFrom(theme(preset: 'holi'), now), isNull);
    });

    test('on with no dates, and inside its dates', () {
      expect(FestivalTheme.activeFrom(theme(), now)?.palette, same(Palettes.diwali));
      final t = FestivalTheme.activeFrom(theme(from: '2026-10-31T18:30:00.000Z', until: '2026-11-10T18:29:59.000Z'), now);
      expect(t?.pack?.id, 'diwali');
    });

    test('Christmas greets with the season: Christmas first, then the New Year', () {
      final pack = FestivalPacks.christmas;
      expect(pack.greetingOn(DateTime(2026, 12, 20)), 'Merry Christmas');
      expect(pack.greetingOn(DateTime(2026, 12, 25)), 'Merry Christmas');
      expect(pack.greetingOn(DateTime(2026, 12, 26)), 'Happy New Year');
      expect(pack.greetingOn(DateTime(2027, 1, 2)), 'Happy New Year');
      expect(pack.greetingOn(DateTime(2026, 10, 3)), 'Merry Christmas'); // switched on early
      expect(FestivalPacks.pongal.greetingOn(DateTime(2027, 1, 14)), 'Happy Pongal');
    });

    test("Valentine's Day has its own look", () {
      final t = FestivalTheme.activeFrom(theme(preset: 'valentine'), now);
      expect(t?.palette, same(Palettes.valentine));
      expect(t?.pack?.greetingOn(DateTime(2027, 2, 14)), 'Happy Valentine’s Day');
    });

    test('Tamil New Year has its own look', () {
      final t = FestivalTheme.activeFrom(theme(preset: 'puthandu'), now);
      expect(t?.palette, same(Palettes.puthandu));
      expect(t?.pack?.greetingOn(DateTime(2027, 4, 14)), 'Happy Tamil New Year');
      expect(t?.pack?.haloImage, 'assets/themes/puthandu/lotus.webp');
    });

    test('Pongal has its own look', () {
      final t = FestivalTheme.activeFrom(theme(preset: 'pongal'), now);
      expect(t?.palette, same(Palettes.pongal));
      expect(t?.pack?.greeting, 'Happy Pongal');
    });

    test('off before it starts and after it ends', () {
      expect(FestivalTheme.activeFrom(theme(from: '2026-11-06T00:00:00.000Z'), now), isNull);
      expect(FestivalTheme.activeFrom(theme(until: '2026-11-04T00:00:00.000Z'), now), isNull);
    });

    test("the store's own message is trimmed; blank means the default line", () {
      expect(FestivalTheme.activeFrom(theme(greeting: '  Deepavali offers are here  '), now)?.message, 'Deepavali offers are here');
      expect(FestivalTheme.activeFrom(theme(greeting: '   '), now)?.message, isNull);
      expect(FestivalTheme.activeFrom(theme(), now)?.message, isNull);
    });
  });
}
