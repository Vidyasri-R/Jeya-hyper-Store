import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/core/festival.dart';
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
      expect(t?.isDiwali, isTrue);
    });

    test('off before it starts and after it ends', () {
      expect(FestivalTheme.activeFrom(theme(from: '2026-11-06T00:00:00.000Z'), now), isNull);
      expect(FestivalTheme.activeFrom(theme(until: '2026-11-04T00:00:00.000Z'), now), isNull);
    });

    test('custom greeting wins, blank falls back to the default', () {
      expect(FestivalTheme.activeFrom(theme(greeting: '  Deepavali offers are here  '), now)?.headline, 'Deepavali offers are here');
      expect(FestivalTheme.activeFrom(theme(greeting: '   '), now)?.headline, 'Happy Diwali from Jeya Hyper Store!');
    });
  });
}
