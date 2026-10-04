import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeya_hyper_store/core/festival.dart';
import 'package:jeya_hyper_store/core/festival_pack.dart';
import 'package:jeya_hyper_store/core/theme.dart';
import 'package:jeya_hyper_store/data/models.dart';
import 'package:jeya_hyper_store/features/home/home_header.dart';
import 'package:jeya_hyper_store/features/shell/splash_screen.dart';
import 'package:jeya_hyper_store/state/providers.dart';
import 'package:jeya_hyper_store/widgets/festive_decor.dart';

class _Starting extends AuthController {
  _Starting(this.state0);
  final AuthState state0;
  @override
  AuthState build() => state0;
}

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
  for (final pack in [FestivalPacks.diwali, FestivalPacks.pongal, FestivalPacks.christmas, FestivalPacks.valentine, FestivalPacks.puthandu, FestivalPacks.eid, FestivalPacks.national, FestivalPacks.vinayagar]) {
    group(pack.id, () => _festiveLayout(pack));
  }
}

void _festiveLayout(FestivalPack pack) {
  setUp(() {
    AppColors.palette = Palettes.byId(pack.id);
    Festive.pack = pack;
  });
  tearDown(() {
    AppColors.palette = Palettes.standard;
    Festive.pack = null;
  });

  testWidgets('header: greeting, thoranam and centrepiece fit a small phone', (tester) async {
    await pumpAt(
      tester,
      const SingleChildScrollView(child: HomeHeader()),
      overrides: [
        festivalProvider.overrideWithValue(FestivalTheme(preset: pack.id)),
        authProvider.overrideWith(() => _SignedInAs('Jayaprakash Ramalingam')),
        selectedAddressProvider.overrideWithValue(null),
      ],
    );
    expect(find.textContaining('${pack.greetingOn(DateTime.now())}, Jayaprakash!'), findsOneWidget);
    expect(find.text(pack.question), findsOneWidget);
    expect(find.byType(Thoranam), findsOneWidget);
    expect(find.byType(FestiveHero), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('festival banners keep their text inside the card', (tester) async {
    for (final width in [300.0, 351.0]) {
      await pumpAt(
        tester,
        Column(children: [
          for (final b in pack.banners) SizedBox(width: width, height: 176, child: FestiveBannerCard(b)),
        ]),
        size: Size(width + 20, 700),
      );
      expect(find.text(pack.banners.first.title), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'at $width dp');
    }
  });

  testWidgets("the store's festival message replaces the line under the greeting", (tester) async {
    await pumpAt(
      tester,
      const SingleChildScrollView(child: HomeHeader()),
      overrides: [
        festivalProvider.overrideWithValue(FestivalTheme(preset: pack.id, greeting: 'Festive offers on sweets, dry fruits and pooja needs — order by 6 PM! ' * 2)),
        authProvider.overrideWith(() => _SignedInAs('Jai')),
        selectedAddressProvider.overrideWithValue(null),
      ],
    );
    expect(find.text(pack.question), findsNothing);
    expect(find.textContaining('Festive offers on sweets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final offline in [false, true]) {
    testWidgets('festive splash fits a small phone${offline ? ' (offline)' : ''}', (tester) async {
      await pumpAt(
        tester,
        const SplashScreen(),
        size: const Size(320, 568),
        overrides: [
          festivalProvider.overrideWithValue(FestivalTheme(preset: pack.id)),
          authProvider.overrideWith(() => _Starting(offline ? const AuthOffline() : const AuthUnknown())),
        ],
      );
      expect(find.text(pack.greetingOn(DateTime.now())), findsOneWidget);
      expect(find.byType(FestiveHero), offline ? findsNothing : findsOneWidget);
      expect(find.text('Try again'), offline ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('petal shower plays once and gets out of the way', (tester) async {
    await pumpAt(tester, SizedBox.expand(child: PetalShower(pack: pack)), size: const Size(390, 800), textScale: 1);
    expect(find.byType(Image), findsWidgets);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.descendant(of: find.byType(PetalShower), matching: find.byType(Image)), findsNothing);
  });
}
