import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/core/festival.dart';
import 'package:jeya_hyper_store/core/festival_pack.dart';
import 'package:jeya_hyper_store/core/theme.dart';
import 'package:jeya_hyper_store/data/models.dart';
import 'package:jeya_hyper_store/features/home/home_header.dart';
import 'package:jeya_hyper_store/state/providers.dart';
import 'package:jeya_hyper_store/widgets/festive_decor.dart';

class _SignedInAs extends AuthController {
  _SignedInAs(this.name);
  final String name;
  @override
  AuthState build() => SignedIn(AppUser(id: 'u1', phone: '919999999999', name: name, profileComplete: true));
}

/// Small phone, large accessibility text: the festive layout must not overflow anywhere.
Future<void> pumpAt(WidgetTester tester, Widget child, {Size size = const Size(320, 640), double textScale = 1.25, List<Override> overrides = const []}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      // Plain theme: the brand font is fetched at runtime, which tests can't do.
      theme: ThemeData(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale), padding: const EdgeInsets.only(top: 32)),
        child: Scaffold(body: child),
      ),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() {
    AppColors.palette = Palettes.diwali;
    Festive.pack = FestivalPacks.diwali;
  });
  tearDown(() {
    AppColors.palette = Palettes.standard;
    Festive.pack = null;
  });

  testWidgets('Deepavali header: greeting, thoranam and diyas fit a small phone', (tester) async {
    await pumpAt(
      tester,
      const SingleChildScrollView(child: HomeHeader()),
      overrides: [
        festivalProvider.overrideWithValue(const FestivalTheme(preset: 'diwali')),
        authProvider.overrideWith(() => _SignedInAs('Jayaprakash Ramalingam')),
        selectedAddressProvider.overrideWithValue(null),
      ],
    );
    expect(find.textContaining('Happy Deepavali, Jayaprakash!'), findsOneWidget);
    expect(find.text('Festive essentials, delivered'), findsOneWidget);
    expect(find.byType(Thoranam), findsOneWidget);
    expect(find.byType(DiyaCluster), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('festival banners keep their text inside the card', (tester) async {
    for (final width in [300.0, 351.0]) {
      await pumpAt(
        tester,
        Column(children: [
          for (final b in FestivalPacks.diwali.banners) SizedBox(width: width, height: 176, child: FestiveBannerCard(b)),
        ]),
        size: Size(width + 20, 700),
      );
      expect(find.text('Sweets &\nsavouries'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'at $width dp');
    }
  });

  testWidgets('greeting ribbon takes the longest admin message', (tester) async {
    await pumpAt(tester, FestiveRibbon(pack: FestivalPacks.diwali, text: 'Happy Deepavali! ' * 7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('petal shower plays once and gets out of the way', (tester) async {
    await pumpAt(tester, const SizedBox.expand(child: PetalShower(pack: FestivalPacks.diwali)), size: const Size(390, 800), textScale: 1);
    expect(find.byType(Image), findsWidgets);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.descendant(of: find.byType(PetalShower), matching: find.byType(Image)), findsNothing);
  });
}
