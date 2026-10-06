import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeya_hyper_store/core/navigation.dart';
import 'package:jeya_hyper_store/features/shell/app_shell.dart';
import 'package:jeya_hyper_store/state/providers.dart';

/// System back: pushed screens return to where the customer came from, tabs go to Home,
/// and only a double press on Home closes the app.
void main() {
  late GoRouter router;
  late int exits;

  Widget page(String name) => Scaffold(
        body: Builder(
          builder: (context) => Column(children: [
            Text(name),
            TextButton(onPressed: () => openRoute(context, '/search?q=rice'), child: const Text('open search')),
            TextButton(onPressed: () => openCart(context), child: const Text('open cart')),
          ]),
        ),
      );

  Future<void> pump(WidgetTester tester, String start) async {
    exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    router = GoRouter(initialLocation: start, routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          for (final tab in ['home', 'categories', 'cart', 'orders', 'profile'])
            StatefulShellBranch(routes: [GoRoute(path: '/$tab', builder: (_, _) => page('tab $tab'))]),
        ],
      ),
      GoRoute(path: '/search', builder: (_, _) => page('search')),
      GoRoute(path: '/bag', builder: (_, _) => page('bag')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [cartCountProvider.overrideWithValue(0)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('back from another tab goes to Home', (tester) async {
    await pump(tester, '/categories');
    expect(find.text('tab categories'), findsOneWidget);
    await back(tester);
    expect(find.text('tab home'), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('a pushed screen goes back to the screen it was opened from', (tester) async {
    await pump(tester, '/categories');
    await tester.tap(find.text('open search'));
    await tester.pumpAndSettle();
    expect(find.text('search'), findsOneWidget);
    await back(tester);
    expect(find.text('tab categories'), findsOneWidget);

    await tester.tap(find.text('open cart'));
    await tester.pumpAndSettle();
    expect(find.text('bag'), findsOneWidget);
    await back(tester);
    expect(find.text('tab categories'), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('Home needs a second back press to close the app', (tester) async {
    await pump(tester, '/home');
    await back(tester);
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(exits, 0);
    await back(tester);
    expect(exits, 1);
  });

  testWidgets('a slow second press only warns again', (tester) async {
    await pump(tester, '/home');
    await back(tester);
    await tester.pump(const Duration(seconds: 3));
    await back(tester);
    expect(exits, 0);
    expect(find.text('Press back again to exit'), findsOneWidget);
  });
}
