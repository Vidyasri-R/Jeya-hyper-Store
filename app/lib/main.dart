import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/festival_cache.dart';
import 'core/festival_pack.dart';
import 'core/theme.dart';
import 'state/providers.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Read while Android's launch splash is still up, so the first frame already has the festival look.
  final savedTheme = await FestivalCache.read();
  runApp(ProviderScope(overrides: [savedThemeProvider.overrideWithValue(savedTheme)], child: const JeyaApp()));
}

class JeyaApp extends ConsumerStatefulWidget {
  const JeyaApp({super.key});

  @override
  ConsumerState<JeyaApp> createState() => _JeyaAppState();
}

class _JeyaAppState extends ConsumerState<JeyaApp> with WidgetsBindingObserver {
  DateTime _configFetchedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Remember the store's festival setting for the next launch, and pick Android's launch splash.
    ref.listenManual(publicConfigProvider, (_, next) {
      if (next.hasValue) FestivalCache.write(next.value!['app.theme']);
    });
    ref.listenManual<bool>(festivalProvider.select((f) => f?.pack != null), (_, festive) => FestivalCache.launchSplash(festive: festive), fireImmediately: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the app after a while: pick up settings the store changed (festival theme, pause…).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && DateTime.now().difference(_configFetchedAt) > const Duration(minutes: 10)) {
      _configFetchedAt = DateTime.now();
      ref.invalidate(publicConfigProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final festival = ref.watch(festivalProvider);
    final palette = festival?.palette ?? Palettes.standard;
    final pack = festival?.pack;
    if (!identical(AppColors.palette, palette) || !identical(Festive.pack, pack)) {
      AppColors.palette = palette;
      Festive.pack = pack;
      // Brand colours are read straight from AppColors, so repaint every widget once —
      // without losing the screen, scroll position or anything typed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        void rebuild(Element element) {
          element.markNeedsBuild();
          element.visitChildren(rebuild);
        }

        (context as Element).visitChildren(rebuild);
      });
    }
    return MaterialApp.router(
      title: 'Jeya Hyper Store',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery(
        // Respect accessibility text size, but cap it so grids don't break.
        data: MediaQuery.of(context).copyWith(textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.25)),
        child: child!,
      ),
    );
  }
}
