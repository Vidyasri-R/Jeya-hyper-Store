import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/features/profile/info_screens.dart';
import 'package:jeya_hyper_store/state/providers.dart';

/// What Admin → Store settings saves, as GET /v1/config serves it.
Map<String, dynamic> settings({String? freeAbove = '1499.00', String minOrder = '199.00', bool cod = false, bool online = true}) => {
  'delivery.rules': {
    'freeDeliveryAbove': freeAbove,
    'minOrderAmount': minOrder,
    'deliveryDays': 0,
    'tiers': [
      {'upToKm': 6, 'fee': '40.00'},
      {'upToKm': 3, 'fee': '25.00'},
    ],
  },
  'checkout.payment_methods': {'cod': cod, 'online': online},
  'store.info': {'name': 'Jeya Hyper Store', 'city': 'Tiruchirappalli', 'address': '12 Main Road, Thillai Nagar', 'openingHours': '7 AM – 10 PM', 'supportPhone': '+91 90000 90000'},
};

void main() {
  group('StoreRules.from', () {
    test('defaults until the store settings arrive', () {
      const r = StoreRules();
      final d = StoreRules.from(null);
      expect([d.freeAbovePaise, d.minOrderPaise, d.cod, d.online], [r.freeAbovePaise, 0, true, true]);
    });

    test('reads delivery charges, minimum order and payment options', () {
      final r = StoreRules.from(settings());
      expect(r.freeAbovePaise, 149900);
      expect(r.minOrderPaise, 19900);
      expect(r.lowestFeePaise, 2500);
      expect(r.cod, isFalse);
      expect(r.online, isTrue);
    });

    test('no free delivery when the store clears the amount', () {
      expect(StoreRules.from(settings(freeAbove: null)).freeAbovePaise, isNull);
    });
  });

  testWidgets('help and about follow the store settings', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Future<void> pump(Widget screen, Map<String, dynamic> config) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [publicConfigProvider.overrideWith((ref) async => config)],
        child: MaterialApp(theme: ThemeData(useMaterial3: true), home: screen),
      ));
      await tester.pumpAndSettle();
    }

    await pump(const HelpScreen(), settings());
    for (final q in ['Is delivery free?', 'Is there a minimum order?', 'How can I pay?', 'When will my order arrive?']) {
      await tester.tap(find.text(q));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('free on orders of ₹1,499 and above'), findsOneWidget);
    expect(find.textContaining('(from ₹25)'), findsOneWidget);
    expect(find.textContaining('at least ₹199'), findsOneWidget);
    expect(find.text('Pay online with UPI, cards or netbanking.'), findsOneWidget);
    expect(find.textContaining('Same-day delivery'), findsOneWidget);

    await pump(const AboutScreen(), settings());
    expect(find.text('12 Main Road, Thillai Nagar'), findsOneWidget);
    expect(find.text('7 AM – 10 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('address map tiles', () {
    test('come from map.tiles, so they can move to the custom domain without an update', () {
      final t = MapTiles.from({'url': 'https://maps.example.in/trichy/v2/{z}/{x}/{y}.webp', 'minZoom': 12, 'maxNativeZoom': 15, 'bounds': [78.4, 10.6, 78.9, 11.0]});
      expect(t.url, 'https://maps.example.in/trichy/v2/{z}/{x}/{y}.webp');
      expect(t.minZoom, 12);
      expect(t.maxNativeZoom, 15);
      expect(t.bounds, [78.4, 10.6, 78.9, 11.0]);
    });

    test('fall back to our own R2 tiles when the setting is missing or broken', () {
      expect(MapTiles.from(null).url, MapTiles.fallback.url);
      expect(MapTiles.from({'url': 42}).url, contains('/maps/trichy/'));
      expect(MapTiles.from({'url': 'https://x/{z}/{x}/{y}.webp', 'bounds': [1, 2]}).bounds, MapTiles.fallback.bounds);
    });
  });
}
