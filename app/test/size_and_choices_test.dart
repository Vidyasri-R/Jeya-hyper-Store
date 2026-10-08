import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/data/models.dart';
import 'package:jeya_hyper_store/state/providers.dart';
import 'package:jeya_hyper_store/widgets/choices_sheet.dart';
import 'package:jeya_hyper_store/widgets/product_card.dart';

class _EmptyCart extends CartController {
  final added = <String>[];

  @override
  Future<Cart> build() async => Cart.empty;

  @override
  Future<void> setQty(Product product, int milli, {Choices? choices}) async => added.add('${product.name} × $milli');
}

Map<String, dynamic> _size(int id, String label, String price) => {
      'id': id,
      'slug': 'bru-$id',
      'name': 'Bru $label',
      'mrp': price,
      'sellingPrice': price,
      'unit': 'pcs',
      'packSize': label,
      'minOrderQty': '1',
      'qtyStep': '1',
      'maxPurchasableQty': '10',
      'variantLabel': label,
    };

late _EmptyCart _cart;

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      cartProvider.overrideWith(() => _cart = _EmptyCart()),
      isSignedInProvider.overrideWith((ref) => true),
    ],
    child: MaterialApp(home: Scaffold(body: Center(child: child))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one card for all sizes: the size picker switches price', (tester) async {
    final sizes = [_size(1, '100 g', '98.00'), _size(2, '200 g', '189.00')];
    final product = Product.fromJson({...sizes[0], 'variants': sizes});
    await _pump(tester, SizedBox(width: 160, height: 300, child: ProductCard(product: product)));
    expect(find.text('₹98'), findsOneWidget);
    await tester.tap(find.text('100 g'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a size'), findsOneWidget);
    await tester.tap(find.text('200 g').last);
    await tester.pumpAndSettle();
    expect(find.text('₹189'), findsOneWidget);
    expect(find.text('Bru 200 g'), findsOneWidget);
  });

  testWidgets('Add on a product with several sizes asks which one first', (tester) async {
    final sizes = [_size(1, '100 g', '98.00'), _size(2, '200 g', '189.00')];
    final product = Product.fromJson({...sizes[0], 'variants': sizes});
    await _pump(tester, SizedBox(width: 160, height: 300, child: ProductCard(product: product)));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Which one do you want?'), findsOneWidget);
    await tester.tap(find.text('200 g').last);
    await tester.pumpAndSettle();
    expect(_cart.added, ['Bru 200 g × 1000']);
    expect(find.text('₹189'), findsOneWidget);
  });

  testWidgets('flavour picker splits the quantity across flavours', (tester) async {
    final product = Product.fromJson({
      ..._size(7, '1 pcs', '10.00'),
      'name': 'Arun',
      'options': {'label': 'Flavour', 'values': ['Vanilla', 'Chocolate', 'Strawberry']},
    });
    Choices? picked;
    await _pump(
      tester,
      Builder(builder: (context) => TextButton(onPressed: () async => picked = await showChoicesSheet(context, product), child: const Text('open'))),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose the flavour · ₹10 each'), findsOneWidget);
    final plus = find.byIcon(Icons.add);
    await tester.tap(plus.at(0));
    await tester.tap(plus.at(0));
    await tester.tap(plus.at(1));
    await tester.pump();
    await tester.tap(find.text('Add 3 · ₹30'));
    await tester.pumpAndSettle();
    expect(picked, {'Vanilla': 2000, 'Chocolate': 1000});
  });
}
