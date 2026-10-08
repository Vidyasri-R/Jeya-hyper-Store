import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api/api_client.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../state/providers.dart';
import 'choices_sheet.dart';
import 'product_image.dart';
import 'size_picker.dart';

/// Flavour/colour items: the customer splits the quantity across the store's choices, then it goes
/// into the cart (signed-out customers go to login first).
Future<void> chooseAndAdd(BuildContext context, WidgetRef ref, Product p) async {
  if (!ref.read(isSignedInProvider)) {
    context.push('/login');
    return;
  }
  final picked = await showChoicesSheet(context, p, current: ref.read(cartProvider.notifier).choicesFor(p.id));
  if (picked == null || !context.mounted) return;
  final total = picked.values.fold(0, (a, b) => a + b);
  try {
    await ref.read(cartProvider.notifier).setQty(p, total, choices: total == 0 ? null : picked);
  } on ApiException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Amazon-style flavour / design swatches on the product page: "Flavour: Vanilla", then a row of
/// photos that scrolls sideways. The selected one gets a border; ones in the cart show how many.
class ChoiceSwatches extends ConsumerWidget {
  const ChoiceSwatches({super.key, required this.product, required this.selected, required this.onSelected});
  final Product product;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = product.options;
    if (options == null) return const SizedBox.shrink();
    ref.watch(cartProvider);
    final inCart = ref.read(cartProvider.notifier).choicesFor(product.id) ?? const {};
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(
        TextSpan(children: [
          TextSpan(text: '${options.label}: ', style: const TextStyle(color: AppColors.inkMuted)),
          TextSpan(text: selected, style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: '   ${options.values.length} ${options.label.toLowerCase()}s', style: const TextStyle(color: AppColors.inkFaint, fontWeight: FontWeight.w400)),
        ]),
        style: text.titleSmall,
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: options.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final v = options.values[i];
            final isSelected = v == selected;
            final count = inCart[v] ?? 0;
            return Semantics(
              selected: isSelected,
              button: true,
              label: v,
              child: InkWell(
                onTap: () => onSelected(v),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 84,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.brandTint : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: isSelected ? AppColors.brand700 : AppColors.line, width: isSelected ? 2 : 1),
                  ),
                  child: Column(children: [
                    Stack(children: [
                      SizedBox(
                        width: 72,
                        height: 64,
                        child: options.images[v] != null
                            ? ProductImage(url: options.images[v], name: v, radius: AppRadius.sm)
                            : Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(AppRadius.sm)),
                                child: Text(v.isEmpty ? '?' : v[0].toUpperCase(), style: text.titleLarge?.copyWith(color: AppColors.inkMuted)),
                              ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.brand700, borderRadius: BorderRadius.circular(99)),
                            child: Text(formatQty(count, product.unit), style: text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 4),
                    Text(v, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, height: 1.15)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

/// "Add" button that turns into a − qty + stepper. Handles login, stock limits and loose (kg) steps.
class AddToCartControl extends ConsumerWidget {
  const AddToCartControl({super.key, required this.product, this.height = 34, this.expanded = true, this.big = false, this.sizes = const [], this.onSizeChosen, this.choice});

  final Product product;
  /// Product page with flavour swatches: Add / − + work on this one flavour.
  final String? choice;
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

  /// [choice] set to [milli] (0 removes it); the other flavours in the cart stay.
  Future<void> _setChoice(BuildContext context, WidgetRef ref, int milli) {
    final picked = {...?ref.read(cartProvider.notifier).choicesFor(product.id)};
    if (milli <= 0) {
      picked.remove(choice);
    } else {
      picked[choice!] = milli;
    }
    final total = picked.values.fold(0, (a, b) => a + b);
    return _change(context, ref, total, choices: total == 0 ? null : picked);
  }

  /// Flavour/colour items: the customer splits the quantity across the store's choices.
  Future<void> _choose(BuildContext context, WidgetRef ref, [Product? of]) => chooseAndAdd(context, ref, of ?? product);

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

  void _limit(BuildContext context) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('Only ${formatQty(product.maxMilli, product.unit)} available')));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cartProvider);
    final total = ref.read(cartProvider.notifier).qtyFor(product.id);
    final perChoice = choice != null && product.options != null;
    // Flavour swatches: the button and stepper count only the selected flavour.
    final qty = perChoice ? (ref.read(cartProvider.notifier).choicesFor(product.id)?[choice] ?? 0) : total;
    final text = Theme.of(context).textTheme;
    final hasOptions = product.options != null && !perChoice;

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
          onPressed: () {
            if (perChoice) {
              if (total + product.minMilli > product.maxMilli) return _limit(context);
              _setChoice(context, ref, product.minMilli);
            } else if (sizes.length > 1) {
              _pickSize(context, ref);
            } else if (hasOptions) {
              _choose(context, ref);
            } else {
              _change(context, ref, product.minMilli);
            }
          },
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

    final atMax = (perChoice ? total : qty) + product.stepMilli > product.maxMilli;
    final next = perChoice ? qty - product.stepMilli : (qty - product.stepMilli < product.minMilli ? 0 : qty - product.stepMilli);
    void set(int milli) => perChoice ? _setChoice(context, ref, milli) : _change(context, ref, milli);
    return Container(
      height: height,
      width: expanded ? double.infinity : null,
      decoration: AppDecor.brandFill(radius: big ? AppRadius.lg : AppRadius.sm),
      child: Row(
        mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepButton(icon: Icons.remove, onTap: () => set(next), size: height),
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
            onTap: atMax ? () => _limit(context) : () => set(qty + product.stepMilli),
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
