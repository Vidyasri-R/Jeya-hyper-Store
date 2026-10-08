import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';

/// The size a product card should start on: one already in the cart, else the one it was sent with.
Product initialSize(WidgetRef ref, Product product) {
  if (product.variants.isEmpty) return product;
  final cart = ref.read(cartProvider.notifier);
  if (cart.qtyFor(product.id) > 0) return product;
  return product.variants.firstWhere((v) => cart.qtyFor(v.id) > 0, orElse: () => product);
}

/// "100 g ▾" under the name: opens the list of sizes with their prices.
class SizePill extends ConsumerWidget {
  const SizePill({super.key, required this.product, required this.selected, required this.onSelected, this.compact = false});
  final Product product;
  final Product selected;
  final ValueChanged<Product> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () async {
        final picked = await showSizeSheet(context, ref, product.variants, selected);
        if (picked != null) onSelected(picked);
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(compact ? 6 : 8, 2, 2, 2),
        decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: Text(selected.variantLabel ?? selected.sizeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.ink)),
          ),
          Icon(Icons.arrow_drop_down_rounded, size: compact ? 16 : 18, color: AppColors.inkMuted),
        ]),
      ),
    );
  }
}

/// Bottom sheet listing every size: label, price (MRP struck), stock, and how many are in the cart.
/// [addMode]: opened from Add — "Which one do you want?" and out-of-stock sizes can't be picked.
Future<Product?> showSizeSheet(BuildContext context, WidgetRef ref, List<Product> sizes, Product selected, {bool addMode = false}) {
  return showModalBottomSheet<Product>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final cart = ref.read(cartProvider.notifier);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 0, 8, 12), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(addMode ? 'Which one do you want?' : 'Choose a size', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final v in sizes)
              ListTile(
                selected: v.id == selected.id,
                selectedTileColor: AppColors.brand50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                title: Text(v.variantLabel ?? v.sizeLabel, style: text.titleSmall),
                subtitle: !v.canBuy
                    ? Text('Out of stock', style: text.bodySmall?.copyWith(color: AppColors.offerRed))
                    : (cart.qtyFor(v.id) > 0 ? Text('${formatQty(cart.qtyFor(v.id), v.unit)} in cart', style: text.bodySmall?.copyWith(color: AppColors.brand700)) : null),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (v.hasDiscount)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(formatRupees(v.mrp), style: text.labelSmall?.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.inkFaint)),
                    ),
                  // Price points ("₹10") already say the price.
                  if ((v.variantLabel ?? '') != formatRupees(v.sellingPrice))
                    Text(formatRupees(v.sellingPrice), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ]),
                enabled: !addMode || v.canBuy,
                onTap: () => Navigator.pop(context, v),
              ),
          ]),
        ),
      );
    },
  );
}

/// Product page: every size as a chip with its price; picking one opens that size's page.
class SizeChips extends StatelessWidget {
  const SizeChips({super.key, required this.product, required this.onPick});
  final Product product;
  final ValueChanged<Product> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final v in product.variants)
        ChoiceChip(
          selected: v.id == product.id,
          showCheckmark: false,
          onSelected: v.id == product.id ? null : (_) => onPick(v),
          label: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(v.variantLabel ?? v.sizeLabel, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            if (!v.canBuy || (v.variantLabel ?? '') != formatRupees(v.sellingPrice))
              Text(v.canBuy ? formatRupees(v.sellingPrice) : 'Out of stock', style: text.labelSmall?.copyWith(color: v.canBuy ? AppColors.ink : AppColors.offerRed)),
          ]),
        ),
    ]);
  }
}
