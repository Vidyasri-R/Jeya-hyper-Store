import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/add_to_cart.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_image.dart';
import '../../core/navigation.dart';

final _relatedProvider = FutureProvider.family<List<Product>, ({String category, int exclude})>((ref, arg) async {
  final page = await ref.watch(repositoryProvider).products(category: arg.category, inStock: true, limit: 12);
  return page.items.where((p) => p.id != arg.exclude).toList();
});

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productProvider(slug));
    return product.when(
      loading: () => Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.brand700))),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorRetry(error: e, onRetry: () => ref.invalidate(productProvider(slug)))),
      data: (p) => _Detail(product: p),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = product;
    final leaf = p.breadcrumb.isNotEmpty ? p.breadcrumb.last : null;
    final related = leaf == null ? null : ref.watch(_relatedProvider((category: leaf.slug, exclude: p.id)));
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: width * 0.92,
            backgroundColor: AppColors.surface,
            leading: _RoundIcon(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
            actions: [
              _RoundIcon(icon: Icons.search_rounded, onTap: () => context.push('/search')),
              _RoundIcon(icon: Icons.shopping_cart_outlined, onTap: () => openCart(context)),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.brandTint,
                padding: EdgeInsets.fromLTRB(32, MediaQuery.paddingOf(context).top + 56, 32, 24),
                child: Hero(tag: 'p${p.id}', child: ProductImage(url: p.imageUrl, name: p.name, radius: AppRadius.lg)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p.breadcrumb.isNotEmpty)
                    Text(p.breadcrumb.map((b) => b.name).join('  ›  '), style: text.labelSmall),
                  const SizedBox(height: 6),
                  Text(p.name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                  if (p.brand != null) ...[
                    const SizedBox(height: 4),
                    Text(p.brand!, style: text.bodyMedium?.copyWith(color: AppColors.brandBlue, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 4),
                  Text(p.sizeLabel, style: text.bodySmall),
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    PriceLine(price: p.sellingPrice, mrp: p.mrp, showMrp: p.hasDiscount, large: true),
                    const SizedBox(width: 10),
                    if (p.hasDiscount) DiscountBadge(percent: p.discountPercent, large: true),
                  ]),
                  Text('Inclusive of all taxes', style: text.labelSmall),
                  const SizedBox(height: 10),
                  _StockLine(product: p),
                  const SizedBox(height: 16),
                  const _PromiseStrip(),
                  if (p.description != null && p.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('About this product', style: text.titleSmall),
                    const SizedBox(height: 6),
                    Text(p.description!, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted, height: 1.45)),
                  ],
                ],
              ),
            ),
          ),
          if (related != null)
            ...related.maybeWhen(
              data: (items) => items.isEmpty
                  ? <Widget>[]
                  : [
                      const SliverToBoxAdapter(child: SectionHeader(title: 'You might also need')),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: (width - 48) / 2.6 + 132,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => ProductCard(product: items[i], width: (width - 48) / 2.6),
                          ),
                        ),
                      ),
                    ],
              orElse: () => <Widget>[],
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                PriceLine(price: p.sellingPrice, mrp: p.mrp, showMrp: p.hasDiscount),
                Text('${p.name.length > 22 ? '${p.name.substring(0, 22)}…' : p.name} (${p.sizeLabel})', style: text.labelSmall, maxLines: 1),
              ]),
            ),
            SizedBox(width: width * 0.48, child: AddToCartControl(product: p, height: 50, big: true)),
          ]),
        ),
      ),
    );
  }
}

class _StockLine extends StatelessWidget {
  const _StockLine({required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (product.stockStatus) {
      StockStatus.inStock => ('In stock', AppColors.brand700, Icons.check_circle_rounded),
      StockStatus.lowStock => ('Only a few left', const Color(0xFFB7791F), Icons.timelapse_rounded),
      StockStatus.outOfStock => ('Out of stock', AppColors.offerRed, Icons.remove_circle_outline_rounded),
    };
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _PromiseStrip extends ConsumerWidget {
  const _PromiseStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    Widget item(IconData icon, String a, String b) => Expanded(
          child: Row(children: [
            Icon(icon, color: AppColors.brand700, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a, style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(b, style: text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        item(Icons.local_shipping_outlined, ref.watch(deliverySpeedProvider).short, 'delivery'),
        item(Icons.verified_outlined, 'Quality', 'checked'),
        item(Icons.currency_rupee_rounded, 'Best price', 'in Trichy'),
      ]),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 1,
          child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 20))),
        ),
      );
}
