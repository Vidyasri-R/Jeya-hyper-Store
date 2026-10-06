import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config_cache.dart';
import 'core/festival_pack.dart';
import 'core/theme.dart';
import 'state/providers.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Read while Android's launch splash is still up, so the first frame already has the store's settings.
  final savedConfig = await ConfigCache.read();
  runApp(ProviderScope(overrides: [savedConfigProvider.overrideWithValue(savedConfig)], child: const JeyaApp()));
}

class JeyaApp extends ConsumerStatefulWidget {
  const JeyaApp({super.key});

  @override
  ConsumerState<JeyaApp> createState() => _JeyaAppState();
}

class _JeyaAppState extends ConsumerState<JeyaApp> with WidgetsBindingObserver {
  DateTime _configFetchedAt = DateTime.now();
  Timer? _configTimer;

  void _refreshConfig() {
    _configFetchedAt = DateTime.now();
    ref.invalidate(publicConfigProvider);
  }

  /// Store settings (delivery charges, minimum order, pause, festival theme…) reach an open app
  /// within five minutes; coming back to the app picks them up straight away.
  void _startConfigTimer() {
    _configTimer?.cancel();
    _configTimer = Timer.periodic(const Duration(minutes: 5), (_) => _refreshConfig());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startConfigTimer();
    // Remember the store's settings for the next launch, and pick Android's launch splash.
    ref.listenManual(publicConfigProvider, (_, next) {
      if (next.hasValue) ConfigCache.write(next.value!);
    });
    ref.listenManual<String?>(festivalProvider.select((f) => f?.pack?.id), (_, preset) => ConfigCache.launchSplash(preset), fireImmediately: true);
  }

  @override
  void dispose() {
    _configTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back in the app: pick up settings the store changed (delivery charges, pause, festival theme…).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_configFetchedAt) > const Duration(minutes: 1)) _refreshConfig();
      _startConfigTimer();
    } else if (state == AppLifecycleState.paused) {
      _configTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final festival = ref.watch(festivalProvider);
    final BrandPalette brand = ref.watch(brandPaletteProvider);
    final palette = festival?.palette ?? brand;
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
