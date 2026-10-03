import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/festival_pack.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/festive_decor.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(authProvider) is AuthOffline;
    final pack = ref.watch(festivalProvider)?.pack;
    if (pack != null) return _FestiveSplash(pack: pack, offline: offline, onRetry: () => ref.read(authProvider.notifier).retry());
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/brand/logo_full.png', width: 220),
              const SizedBox(height: 28),
              if (offline) ...[
                const Icon(Icons.wifi_off_rounded, color: AppColors.inkFaint, size: 32),
                const SizedBox(height: 8),
                Text("Can't reach Jeya Hyper Store", style: text.titleSmall),
                const SizedBox(height: 4),
                Text('Check your internet connection.', style: text.bodySmall),
                const SizedBox(height: 16),
                FilledButton(clipBehavior: Clip.antiAlias, onPressed: () => ref.read(authProvider.notifier).retry(), child: const Text('Try again')),
              ] else
                SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.brand700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Festival splash: the store's logo glowing on a rangoli, the thoranam above, lit diyas below.
class _FestiveSplash extends StatelessWidget {
  const _FestiveSplash({required this.pack, required this.offline, required this.onRetry});
  final FestivalPack pack;
  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gold = AppColors.festiveAccent;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.brand900,
        body: DecoratedBox(
          decoration: BoxDecoration(image: DecorationImage(image: AssetImage(pack.splashBackground), fit: BoxFit.cover)),
          child: Stack(children: [
            const Positioned.fill(child: Twinkles()),
            Positioned(top: MediaQuery.paddingOf(context).top, left: 0, right: 0, height: 44, child: Thoranam(pack: pack)),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: gold, width: 2),
                        boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.45), blurRadius: 36, spreadRadius: 4)],
                      ),
                      child: Image.asset('assets/brand/logo_full.png', width: 180),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      pack.greeting,
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(color: gold, fontWeight: FontWeight.w800, shadows: const [Shadow(color: Color(0x99000000), blurRadius: 8)]),
                    ),
                    const SizedBox(height: 4),
                    Text('from all of us at Jeya Hyper Store', textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 28),
                    if (offline) ...[
                      const Icon(Icons.wifi_off_rounded, color: Colors.white70, size: 30),
                      const SizedBox(height: 8),
                      Text("Can't reach Jeya Hyper Store", style: text.titleSmall?.copyWith(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Check your internet connection.', style: text.bodySmall?.copyWith(color: Colors.white70)),
                      const SizedBox(height: 16),
                      FilledButton(clipBehavior: Clip.antiAlias, onPressed: onRetry, child: const Text('Try again')),
                    ] else ...[
                      DiyaCluster(pack: pack, width: 168),
                      const SizedBox(height: 18),
                      SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: gold)),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
