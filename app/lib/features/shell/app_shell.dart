import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final pack = ref.watch(festivalProvider)?.pack;
    final tabs = SafeArea(
      top: false,
      child: Row(children: [
        item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
        item(1, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categories'),
        item(2, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'Cart', badge: count),
        item(3, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Orders'),
        item(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
      ]),
    );
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: pack == null ? AppColors.surface : AppColors.brandTint,
          border: pack == null ? const Border(top: BorderSide(color: AppColors.line)) : null,
        ),
        child: pack == null
            ? tabs
            : Column(mainAxisSize: MainAxisSize.min, children: [
                // Festival edge: gold scallops on maroon.
                DecoratedBox(
                  decoration: BoxDecoration(image: DecorationImage(image: pack.navBorder, repeat: ImageRepeat.repeatX, alignment: Alignment.topLeft)),
                  child: const SizedBox(height: 10, width: double.infinity),
                ),
                tabs,
              ]),
      ),
    );
  }
}
