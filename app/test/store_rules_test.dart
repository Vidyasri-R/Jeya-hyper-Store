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
}
