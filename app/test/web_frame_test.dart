import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeya_hyper_store/core/layout.dart';
import 'package:jeya_hyper_store/router.dart';
import 'package:jeya_hyper_store/widgets/web_frame.dart';

/// The web shop layout is for jeyahyperstore.in only: the Android/iOS apps keep the app layout
/// on every screen size (tests run as a native app).
void main() {
  for (final size in const [Size(390, 844), Size(834, 1194), Size(1440, 900)]) {
    testWidgets('native app at ${size.width.toInt()} px: no web header, app layout', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late bool wide;
      late double width;
      final router = GoRouter(initialLocation: '/home', routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) {
            wide = isWideLayout(context);
            width = MediaQuery.sizeOf(context).width;
            return const Scaffold(body: Text('page'));
          },
        ),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [routerProvider.overrideWithValue(router)],
        child: MaterialApp.router(routerConfig: router, builder: (context, child) => WebFrame(child: child!)),
      ));
      await tester.pump();
      expect(find.byType(WebHeader), findsNothing);
      expect(wide, isFalse);
      expect(width, size.width);
    });
  }
}
