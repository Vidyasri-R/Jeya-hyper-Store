import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_update.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

/// Branch indexes of the StatefulShellRoute in router.dart.
abstract final class Branch {
  static const orders = 0;
  static const sales = 1;
  static const products = 2;
  static const more = 3;
  static const myPhotos = 4;
}

class _Destination {
  const _Destination(this.branch, this.label, this.icon, this.selectedIcon);
  final int branch;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _staffDestinations = [
  _Destination(Branch.orders, 'Orders', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  _Destination(Branch.myPhotos, 'My photos', Icons.add_a_photo_outlined, Icons.add_a_photo_rounded),
  _Destination(Branch.more, 'Account', Icons.person_outline_rounded, Icons.person_rounded),
];

const _photoHelperDestinations = [
  _Destination(Branch.myPhotos, 'My photos', Icons.add_a_photo_outlined, Icons.add_a_photo_rounded),
  _Destination(Branch.more, 'Account', Icons.person_outline_rounded, Icons.person_rounded),
];

const _adminDestinations = [
  _Destination(Branch.orders, 'Orders', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  _Destination(Branch.sales, 'Sales', Icons.insights_outlined, Icons.insights_rounded),
  _Destination(Branch.products, 'Photos', Icons.photo_library_outlined, Icons.photo_library_rounded),
  _Destination(Branch.more, 'More', Icons.grid_view_outlined, Icons.grid_view_rounded),
];

/// Staff see Orders, My photos and Account; photo helpers only My photos and Account; admins also
/// get Sales, product Photos and the admin tools.
/// Phones get a bottom bar; the store computer gets a side rail.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(currentStaffProvider);
    final isAdmin = staff?.isAdmin ?? false;
    final destinations = isAdmin ? _adminDestinations : (staff?.isPhotoHelper ?? false ? _photoHelperDestinations : _staffDestinations);
    final selected = destinations.indexWhere((d) => d.branch == shell.currentIndex).clamp(0, destinations.length - 1);
    final newCount = ref.watch(boardProvider.select((s) => s.summary?.counts['new'] ?? 0));
    final alerts = ref.watch(boardProvider.select((s) => s.summary?.alertsOpen ?? 0));

    Widget iconFor(_Destination d, {required bool selectedIcon}) {
      final icon = Icon(selectedIcon ? d.selectedIcon : d.icon);
      final badge = d.branch == Branch.orders ? newCount : (d.branch == Branch.more && isAdmin ? alerts : 0);
      return badge > 0 ? Badge(label: Text('$badge'), backgroundColor: d.branch == Branch.orders ? AppColors.offerRed : AppColors.amber, child: icon) : icon;
    }

    void go(int index) => shell.goBranch(destinations[index].branch, initialLocation: destinations[index].branch == shell.currentIndex);

    if (MediaQuery.sizeOf(context).width >= AppConfig.wideLayout) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.surface,
              indicatorColor: AppColors.green100,
              leading: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Image.asset('assets/brand/logo_mark.png', height: 40)),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: iconFor(d, selectedIcon: false), selectedIcon: iconFor(d, selectedIcon: true), label: Text(d.label)),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }

    return Scaffold(
      body: Column(children: [const _UpdateBar(), Expanded(child: shell)]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: go,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.green100,
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: iconFor(d, selectedIcon: false), selectedIcon: iconFor(d, selectedIcon: true), label: d.label),
        ],
      ),
    );
  }
}

/// "New version available" on Android phones that installed the APK from the download page.
class _UpdateBar extends ConsumerWidget {
  const _UpdateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider).valueOrNull;
    if (update == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.green700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(children: [
            const Icon(Icons.system_update_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('New version ${update.versionName} is ready', style: text.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => launchUrl(Uri.parse(update.url), mode: LaunchMode.externalApplication),
              child: const Text('Update'),
            ),
          ]),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.mint,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/brand/logo_mark.png', height: 80),
          const SizedBox(height: 20),
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.6)),
        ],
      ),
    ),
  );
}

/// Launch couldn't reach the server (network blip / server restart). The session is kept.
class UnreachableScreen extends ConsumerWidget {
  const UnreachableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/brand/logo_mark.png', height: 72),
              const SizedBox(height: 20),
              Text("Can't reach Jeya Hyper Store", style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('You are still signed in. Check the internet and try again.', style: text.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => ref.read(sessionProvider.notifier).retry(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: const Text('Sign out')),
            ],
          ),
        ),
      ),
    );
  }
}
