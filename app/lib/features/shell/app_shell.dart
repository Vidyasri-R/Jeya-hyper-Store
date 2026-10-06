import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Timer? _exitWindow; // running = one more back press closes the app

  @override
  void dispose() {
    _exitWindow?.cancel();
    super.dispose();
  }

  /// System back on a tab: other tabs go to Home; on Home, a second press within 2 s closes the app.
  void _onBack() {
    final shell = widget.shell;
    if (shell.currentIndex != 0) {
      shell.goBranch(0);
      return;
    }
    if (_exitWindow?.isActive ?? false) {
      SystemNavigator.pop();
      return;
    }
    _exitWindow = Timer(const Duration(seconds: 2), () {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final count = ref.watch(cartCountProvider);
    final text = Theme.of(context).textTheme;

    Widget item(int index, IconData icon, IconData active, String label, {int badge = 0}) {
      final selected = shell.currentIndex == index;
      return Expanded(
        child: InkWell(
          onTap: () => shell.goBranch(index, initialLocation: index == shell.currentIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge'),
                  backgroundColor: AppColors.offerRed,
                  child: Icon(selected ? active : icon, color: selected ? AppColors.brand700 : AppColors.inkMuted, size: 26),
                ),
                const SizedBox(height: 3),
                Text(label,
                    style: text.labelSmall?.copyWith(
                      color: selected ? AppColors.brand700 : AppColors.inkMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Row(children: [
            item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
            item(1, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categories'),
            item(2, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'Cart', badge: count),
            item(3, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Orders'),
            item(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
          ]),
        ),
      ),
      ),
    );
  }
}
