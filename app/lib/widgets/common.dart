import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../core/api/api_client.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../state/providers.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.subtitle, this.onSeeAll, this.padding = const EdgeInsets.fromLTRB(16, 20, 8, 10)});
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null) Text(subtitle!, style: text.bodySmall),
              ],
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('See All'), Icon(Icons.chevron_right, size: 18)]),
            ),
        ],
      ),
    );
  }
}

/// Floating "N items · ₹total · You save ₹x · View Cart" bar from the category screen design.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider).valueOrNull;
    if (cart == null || cart.lines.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final savings = toPaise(cart.savings);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Material(
          color: AppColors.surface,
          elevation: 8,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${cart.lines.length} item${cart.lines.length == 1 ? '' : 's'}', style: text.labelSmall),
                      Row(children: [
                        Text(formatRupees(cart.subtotal), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        if (savings > 0) ...[
                          const SizedBox(width: 6),
                          Text(formatRupees(cart.mrpTotal),
                              style: text.labelSmall?.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.inkFaint)),
                        ],
                      ]),
                      if (savings > 0) Text('You save ${formatPaise(savings)}', style: text.labelSmall?.copyWith(color: AppColors.green700, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => context.go('/cart'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 22)),
                  child: const Row(children: [Text('View Cart'), SizedBox(width: 6), Icon(Icons.arrow_forward, size: 18)]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final e = ApiException.from(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(e.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 48, color: AppColors.inkFaint),
            const SizedBox(height: 12),
            Text(e.message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: AppColors.green50, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: AppColors.green700),
            ),
            const SizedBox(height: 18),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[const SizedBox(height: 6), Text(message!, style: text.bodySmall, textAlign: TextAlign.center)],
            if (action != null) ...[const SizedBox(height: 20), FilledButton(onPressed: onAction, child: Text(action!))],
          ],
        ),
      ),
    );
  }
}

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({super.key, this.width, this.height, this.radius = AppRadius.md});
  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: const Color(0xFFEDF2EE),
        highlightColor: Colors.white,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
        ),
      );
}

/// Grid delegate shared by every product grid (2 columns phones, 3 on wide screens).
SliverGridDelegate productGridDelegate(BuildContext context, {double extraHeight = 0}) {
  // Full-width grids (16px page padding each side).
  final width = MediaQuery.sizeOf(context).width - 32;
  final columns = width > 560 ? 3 : 2;
  final colWidth = (width - 10 * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    mainAxisExtent: colWidth + 132 + extraHeight,
  );
}

/// Visual identity for a category tile (until category photos are uploaded to R2).
({IconData icon, Color bg, Color fg}) categoryVisual(String name) {
  final n = name.toLowerCase();
  if (n.contains('fruit') || n.contains('veg') || n.contains('fresh')) return (icon: Icons.eco_rounded, bg: const Color(0xFFE6F6E9), fg: AppColors.green700);
  if (n.contains('dairy') || n.contains('milk') || n.contains('egg') || n.contains('bread')) return (icon: Icons.egg_alt_rounded, bg: const Color(0xFFFFF6E0), fg: const Color(0xFFB7791F));
  if (n.contains('snack') || n.contains('biscuit')) return (icon: Icons.cookie_rounded, bg: const Color(0xFFFFEDE0), fg: const Color(0xFFC05621));
  if (n.contains('tea') || n.contains('coffee') || n.contains('bever')) return (icon: Icons.local_cafe_rounded, bg: const Color(0xFFF3ECE6), fg: const Color(0xFF7B4B2A));
  if (n.contains('personal')) return (icon: Icons.spa_rounded, bg: const Color(0xFFF3EAFB), fg: const Color(0xFF6B46C1));
  if (n.contains('home') || n.contains('household') || n.contains('clean')) return (icon: Icons.cleaning_services_rounded, bg: const Color(0xFFE6F4FA), fg: const Color(0xFF2B6CB0));
  if (n.contains('baby')) return (icon: Icons.child_friendly_rounded, bg: const Color(0xFFFDEEF4), fg: const Color(0xFFB83280));
  if (n.contains('oil') || n.contains('ghee')) return (icon: Icons.water_drop_rounded, bg: const Color(0xFFFFF8D6), fg: const Color(0xFFB08800));
  if (n.contains('masala') || n.contains('spice')) return (icon: Icons.local_fire_department_rounded, bg: const Color(0xFFFDE8E8), fg: const Color(0xFFC53030));
  if (n.contains('rice') || n.contains('atta') || n.contains('dal') || n.contains('staple') || n.contains('flour')) return (icon: Icons.rice_bowl_rounded, bg: const Color(0xFFF5F0E6), fg: const Color(0xFF8B6B2E));
  if (n.contains('salt') || n.contains('sugar')) return (icon: Icons.grain_rounded, bg: const Color(0xFFF1F3F5), fg: const Color(0xFF4A5568));
  if (n.contains('frozen')) return (icon: Icons.ac_unit_rounded, bg: const Color(0xFFE6F6FF), fg: const Color(0xFF2B6CB0));
  return (icon: Icons.storefront_rounded, bg: AppColors.green50, fg: AppColors.green700);
}

/// Round-cornered category tile with icon (or photo when available) + label.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.name, this.imageUrl, required this.onTap, this.size = 64});
  final String name;
  final String? imageUrl;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final v = categoryVisual(name);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        width: size + 12,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: v.bg, borderRadius: BorderRadius.circular(AppRadius.lg)),
              child: Icon(v.icon, color: v.fg, size: size * 0.48),
            ),
            const SizedBox(height: 6),
            Text(name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink, height: 1.15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
