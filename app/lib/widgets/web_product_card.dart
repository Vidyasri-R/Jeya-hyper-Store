import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'add_to_cart.dart';
import 'product_card.dart';
import 'product_image.dart';
import 'size_picker.dart';

/// Web shop product card (laptops/tablets): discount badge, square photo, name, size,
/// price with struck MRP, and the add / − qty + control.
class WebProductCard extends ConsumerStatefulWidget {
  const WebProductCard({super.key, required this.product, this.width});
  final Product product;
  final double? width;

  @override
  ConsumerState<WebProductCard> createState() => _WebProductCardState();
}

class _WebProductCardState extends ConsumerState<WebProductCard> {
  late Product _selected = initialSize(ref, widget.product);
  /// The customer picked a size (size button, Add's question, or one is in the cart): Add adds it.
  late bool _chosen = _selected.id != widget.product.id || ref.read(cartProvider.notifier).qtyFor(widget.product.id) > 0;

  @override
  void didUpdateWidget(covariant WebProductCard old) {
    super.didUpdateWidget(old);
    if (old.product.id != widget.product.id) {
      _selected = initialSize(ref, widget.product);
      _chosen = _selected.id != widget.product.id || ref.read(cartProvider.notifier).qtyFor(widget.product.id) > 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = _selected;
    final width = widget.width;
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.push('/product/${p.slug}'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(children: [
                AspectRatio(
                  aspectRatio: 1.15,
                  child: Opacity(opacity: p.canBuy ? 1 : 0.5, child: ProductImage(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl, name: p.name, radius: 10)),
                ),
                if (p.hasDiscount) Positioned(left: 0, top: 0, child: DiscountBadge(percent: p.discountPercent)),
              ]),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, height: 1.25)),
              ),
              if (widget.product.variants.isNotEmpty)
                SizePill(product: widget.product, selected: p, onSelected: (v) => setState(() {
                    _selected = v;
                    _chosen = true;
                  }))
              else
                Text(p.sizeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(formatRupees(p.sellingPrice), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: p.hasDiscount ? AppColors.offerRed : AppColors.ink)),
                if (p.hasDiscount) ...[
                  const SizedBox(width: 6),
                  Text(formatRupees(p.mrp), style: text.labelSmall?.copyWith(color: AppColors.inkFaint, decoration: TextDecoration.lineThrough)),
                ],
              ]),
              const SizedBox(height: 8),
              AddToCartControl(product: p, height: 38, sizes: _chosen ? const [] : widget.product.variants, onSizeChosen: (v) => setState(() {
                _selected = v;
                _chosen = true;
              })),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A row of [WebProductCard]s that fills the width with whole cards (as many as fit, ≥ 2).
class WebProductRow extends StatelessWidget {
  const WebProductRow({super.key, required this.products, this.minCardWidth = 190});
  final List<Product> products;
  final double minCardWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 14.0;
      final count = ((c.maxWidth + gap) / (minCardWidth + gap)).floor().clamp(2, 8);
      final w = (c.maxWidth - gap * (count - 1)) / count;
      final shown = products.take(count).toList();
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          WebProductCard(product: shown[i], width: w),
        ],
      ]);
    });
  }
}
