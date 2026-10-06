import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/core/store_banner.dart';
import 'package:jeya_hyper_store/widgets/store_banner_card.dart';

Map<String, dynamic> banner([Map<String, dynamic> over = const {}]) => {
      'id': 'b1',
      'active': true,
      'image': null,
      'tag': 'Diwali',
      'title': 'Sweets & snacks',
      'subtitle': 'Murukku, laddoo & more',
      'cta': 'Shop now',
      'background': '#FFF4DC',
      'link': {'type': 'search', 'value': 'sweets & snacks'},
      'startsAt': null,
      'endsAt': null,
      ...over,
    };

void main() {
  final now = DateTime.utc(2026, 10, 20, 6);

  group('StoreBanner.activeFrom', () {
    test('keeps the store order and only active banners inside their dates', () {
      final list = StoreBanner.activeFrom([
        banner({'id': 'a'}),
        banner({'id': 'off', 'active': false}),
        banner({'id': 'later', 'startsAt': '2026-10-21T00:00:00+05:30'}),
        banner({'id': 'over', 'endsAt': '2026-10-19T00:00:00+05:30'}),
        banner({'id': 'b', 'startsAt': '2026-10-19T00:00:00+05:30', 'endsAt': '2026-10-21T00:00:00+05:30'}),
      ], now);
      expect(list.map((b) => b.id), ['a', 'b']);
    });

    test('links become app routes', () {
      expect(StoreBanner.routeOf({'type': 'search', 'value': 'sweets & snacks'}), '/search?q=sweets+%26+snacks');
      expect(StoreBanner.routeOf({'type': 'category', 'value': 'staples'}), '/categories?c=staples');
      expect(StoreBanner.routeOf({'type': 'product', 'value': 'ponni-raw-rice-1-kg'}), '/product/ponni-raw-rice-1-kg');
      expect(StoreBanner.routeOf({'type': 'none'}), isNull);
      expect(StoreBanner.routeOf({'type': 'url', 'value': 'https://x.y'}), isNull);
    });

    test('skips anything malformed instead of breaking Home', () {
      expect(StoreBanner.activeFrom(null, now), isEmpty);
      expect(StoreBanner.activeFrom({'not': 'a list'}, now), isEmpty);
      final list = StoreBanner.activeFrom(['junk', 42, banner({'title': null, 'image': null}), banner({'image': 'http://insecure/x.webp', 'title': null}), banner()], now);
      expect(list, hasLength(1));
      expect(list.single.background, const Color(0xFFFFF4DC));
    });
  });

  group('StoreBannerCard', () {
    Future<void> show(WidgetTester tester, StoreBanner b, {double scale = 1.0}) async {
      await tester.binding.setSurfaceSize(const Size(320, 220));
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 220), textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: Center(child: SizedBox(width: 300, height: 176, child: StoreBannerCard(b)))),
        ),
      ));
    }

    testWidgets('text card shows tag, title, subtitle and button without overflow, even at large text', (tester) async {
      final b = StoreBanner.activeFrom([banner({'title': 'A very long festival offer title that wraps onto more lines than fit'})], now).single;
      await show(tester, b, scale: 1.1);
      expect(find.text('DIWALI'), findsOneWidget);
      expect(find.text('Shop now'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a dark card colour switches the text to white', (tester) async {
      final b = StoreBanner.activeFrom([banner({'background': '#1E4FA8'})], now).single;
      await show(tester, b);
      final title = tester.widget<Text>(find.text('Sweets & snacks'));
      expect(title.style?.color, Colors.white);
    });

    testWidgets('no link → no button, not tappable', (tester) async {
      final b = StoreBanner.activeFrom([banner({'link': {'type': 'none'}})], now).single;
      await show(tester, b);
      expect(find.text('Shop now'), findsNothing);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNull);
    });
  });
}
