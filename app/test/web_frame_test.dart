import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeya_hyper_store/core/layout.dart';
import 'package:jeya_hyper_store/router.dart';
import 'package:jeya_hyper_store/state/providers.dart';
import 'package:jeya_hyper_store/widgets/web_frame.dart';

/// The web shop layout: a top bar and a centred page on wide screens; phones are untouched.
void main() {
  Future<({double width, bool wide})> pageOn(WidgetTester tester, Size window, String path) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late double seenWidth;
    late bool seenWide;
    Widget page(BuildContext context) {
      seenWidth = MediaQuery.sizeOf(context).width;
      seenWide = isWideLayout(context);
      return const Scaffold(body: Text('page'));
    }

    final router = GoRouter(initialLocation: path, routes: [
      GoRoute(path: '/home', builder: (c, _) => page(c)),
      GoRoute(path: '/checkout', builder: (c, _) => page(c)),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [routerProvider.overrideWithValue(router), cartProvider.overrideWith(() => throw UnimplementedError())],
      child: MaterialApp.router(routerConfig: router, builder: (context, child) => WebFrame(child: child!)),
    ));
    await tester.pump();
    return (width: seenWidth, wide: seenWide);
  }

  testWidgets('laptop: top bar, page capped at 1280 px and told it is wide', (tester) async {
    final seen = await pageOn(tester, const Size(1600, 900), '/home');
    expect(find.byType(WebTopBar), findsOneWidget);
    expect(seen.width, kMaxContentWidth);
    expect(seen.wide, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('laptop checkout: reading width, still the wide layout (no bottom tabs)', (tester) async {
    final seen = await pageOn(tester, const Size(1600, 900), '/checkout');
    expect(seen.width, kReadingWidth);
    expect(seen.wide, isTrue);
  });

  testWidgets('phone: no top bar, full width, app layout', (tester) async {
    final seen = await pageOn(tester, const Size(390, 844), '/home');
    expect(find.byType(WebTopBar), findsNothing);
    expect(seen.width, 390);
    expect(seen.wide, isFalse);
  });
}
