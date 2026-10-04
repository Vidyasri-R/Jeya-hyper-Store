import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/widgets/brand_intro.dart';
import 'package:jeya_hyper_store/widgets/brand_intro_parts.dart';

Future<void> _pumpIntro(WidgetTester tester, {required VoidCallback onDone, bool reduceMotion = false}) async {
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(390, 844), disableAnimations: reduceMotion),
      child: Center(child: BrandIntro(width: 236, onDone: onDone)),
    ),
  ));
}

void main() {
  testWidgets('the logo blooms in, then lets the app go on', (tester) async {
    var done = 0;
    await _pumpIntro(tester, onDone: () => done++);
    await tester.runAsync(() async {
      // the intro waits for its pieces to be decoded before it starts
      final ctx = tester.element(find.byType(BrandIntro));
      for (final piece in BrandIntroParts.all) {
        await precacheImage(AssetImage(piece.asset), ctx);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    Future<void> play(int ms) async {
      for (var t = 0; t < ms; t += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await play(900);
    expect(done, 0, reason: 'feathers still opening');
    await play(BrandIntro.duration.inMilliseconds);
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduce motion on, the logo is simply there', (tester) async {
    var done = 0;
    await _pumpIntro(tester, onDone: () => done++, reduceMotion: true);
    await tester.pump();
    expect(done, 1);
    expect(find.byType(Image), findsNWidgets(BrandIntroParts.all.length));
  });

  test('the pieces make up the whole logo', () {
    expect(BrandIntroParts.feathers, hasLength(9));
    for (final piece in BrandIntroParts.all) {
      expect(Offset.zero & BrandIntroParts.size, isA<Rect>().having((r) => r.intersect(piece.rect), 'covers', piece.rect), reason: piece.asset);
    }
  });
}
