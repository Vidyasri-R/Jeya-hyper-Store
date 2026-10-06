import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_staff/features/admin/banners_screen.dart';

void main() {
  test('what the server receives drops the picker label and stray link fields', () {
    final b = {...blankBanner(), 'title': 'Hi', 'link': {'type': 'category', 'value': 'staples', 'label': 'Staples'}};
    expect(forServer(b)['link'], {'type': 'category', 'value': 'staples'});
    expect(forServer({...b, 'link': {'type': 'none', 'value': 'x'}})['link'], {'type': 'none'});
  });

  test('status lines for the list', () {
    final now = DateTime(2026, 10, 20, 12);
    expect(bannerWhen({'active': false}, now), 'Off');
    expect(bannerWhen({'active': true, 'endsAt': DateTime(2026, 10, 19).toUtc().toIso8601String()}, now), 'Ended 19 Oct');
    expect(bannerWhen({'active': true, 'startsAt': DateTime(2026, 10, 25).toUtc().toIso8601String()}, now), 'Starts 25 Oct');
    expect(bannerWhen({'active': true}, now), 'Live');
    expect(bannerLink({'link': {'type': 'search', 'value': 'sweets'}}), 'Opens search: “sweets”');
    expect(bannerLink({'link': {'type': 'product', 'value': 'x', 'label': 'Ponni Rice 5 kg'}}), 'Opens product: Ponni Rice 5 kg');
  });

  testWidgets('new text banner: Done waits for a title and a search word, then returns the banner', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    Map<String, dynamic>? result;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => result = await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(builder: (_) => BannerEditorScreen(banner: blankBanner(), brand: const Color(0xFF1E4FA8), isNew: true)),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    FilledButton done() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Done'));
    expect(done().onPressed, isNull);
    expect(find.text('Add a picture or a title'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Sweets & snacks');
    await tester.pump();
    expect(done().onPressed, isNotNull);

    await tester.tap(find.text('Search'));
    await tester.pump();
    expect(done().onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Search for'), 'sweets');
    await tester.pump();
    await tester.tap(find.text('Cream'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(result?['title'], 'Sweets & snacks');
    expect(result?['link'], {'type': 'search', 'value': 'sweets'});
    expect(result?['background'], '#FFF4DC');
    expect(result?['active'], true);
  });

  testWidgets('preview handles long text and a deep colour', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 400));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BannerPreview(
          brand: const Color(0xFF1B7A3E),
          banner: {
            ...blankBanner(),
            'tag': 'Weekend',
            'title': 'A very long title that will need to wrap over more than two lines here',
            'subtitle': 'And a subtitle that is also far too long to fit on one line',
            'background': '#8E1B2E',
            'link': {'type': 'search', 'value': 'x'},
          },
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.textContaining('A very long title')).style?.color, Colors.white);
  });
}
