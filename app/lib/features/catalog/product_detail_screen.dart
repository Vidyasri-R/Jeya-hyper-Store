import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../widgets/web_product_card.dart';
import '../../widgets/web_frame.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/add_to_cart.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_image.dart';
import '../../widgets/size_picker.dart';
import '../../core/layout.dart';
import '../../core/navigation.dart';

final _relatedProvider = FutureProvider.family<List<Product>, ({String category, int exclude})>((ref, arg) async {
  final page = await ref.watch(repositoryProvider).products(category: arg.category, inStock: true, limit: 12);
  return page.items.where((p) => p.id != arg.exclude).toList();
});

/// Picking another size swaps the product on this same page (no new page); the last product stays
/// on screen while the new size loads.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late String _slug = widget.slug;
  Product? _shown;
  /// The size just picked, shown at once from the sizes list until its details arrive.
  Product? _instant;
  /// The flavour / design picked on the page (Amazon-style swatches); the first one until then.
  String? _choice;

  @override
  void didUpdateWidget(covariant ProductDetailScreen old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) _slug = widget.slug;
  }

  void _pickSize(Product v) {
    if (v.slug == _slug) return;
    setState(() {
      _instant = _shown == null ? null : v.onPageOf(_shown!);
      _slug = v.slug;
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = ref.watch(productProvider(_slug));
    if (product.hasValue) {
      _shown = product.value;
      _instant = null;
    }
    final p = _instant ?? product.valueOrNull ?? _shown;
    if (p == null) {
      return product.hasError
          ? Scaffold(appBar: AppBar(), body: ErrorRetry(error: product.error!, onRetry: () => ref.invalidate(productProvider(_slug))))
          : Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.brand700)));
    }
    final values = p.options?.values ?? const <String>[];
    final choice = values.isEmpty ? null : (values.contains(_choice) ? _choice : values.first);
    return _Detail(product: p, onPickSize: _pickSize, pickedSlug: _slug, choice: choice, onChoice: (v) => setState(() => _choice = v));
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.product, required this.onPickSize, required this.pickedSlug, this.choice, required this.onChoice});
  final Product product;
  final ValueChanged<Product> onPickSize;
  /// Selected flavour / design (products with choices): its photo is shown and Add adds it.
  final String? choice;
  final ValueChanged<String> onChoice;
  /// The size just picked (highlighted at once, while its details load).
  final String pickedSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = product;
    final leaf = p.breadcrumb.isNotEmpty ? p.breadcrumb.last : null;
    final related = leaf == null ? null : ref.watch(_relatedProvider((category: leaf.slug, exclude: p.id)));
    final width = MediaQuery.sizeOf(context).width;

    final details = Column(
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
                  // Flavours first: a long row of sizes (e.g. 26 Arun prices) would push them out of sight.
                  if (p.options != null && choice != null) ...[
                    const SizedBox(height: 8),
                    ChoiceSwatches(product: p, selected: choice!, onSelected: onChoice),
                    const SizedBox(height: 6),
                  ],
                  if (p.variants.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SizeChips(product: p, selectedSlug: pickedSlug, onPick: onPickSize),
                  ] else
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
              );
    final wide = isWideLayout(context);
    final railWidth = productRailCardWidth(context);
    final compact = compactProducts(context);

    if (wide) {
      return _WideProductPage(product: p, details: details, related: related, railWidth: railWidth, onPickSize: onPickSize, pickedSlug: pickedSlug, choice: choice, onChoice: onChoice);
    }

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
                child: Hero(tag: 'p${p.id}', child: ProductImage(url: p.choiceImage(choice) ?? p.imageUrl, placeholderUrl: p.placeholderImageUrl, name: p.name, radius: AppRadius.lg)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: details,
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
                          height: railWidth + (compact ? 118 : 132),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, _) => SizedBox(width: compact ? 6 : 10),
                            itemBuilder: (_, i) => ProductCard(product: items[i], width: railWidth, compact: compact),
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
                Text('${p.name.length > 22 ? '${p.name.substring(0, 22)}…' : p.name} (${choice ?? p.sizeLabel})', style: text.labelSmall, maxLines: 1),
              ]),
            ),
            SizedBox(width: width * 0.48, child: AddToCartControl(product: p, height: 50, big: true, choice: choice)),
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

/// Web shop product page (laptops/tablets): photo · details table and add · delivery & trust cards,
/// then the description and similar products.
class _WideProductPage extends ConsumerWidget {
  const _WideProductPage({required this.product, required this.details, required this.related, required this.railWidth, required this.onPickSize, required this.pickedSlug, this.choice, required this.onChoice});
  final Product product;
  final String? choice;
  final ValueChanged<String> onChoice;
  final ValueChanged<Product> onPickSize;
  final String pickedSlug;
  final Widget details; // phone details column (unused here, kept for the shared signature)
  final AsyncValue<List<Product>>? related;
  final double railWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = product;
    final items = related?.valueOrNull ?? const <Product>[];
    final address = ref.watch(selectedAddressProvider);
    final speed = ref.watch(deliverySpeedProvider);
    final rules = ref.watch(storeRulesProvider);
    final free = rules.freeAbovePaise;
    final width = MediaQuery.sizeOf(context).width;
    final threeCols = width >= 1100;

    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(label, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted))),
            Text(':  ', style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
            Expanded(child: value),
          ]),
        );
    Widget card(IconData icon, String title, Widget child) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, color: AppColors.brand700, size: 20), const SizedBox(width: 8), Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700))]),
            const SizedBox(height: 10),
            child,
          ]),
        );

    final photo = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
      child: AspectRatio(aspectRatio: 1, child: Hero(tag: 'p${p.id}', child: ProductImage(url: p.choiceImage(choice) ?? p.imageUrl, placeholderUrl: p.placeholderImageUrl, name: p.name, radius: 12))),
    );

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(p.name, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
      if (p.brand != null) ...[
        const SizedBox(height: 6),
        Text(p.brand!, style: text.titleSmall?.copyWith(color: AppColors.brandBlue, fontWeight: FontWeight.w700)),
      ],
      const SizedBox(height: 14),
      if (p.brand != null) row('Brand', Text(p.brand!, style: text.bodyMedium)),
      if (p.options != null && choice != null) ...[
        const SizedBox(height: 6),
        ChoiceSwatches(product: p, selected: choice!, onSelected: onChoice),
        const SizedBox(height: 6),
      ],
      row('Pack size', p.variants.isNotEmpty ? SizeChips(product: p, selectedSlug: pickedSlug, onPick: onPickSize) : Text(p.sizeLabel, style: text.bodyMedium)),
      if (p.hasDiscount) row('MRP', Text('${formatRupees(p.mrp)} (inclusive of all taxes)', style: text.bodyMedium?.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.inkMuted))),
      row(
        'Selling price',
        Row(children: [
          Text(formatRupees(p.sellingPrice), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: p.hasDiscount ? AppColors.offerRed : AppColors.ink)),
          const SizedBox(width: 10),
          if (p.hasDiscount) DiscountBadge(percent: p.discountPercent, large: true),
        ]),
      ),
      if (p.gstRate != null) row('GST', Text('${p.gstRate!.replaceAll(RegExp(r'\.0+$'), '')}% (included)', style: text.bodyMedium)),
      row('Availability', _StockLine(product: p)),
      const SizedBox(height: 18),
      Row(children: [
        SizedBox(width: 240, child: AddToCartControl(product: p, height: 50, big: true, choice: choice)),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => openCart(context),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
          icon: const Icon(Icons.shopping_cart_outlined),
          label: const Text('View cart'),
        ),
      ]),
      if (free != null && free > 0) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_shipping_outlined, color: AppColors.brand700),
            const SizedBox(width: 8),
            Text('Free delivery on orders above ${formatPaise(free)}', style: text.labelLarge?.copyWith(color: AppColors.brand800, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
    ]);

    final side = Column(children: [
      card(
        Icons.local_shipping_outlined,
        'Delivery information',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 18, color: AppColors.offerRed),
            const SizedBox(width: 6),
            Expanded(child: Text(address == null ? 'Tiruchirappalli' : '${address.title} · ${address.city} ${address.pincode}', style: text.bodyMedium)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: AppColors.brand700, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(speed.headline, style: text.labelLarge?.copyWith(color: AppColors.brand800, fontWeight: FontWeight.w700))),
            ]),
          ),
        ]),
      ),
      card(
        Icons.lock_outline_rounded,
        'Secure payment',
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in [if (rules.online) 'UPI', if (rules.online) 'Cards', if (rules.online) 'Net banking', if (rules.cod) 'Cash on delivery'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.line)),
              child: Text(m, style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
      card(
        Icons.verified_user_outlined,
        'Shop with confidence',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (icon, label) in [(Icons.storefront_outlined, 'From our own store in Trichy'), (Icons.replay_rounded, 'Damaged or wrong item? Tell us within 24 hours')])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 18, color: AppColors.brand700),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: text.bodySmall)),
              ]),
            ),
        ]),
      ),
    ]);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        children: [
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            TextButton(onPressed: () => context.go('/home'), style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)), child: const Text('Home')),
            for (final b in p.breadcrumb) ...[
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkFaint),
              TextButton(onPressed: () => context.go('/categories?c=${b.slug}'), style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)), child: Text(b.name)),
            ],
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkFaint),
            Text(p.name, style: text.labelLarge),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 4, child: photo),
            const SizedBox(width: 24),
            Expanded(flex: 5, child: info),
            if (threeCols) ...[const SizedBox(width: 24), SizedBox(width: 300, child: side)],
          ]),
          if (!threeCols) ...[const SizedBox(height: 18), side],
          if (p.description != null && p.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Product details', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(p.description!, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted, height: 1.5)),
              ]),
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Similar products', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            WebProductRow(products: items),
          ],
          const WebFooter(),
        ],
      ),
    );
  }
}
