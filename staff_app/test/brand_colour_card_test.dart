import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_staff/features/admin/brand_colour_card.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('shades keep white text readable for every preset and a light pick', () {
    for (final argb in [...brandPresets.map((p) => p.$2), 0xFFFFD600, 0xFFFFFFFF]) {
      final s = brandShades(Color(argb));
      expect(contrast(s.button, Colors.white), greaterThanOrEqualTo(4.5), reason: hexOf(Color(argb)));
      expect(contrast(s.headerStart, Colors.white), greaterThanOrEqualTo(4.5), reason: hexOf(Color(argb)));
    }
    expect(hexOf(brandShades(const Color(0xFF1E4FA8)).button), '#1E4FA8');
  });

  testWidgets('pick Logo blue → saves #1E4FA8; Save is off until something changes', (tester) async {
    Map<String, dynamic>? sent;
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BrandColourCard(value: const {'color': '#1B7A3E'}, onSave: (v) async {
            sent = v;
            return true;
          }),
        ),
      ),
    ));
    final save = find.widgetWithText(FilledButton, 'Save brand colour');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('Logo blue'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '#1E4FA8'); // the code field follows the swatch
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(sent, {'color': '#1E4FA8'});
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '#FFD600');
    await tester.pump();
    expect(find.textContaining('buttons use a deeper shade'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
