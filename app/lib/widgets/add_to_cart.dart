import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'choices_sheet.dart';
import 'size_picker.dart';

/// "Add" button that turns into a − qty + stepper. Handles login, stock limits and loose (kg) steps.
class AddToCartControl extends ConsumerWidget {
  const AddToCartControl({super.key, required this.product, this.height = 34, this.expanded = true, this.big = false, this.sizes = const [], this.onSizeChosen});

  final Product product;
  /// Every size of the product (cards that stand for several): Add first asks which one.
  final List<Product> sizes;
  final ValueChanged<Product>? onSizeChosen;
  final double height;
  final bool expanded;
  final bool big;

  Future<void> _change(BuildContext context, WidgetRef ref, int milli, {Choices? choices, Product? of}) async {
    if (!ref.read(isSignedInProvider)) {
      context.push('/login');
      return;
    }
    try {
      await ref.read(cartProvider.notifier).setQty(of ?? product, milli, choices: choices);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Flavour/colour items: the customer splits the quantity across the store's choices.
  Future<void> _choose(BuildContext context, WidgetRef ref, [Product? of]) async {
    final p = of ?? product;
    if (!ref.read(isSignedInProvider)) {
      context.push('/login');
      return;
    }
    final picked = await showChoicesSheet(context, p, current: ref.read(cartProvider.notifier).choicesFor(p.id));
    if (picked == null || !context.mounted) return;
    final total = picked.values.fold(0, (a, b) => a + b);
    await _change(context, ref, total, choices: total == 0 ? null : picked, of: p);
  }

  /// Several sizes / prices: ask which one, then add it (and its flavours, if it has them).
  Future<void> _pickSize(BuildContext context, WidgetRef ref) async {
    if (!ref.read(isSignedInProvider)) {
      context.push('/login');
      return;
    }
    final size = await showSizeSheet(context, ref, sizes, product, addMode: true);
    if (size == null || !context.mounted) return;
    onSizeChosen?.call(size);
    if (!size.canBuy) return;
    if (size.options != null) return _choose(context, ref, size);
    if (ref.read(cartProvider.notifier).qtyFor(size.id) == 0) await _change(context, ref, size.minMilli, of: size);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cartProvider);
    final qty = ref.read(cartProvider.notifier).qtyFor(product.id);
    final text = Theme.of(context).textTheme;
    final hasOptions = product.options != null;

    // Other sizes in stock: Add (pick one) instead of "Out of stock".
    if (!product.canBuy && qty == 0 && !sizes.any((s) => s.canBuy)) {
      return SizedBox(
        height: height,
        width: expanded ? double.infinity : null,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, height),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
          ),
          child: Text('Out of stock', style: text.labelMedium?.copyWith(color: AppColors.inkFaint)),
        ),
      );
    }

    if (qty == 0) {
      return SizedBox(
        height: height,
        width: expanded ? double.infinity : null,
        child: FilledButton(
          clipBehavior: Clip.antiAlias,
          onPressed: () => sizes.length > 1 ? _pickSize(context, ref) : (hasOptions ? _choose(context, ref) : _change(context, ref, product.minMilli)),
          style: FilledButton.styleFrom(
            minimumSize: Size(0, height),
            padding: EdgeInsets.symmetric(horizontal: big ? 22 : 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(big ? AppRadius.lg : AppRadius.sm)),
            textStyle: (big ? text.titleMedium : text.labelLarge)?.copyWith(fontWeight: FontWeight.w700),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (big) ...[const Icon(Icons.shopping_cart_outlined, size: 20), const SizedBox(width: 8)],
              Text(big ? 'Add to Cart' : 'Add'),
            ],
          ),
        ),
      );
    }

    if (hasOptions) {
      // In the cart: the count, tap to change the flavours.
      return SizedBox(
        height: height,
        width: expanded ? double.infinity : null,
        child: FilledButton(
          onPressed: () => _choose(context, ref),
          style: FilledButton.styleFrom(
            minimumSize: Size(0, height),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(big ? AppRadius.lg : AppRadius.sm)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(formatQty(qty, product.unit), style: (big ? text.titleMedium : text.labelLarge)?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
            ]),
          ),
        ),
      );
    }

    final atMax = qty + product.stepMilli > product.maxMilli;
    final next = qty - product.stepMilli < product.minMilli ? 0 : qty - product.stepMilli;
    return Container(
      height: height,
      width: expanded ? double.infinity : null,
      decoration: AppDecor.brandFill(radius: big ? AppRadius.lg : AppRadius.sm),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepButton(icon: Icons.remove, onTap: () => _change(context, ref, next), size: height),
          // Flexible + scaleDown: "0.75 kg" must never overflow a narrow stepper (cart lines are ~110 px).
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatQty(qty, product.unit),
                  maxLines: 1,
                  style: (big ? text.titleMedium : text.labelLarge)?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            size: height,
            onTap: atMax
                ? () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('Only ${formatQty(product.maxMilli, product.unit)} available')))
                : () => _change(context, ref, qty + product.stepMilli),
            dim: atMax,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap, required this.size, this.dim = false});
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool dim;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          width: size * 0.9,
          height: size,
          child: Icon(icon, color: Colors.white.withValues(alpha: dim ? 0.45 : 1), size: size * 0.5),
        ),
      );
}
