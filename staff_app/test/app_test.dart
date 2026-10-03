import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeya_staff/core/api/api_client.dart';
import 'package:jeya_staff/core/api/token_store.dart';
import 'package:jeya_staff/data/models.dart';
import 'package:jeya_staff/data/repository.dart';
import 'package:jeya_staff/features/admin/settings_screen.dart';
import 'package:jeya_staff/router.dart';
import 'package:jeya_staff/state/providers.dart';

/// Fixtures are real API responses (reviewer demo account only), see backend/docs/staff-api.md.
Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

final admin = Staff.fromJson({'id': 'a1', 'username': 'jeya.admin', 'name': 'Store Admin', 'role': 'admin', 'mustChangePassword': false, 'isActive': true});

Map<String, dynamic> orderAt(String status, {Map<String, dynamic>? next, bool packed = false}) {
  final order = fixture('order_detail.json');
  order['status'] = status;
  order['actions'] = {'next': next, 'canCancel': status != 'delivered' && status != 'cancelled', 'isAdmin': true};
  if (!packed) {
    order['finalAmount'] = null;
    order['amountToCollect'] = order['totalAmount'];
    for (final item in order['items'] as List) {
      (item as Map)['packedQuantity'] = null;
    }
  }
  return order;
}

class FakeRepo extends StaffRepository {
  FakeRepo(this.detail) : super(ApiClient(TokenStore(), onSessionExpired: () async {}), TokenStore());

  Map<String, dynamic> detail;
  final calls = <Map<String, Object?>>[];

  @override
  Future<BoardSummary> summary() async => BoardSummary.fromJson({
    'counts': {'new': 1, 'packing': 0, 'ready': 0, 'out': 0, 'unpaid': 0, 'deliveredToday': 2},
    'latestPlacedAt': '2026-10-03T01:50:37.756Z',
    'version': 1,
    'alerts': {'open': 1, 'worst': 'warning'},
  });

  @override
  Future<ResultPage<OrderCard>> orders({required String tab, String? query, String? cursor}) async {
    final list = fixture('order_list.json')['orders'] as List;
    return ResultPage([for (final o in list) OrderCard.fromJson(Map<String, dynamic>.from(o as Map))], null);
  }

  @override
  Future<OrderDetail> order(String id) async => OrderDetail.fromJson(detail);

  @override
  Future<OrderDetail> advance(String id, {required String from, required String to, String? note, List<Map<String, dynamic>>? packedItems, String? codCollectedAmount}) async {
    calls.add({'call': 'advance', 'from': from, 'to': to, 'note': note, 'packedItems': packedItems, 'cash': codCollectedAmount});
    detail = {...detail, 'status': to, 'actions': {'next': null, 'canCancel': false}};
    return OrderDetail.fromJson(detail);
  }

  @override
  Future<OrderDetail> cancel(String id, {required String from, required String reason}) async {
    calls.add({'call': 'cancel', 'from': from, 'reason': reason});
    detail = {...detail, 'status': 'cancelled', 'cancelledReason': 'Cancelled by store: $reason', 'actions': {'next': null, 'canCancel': false}};
    return OrderDetail.fromJson(detail);
  }

  @override
  Future<Map<String, dynamic>> usage() async => fixture('usage.json');

  @override
  Future<Map<String, dynamic>> dashboard(int days) async => fixture('dashboard.json');

  @override
  Future<Map<String, dynamic>> settings() async => {
    'store.info': {'name': 'Jeya Hyper Store', 'city': 'Tiruchirappalli', 'supportPhone': null, 'supportWhatsApp': null},
    'delivery.rules': {
      'storeLocation': {'lat': 10.8127737, 'lng': 78.6358536},
      'maxDistanceKm': 10,
      'roadDistanceFactor': 1.3,
      'freeDeliveryAbove': '999.00',
      'minOrderAmount': '0.00',
      'deliveryDays': 1,
      'tiers': [
        {'upToKm': 3, 'fee': '20.00'},
        {'upToKm': 10, 'fee': '60.00'},
      ],
    },
    'checkout.payment_methods': {'cod': true, 'online': true},
    'app.maintenance': {'enabled': false, 'message': ''},
    'auth.demo_login_enabled': false,
  };

  @override
  Future<Object?> saveSetting(String key, Object? value) async {
    calls.add({'call': 'saveSetting', 'key': key, 'value': value});
    return value;
  }
}

class SignedInSession extends SessionController {
  @override
  SessionState build() => SignedIn(admin);
}

/// The real board controller minus the polling timer and sound.
class QuietBoard extends BoardController {
  @override
  BoardState build() => const BoardState();
}

Future<GoRouter> pumpApp(WidgetTester tester, FakeRepo repo, {required String at, Size size = const Size(400, 860)}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  late GoRouter router;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      repositoryProvider.overrideWithValue(repo),
      sessionProvider.overrideWith(SignedInSession.new),
      boardProvider.overrideWith(QuietBoard.new),
    ],
    child: Consumer(builder: (context, ref, _) {
      router = ref.watch(routerProvider);
      // Plain theme: the brand font is fetched at runtime, which tests can't do.
      return MaterialApp.router(theme: ThemeData(useMaterial3: true), routerConfig: router);
    }),
  ));
  router.go(at);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('board lists orders on a phone', (tester) async {
    await pumpApp(tester, FakeRepo(orderAt('placed')), at: '/orders');
    expect(find.text('#1016'), findsOneWidget);
    expect(find.text('Cash on delivery'), findsOneWidget);
    expect(find.text('Orders'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('board shows list + detail side by side on the store computer', (tester) async {
    await pumpApp(tester, FakeRepo(orderAt('placed')), at: '/orders', size: const Size(1366, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Select an order'), findsOneWidget);
    await tester.tap(find.text('#1016'));
    await tester.pumpAndSettle();
    expect(find.text('JHS-261003-1016'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('packing a loose item lighter than ordered sends only the short line, and the sheet closes cleanly', (tester) async {
    final repo = FakeRepo(orderAt('packing', next: {'to': 'ready_for_delivery', 'label': 'Mark packed'}));
    await pumpApp(tester, repo, at: '/order/${repo.detail['id']}');
    await tester.tap(find.text('Mark packed'));
    await tester.pumpAndSettle();
    expect(find.text('All items packed'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1.42');
    await tester.pump();
    expect(find.text('1 item short'), findsOneWidget);
    expect(find.text('Total ₹254.30'), findsOneWidget);

    await tester.tap(find.text('Mark packed with changes'));
    await tester.pumpAndSettle(); // runs the sheet's closing animation — this used to crash
    expect(tester.takeException(), isNull);
    expect(repo.calls.single, containsPair('packedItems', [
      {'productId': 40, 'packedQuantity': '1.42'},
    ]));
  });

  testWidgets('delivering a COD order with a different cash amount needs a note', (tester) async {
    final repo = FakeRepo(orderAt('out_for_delivery', next: {'to': 'delivered', 'label': 'Mark delivered'}, packed: true));
    await pumpApp(tester, repo, at: '/order/${repo.detail['id']}');
    await tester.tap(find.text('Mark delivered'));
    await tester.pumpAndSettle();
    expect(find.text('₹254.30'), findsWidgets);

    await tester.tap(find.text('Collected a different amount'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cash collected'), '250');
    await tester.tap(find.text('Delivered — cash recorded'));
    await tester.pump();
    expect(find.text('Add a short note explaining the difference'), findsOneWidget);
    expect(repo.calls, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Why is it different?'), 'No change, rounded off');
    await tester.tap(find.text('Delivered — cash recorded'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(repo.calls.single, allOf(containsPair('to', 'delivered'), containsPair('cash', '250'), containsPair('note', 'No change, rounded off')));
  });

  testWidgets('cancelling asks for a reason', (tester) async {
    final repo = FakeRepo(orderAt('placed', next: {'to': 'packing', 'label': 'Start packing'}));
    await pumpApp(tester, repo, at: '/order/${repo.detail['id']}');
    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Reason'), 'Shop closed early');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel order'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(repo.calls.single, containsPair('reason', 'Shop closed early'));
    expect(find.text('Cancelled by store: Shop closed early'), findsOneWidget);
  });

  testWidgets('usage & bills shows the month bill and every service', (tester) async {
    await pumpApp(tester, FakeRepo(orderAt('placed')), at: '/more/usage');
    expect(find.text('Expected hosting bill'), findsOneWidget);
    expect(find.text('Database backup'), findsOneWidget);
    expect(find.text('Backup failing: AccessDenied: Access Denied'), findsOneWidget);
    expect(find.textContaining('Render (API server)'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('Razorpay (payment fees)'), 300);
    expect(find.textContaining('Cloudflare R2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin switches the customer app to the Diwali theme', (tester) async {
    final repo = FakeRepo(orderAt('placed'));
    await pumpApp(tester, repo, at: '/more/settings');
    final list = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Save theme'), 300, scrollable: list);
    expect(find.text('Customers see the everyday green look.'), findsOneWidget);
    await tester.ensureVisible(find.text('Diwali'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Diwali'));
    await tester.pumpAndSettle();
    expect(find.text('From: now'), findsOneWidget);
    expect(find.text('Live now (until you switch back to Normal).'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Message on the home screen (optional)'), '  Happy Deepavali! ');
    await tester.ensureVisible(find.text('Save theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save theme'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, {
      'call': 'saveSetting',
      'key': 'app.theme',
      'value': {'preset': 'diwali', 'startsAt': null, 'endsAt': null, 'greeting': 'Happy Deepavali!'},
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales dashboard renders', (tester) async {
    await pumpApp(tester, FakeRepo(orderAt('placed')), at: '/sales');
    expect(find.text('Sales'), findsWidgets);
    expect(find.text('Average order'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
