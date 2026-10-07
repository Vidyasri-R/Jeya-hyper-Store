import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'add_to_cart.dart';
import 'product_image.dart';

/// Grid / rail card from the approved design: badge, single image, name, size, price + MRP, Add.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.width, this.compact = false});

  final Product product;
  final double? width;
  /// Three-per-row grids on phones: tighter padding and type.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => context.push('/product/${product.slug}'),
          child: Container(
            padding: EdgeInsets.all(compact ? 5 : 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Opacity(
                        opacity: product.canBuy ? 1 : 0.5,
                        child: ProductImage(url: product.imageUrl, name: product.name),
                      ),
                    ),
                    if (product.hasDiscount)
                      Positioned(left: 0, top: 0, child: DiscountBadge(percent: product.discountPercent)),
                    if (product.stockStatus == StockStatus.lowStock)
                      Positioned(
                        left: 0,
                        bottom: 0,
                        child: _Tag(label: 'Few left', bg: AppColors.amberSoft, fg: const Color(0xFF9A6100)),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 5 : 8),
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: (compact ? text.labelMedium : text.labelLarge)?.copyWith(height: 1.2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(product.sizeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall),
                const Spacer(),
                PriceLine(price: product.sellingPrice, mrp: product.mrp, showMrp: product.hasDiscount, compact: compact),
                SizedBox(height: compact ? 4 : 6),
                AddToCartControl(product: product, height: compact ? 30 : 34),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PriceLine extends StatelessWidget {
  const PriceLine({super.key, required this.price, required this.mrp, required this.showMrp, this.large = false, this.compact = false});
  final String price;
  final String mrp;
  final bool showMrp;
  final bool large;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: compact ? 4 : 6,
      children: [
        Text(formatRupees(price), style: (large ? text.headlineSmall : (compact ? text.labelLarge : text.titleSmall))?.copyWith(fontWeight: FontWeight.w800)),
        if (showMrp)
          Text(
            formatRupees(mrp),
            style: (large ? text.bodyLarge : text.labelSmall)?.copyWith(
              color: AppColors.inkFaint,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.inkFaint,
            ),
          ),
      ],
    );
  }
}

class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent, this.large = false});
  final int percent;
  final bool large;

  @override
  Widget build(BuildContext context) => _Tag(
        label: '$percent% OFF',
        bg: large ? AppColors.offerRedSoft : AppColors.offerRed,
        fg: large ? AppColors.offerRed : Colors.white,
        large: large,
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.bg, required this.fg, this.large = false});
  final String label;
  final Color bg;
  final Color fg;
  final bool large;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 8 : 6, vertical: large ? 4 : 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: fg, fontSize: large ? 13 : 10, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
      );
}
