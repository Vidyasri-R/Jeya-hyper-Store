import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(authProvider) is AuthOffline;
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
                FilledButton(onPressed: () => ref.read(authProvider.notifier).retry(), child: const Text('Try again')),
              ] else
                SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.brand700)),
            ],
          ),
        ),
      ),
    );
  }
}
