import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeya_staff/core/api/api_client.dart';
import 'package:jeya_staff/core/api/token_store.dart';
import 'package:jeya_staff/data/models.dart';
import 'package:jeya_staff/data/repository.dart';
import 'package:jeya_staff/features/admin/choices_editor.dart';
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

  static AdminProduct product(int id, String name, {String available = '5'}) => AdminProduct.fromJson(
    {'id': id, 'name': name, 'itemCode': 'C$id', 'mrp': '50.00', 'sellingPrice': '45.00', 'available': available, 'isActive': true},
  );

  @override
  Future<({List<AdminProduct> offers, List<AdminProduct> popular})> homeLists() async =>
      (offers: [product(1, 'Aashirvaad Atta 1kg'), product(2, 'Bru 100g', available: '0')], popular: <AdminProduct>[]);

  @override
  Future<(ResultPage<AdminProduct>, Map<String, int>)> products({String? query, String filter = 'all', String? cursor}) async =>
      (ResultPage([product(1, 'Aashirvaad Atta 1kg'), product(3, 'Gold Winner Oil 1L')], null), {'active': 3, 'withImage': 0});

  @override
  Future<Map<String, dynamic>> finance(String from, String to) async => {
    'period': {'from': from, 'to': to},
    'orders': {'count': 5, 'customers': 2, 'delivered': 4, 'averageOrder': '993.60', 'freeDeliveryOrders': 3, 'memberOrders': 1},
    'income': {'sales': '4968.00', 'items': '4848.00', 'deliveryFees': '120.00', 'cod': '1447.00', 'online': '3521.00', 'memberDiscounts': '50.00', 'gstInSales': '222.29', 'refunded': '0.00', 'refunds': 0},
    'costs': {'goods': '4000.00', 'costCoveragePercent': 100, 'gatewayFees': '95.74', 'expenses': '300.00', 'expensesByCategory': [{'category': 'Fuel & vehicle', 'amount': '300.00'}]},
    'profit': {'grossMargin': '848.00', 'grossMarginPercent': 17.5, 'net': '572.26', 'netPercent': 11.5},
    'byCategory': [{'category': 'Staples', 'sales': '3000.00', 'orders': 3, 'marginPercent': 12.0}],
    'topProducts': <Map<String, dynamic>>[],
    'lowMargin': [{'id': 1, 'name': 'Sugar 1kg', 'qty': '4', 'sales': '180.00', 'margin': '-4.00', 'marginPercent': -2.2}],
    'daily': <Map<String, dynamic>>[],
    'catalog': {'active': 8631, 'withCost': 8500},
  };

  @override
  Future<(List<Map<String, dynamic>>, List<String>)> expenses(String from, String to) async => (
    [{'id': 1, 'spentOn': '2026-10-05', 'category': 'Fuel & vehicle', 'amount': '300.00', 'note': 'Bike petrol'}],
    ['Delivery staff', 'Fuel & vehicle', 'Other'],
  );

  @override
  Future<List<Map<String, dynamic>>> members() async => [
    {'phone': '919876543210', 'name': 'Kumar', 'freeDelivery': true, 'discountPercent': '5.00', 'note': null, 'isActive': true, 'hasAccount': true, 'orders': 3, 'accountName': null},
  ];

  @override
  Future<void> saveMember({required String phone, String? name, required bool freeDelivery, required double discountPercent, String? note, bool isActive = true}) async =>
      calls.add({'call': 'saveMember', 'phone': phone, 'name': name, 'freeDelivery': freeDelivery, 'discountPercent': discountPercent});

  @override
  Future<int> saveChoices(int id, Map<String, dynamic>? options, {bool allSizes = false}) async {
    calls.add({'call': 'saveChoices', 'id': id, 'options': options, 'allSizes': allSizes});
    return allSizes ? 4 : 1;
  }

  @override
  Future<List<Map<String, dynamic>>> shopCategories() async => [
    {'id': 10, 'name': 'Staples', 'parentId': null, 'imageUrl': null, 'products': 751},
    {'id': 11, 'name': 'Rice & Rice Products', 'parentId': 10, 'imageUrl': null, 'products': 60},
  ];

  @override
  Future<Map<String, dynamic>> photoWork() async => {
    'totals': {'active': 8631, 'withPhoto': 120, 'withoutPhoto': 8511, 'unassigned': 8400, 'today': 14},
    'people': [
      {'staffId': '00000000-0000-4000-8000-000000000002', 'name': 'Priya', 'username': 'priya', 'role': 'photos', 'isActive': true, 'open': 25, 'done': 86, 'doneToday': 14, 'lastPhotoAt': '2026-10-07T05:30:00.000Z'},
    ],
  };

  @override
  Future<int> assignPhotos(String staffId, int count, {int? categoryId}) async {
    calls.add({'call': 'assignPhotos', 'staffId': staffId, 'count': count});
    return count;
  }

  @override
  List<AdminProduct> photoList = const [];

  @override
  Future<(ResultPage<AdminProduct>, Map<String, int>)> myPhotos({String? cursor}) async => (
    ResultPage<AdminProduct>(photoList, null),
    {'open': photoList.length, 'done': 86, 'doneToday': 14},
  );

  @override
  Future<Map<String, dynamic>> stockImportStatus() async => {
    'last': null,
    'settings': {'departments': ['SUPER MARKET'], 'typeMap': {}},
    'categories': [
      {'key': 'staples', 'name': 'Staples', 'parent': null},
      {'key': 'dals', 'name': 'Dals & Pulses', 'parent': 'staples'},
    ],
  };

  @override
  Future<Object?> saveSetting(String key, Object? value) async {
    calls.add({'call': 'saveSetting', 'key': key, 'value': value});
    return value;
  }
}

Staff signedInAs = admin;

class SignedInSession extends SessionController {
  @override
  SessionState build() => SignedIn(signedInAs);
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
  setUp(() => signedInAs = admin);

  testWidgets('a photo helper only gets My photos and Account', (tester) async {
    signedInAs = Staff.fromJson({'id': 'p1', 'username': 'priya', 'name': 'Priya', 'role': 'photos', 'mustChangePassword': false, 'isActive': true});
    final router = await pumpApp(tester, FakeRepo(orderAt('placed')), at: '/orders');
    expect(router.state.matchedLocation, '/my-photos');
    expect(find.text('All done!'), findsOneWidget);
    expect(find.text('Orders'), findsNothing);
    router.go('/sales');
    await tester.pumpAndSettle();
    expect(router.state.matchedLocation, '/my-photos');
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo helper: Enter goes straight to the next product', (tester) async {
    signedInAs = Staff.fromJson({'id': 'p1', 'username': 'priya', 'name': 'Priya', 'role': 'photos', 'mustChangePassword': false, 'isActive': true});
    final repo = FakeRepo(orderAt('placed'))..photoList = [FakeRepo.product(1, 'Indulekha Shampoo'), FakeRepo.product(2, 'Red Label 100g'), FakeRepo.product(3, 'Malli 500g')];
    await pumpApp(tester, repo, at: '/my-photos');
    await tester.tap(find.text('Indulekha Shampoo'));
    await tester.pumpAndSettle();
    expect(find.text('Skip to next product →  (Enter)'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // The sheet now shows the second product (its name appears in the sheet as well as the list).
    expect(find.text('Red Label 100g'), findsNWidgets(3));
    await tester.tap(find.text('Skip to next product →  (Enter)'));
    await tester.pumpAndSettle();
    expect(find.text('Malli 500g'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin hands out photo work in priority batches', (tester) async {
    final repo = FakeRepo(orderAt('placed'));
    await pumpApp(tester, repo, at: '/more/photo-work');
    expect(find.text('1.4% of products have photos'), findsOneWidget);
    expect(find.textContaining('25 to do'), findsOneWidget);
    await tester.tap(find.text('Give more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50 products (most important first)'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, {'call': 'assignPhotos', 'staffId': '00000000-0000-4000-8000-000000000002', 'count': 50});
    expect(find.text('50 products given to Priya'), findsOneWidget);
  });

  testWidgets('admin picks Today\'s offers: sold-out ones are flagged, added products are saved in order', (tester) async {
    final repo = FakeRepo(orderAt('placed'));
    await pumpApp(tester, repo, at: '/more/home-lists');
    expect(find.text('Aashirvaad Atta 1kg'), findsOneWidget);
    expect(find.text('Not shown now — out of stock'), findsOneWidget);
    await tester.tap(find.text('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'gold');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Already in the list'), findsOneWidget);
    await tester.tap(find.text('Gold Winner Oil 1L'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, {'call': 'saveSetting', 'key': 'home.lists', 'value': {'offers': [1, 2, 3], 'popular': <int>[]}});
    await tester.tap(find.text('Popular (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Automatic'), findsOneWidget);
  });

  testWidgets('admin lists the designs of one POS item; every size gets them', (tester) async {
    final repo = FakeRepo(orderAt('placed'));
    final product = AdminProduct.fromJson({'id': 9, 'name': 'Pen', 'itemCode': 'P9', 'mrp': '10.00', 'sellingPrice': '10.00', 'available': '40', 'variantGroup': '1:pen', 'variantLabel': '₹10'});
    tester.view.physicalSize = const Size(800, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: ChoicesEditorScreen(product: product)),
    ));
    await tester.tap(find.text('Design'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), 'Blue gel');
    await tester.enterText(find.byType(TextField).at(1), 'Black ball');
    await tester.tap(find.text('Save choices'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, {
      'call': 'saveChoices',
      'id': 9,
      'options': {'label': 'Design', 'values': ['Blue gel', 'Black ball'], 'images': <String, String>{}},
      'allSizes': true,
    });
  });

  testWidgets('finance shows profit, margin and loss-making products', (tester) async {
    await pumpApp(tester, FakeRepo(orderAt('placed')), at: '/more/finance');
    expect(find.text('Net profit'), findsOneWidget);
    expect(find.text('₹572.26'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Sugar 1kg'), 300);
    expect(find.text('-2.2%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin adds a premium customer with free delivery and 10% off', (tester) async {
    final repo = FakeRepo(orderAt('placed'));
    await pumpApp(tester, repo, at: '/more/members');
    expect(find.textContaining('Free delivery · 5% off · 3 orders'), findsOneWidget);
    await tester.tap(find.text('Add customer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '9123456789');
    await tester.enterText(find.widgetWithText(TextField, 'Name (optional)'), 'Meena');
    await tester.enterText(find.widgetWithText(TextField, 'Discount on items (%)'), '10');
    await tester.tap(find.text('Add premium customer'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, {'call': 'saveMember', 'phone': '9123456789', 'name': 'Meena', 'freeDelivery': true, 'discountPercent': 10.0});
  });

  testWidgets('category photos lists each category with its product count', (tester) async {
    await pumpApp(tester, FakeRepo(orderAt('placed')), at: '/more/categories');
    expect(find.text('Rice & Rice Products'), findsOneWidget);
    expect(find.text('60 products'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stock upload screen explains the daily export', (tester) async {
    await pumpApp(tester, FakeRepo(orderAt('placed')), at: '/more/stock');
    expect(find.textContaining('No stock file uploaded yet'), findsOneWidget);
    expect(find.text('Choose stock file (.csv)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    await tester.enterText(find.widgetWithText(TextField, 'Line under the greeting (optional)'), '  Happy Deepavali! ');
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
