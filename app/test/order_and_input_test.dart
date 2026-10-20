import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/core/phone_input.dart';
import 'package:jeya_hyper_store/data/models.dart';
import 'package:jeya_hyper_store/router.dart' show appPath;

Map<String, dynamic> _order({String? finalAmount, List<Map<String, dynamic>> items = const []}) => {
      'id': 'o1',
      'orderNumber': 'JHS-261020-1047',
      'status': 'ready_for_delivery',
      'paymentStatus': 'pending',
      'paymentMethod': 'cod',
      'subtotal': '782.00',
      'deliveryFee': '0',
      'totalAmount': '782.00',
      'finalAmount': finalAmount,
      'deliveryAddress': <String, dynamic>{},
      'canCancel': false,
      'createdAt': '2026-10-20T13:32:20.928Z',
      'items': items,
    };

void main() {
  group('mobile number field', () {
    test('keeps the 10 digits however the number arrives', () {
      expect(IndianMobileFormatter.clean('09876543210'), '9876543210');
      expect(IndianMobileFormatter.clean('+91 98765 43210'), '9876543210');
      expect(IndianMobileFormatter.clean('919876543210'), '9876543210');
      expect(IndianMobileFormatter.clean('98765-43210'), '9876543210');
      expect(IndianMobileFormatter.clean('9198765432'), '9198765432'); // a real number starting 91
      expect(IndianMobileFormatter.clean('98765'), '98765');
    });

    testWidgets('pasting "09876543210" gives the whole number, not "0987654321"', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: TextField(controller: controller, inputFormatters: const [IndianMobileFormatter()])),
      ));
      await tester.enterText(find.byType(TextField), '09876543210');
      expect(controller.text, '9876543210');
      await tester.enterText(find.byType(TextField), '+91 98765 43210');
      expect(controller.text, '9876543210');
    });

    test('typing a 0 first, then the number, still ends with the number', () {
      const f = IndianMobileFormatter();
      var value = TextEditingValue.empty;
      for (final ch in '09876543210'.split('')) {
        value = f.formatEditUpdate(value, TextEditingValue(text: value.text + ch));
      }
      expect(value.text, '9876543210');
    });
  });

  group('order after packing', () {
    test('an item packed short shows what is charged, and the final amount', () {
      final order = Order.fromJson(_order(finalAmount: '757.00', items: [
        {'productId': 1, 'name': 'Sakthi Turmeric Powder 500.GM', 'unit': 'pcs', 'quantity': '1', 'packedQuantity': '0', 'unitPrice': '25.00', 'totalPrice': '25.00', 'mrp': '25.00'},
        {'productId': 2, 'name': 'Aashirvaad Atta 2kg', 'unit': 'pcs', 'quantity': '3', 'packedQuantity': '2', 'unitPrice': '110.00', 'totalPrice': '330.00', 'mrp': '110.00'},
        {'productId': 3, 'name': 'Sugar', 'unit': 'kg', 'quantity': '1.5', 'packedQuantity': null, 'unitPrice': '44.00', 'totalPrice': '66.00', 'mrp': '44.00'},
      ]));
      expect(order.items[0].isShort, isTrue);
      expect(order.items[0].chargedPaise, 0);
      expect(order.items[1].chargedPaise, 22000);
      expect(order.items[2].isShort, isFalse);
      expect(order.items[2].chargedPaise, 6600);
      expect(order.totalChanged, isTrue);
      expect(order.payableAmount, '757.00');
    });

    test('before packing the order total is what is payable', () {
      final order = Order.fromJson(_order());
      expect(order.totalChanged, isFalse);
      expect(order.payableAmount, '782.00');
    });
  });

  test('search results carry the category filter chips', () {
    final page = ProductPage.fromJson({
      'items': <dynamic>[],
      'nextCursor': null,
      'categories': [
        {'slug': 'staples-web-staples', 'name': 'Staples', 'count': 12},
        {'slug': 'personal-care-web-personal', 'name': 'Personal Care', 'count': 5},
      ],
    });
    expect(page.categories!.map((c) => '${c.name} (${c.count})'), ['Staples (12)', 'Personal Care (5)']);
    expect(ProductPage.fromJson({'items': <dynamic>[]}).categories, isNull);
  });

  test('app links: a WhatsApp "Track order" address opens that order in the app', () {
    expect(appPath('https://jeyahyperstore.in/order/478dcba6-795a-4032-9454-dfc9ad428398'), '/order/478dcba6-795a-4032-9454-dfc9ad428398');
    expect(appPath('https://www.jeyahyperstore.in/product/atta-1?ref=wa'), '/product/atta-1?ref=wa');
    expect(appPath('/order/1'), '/order/1');
    expect(appPath('https://evil.example/order/1'), isNull);
    expect(appPath('order/1'), isNull);
    expect(appPath(null), isNull);
  });
}
