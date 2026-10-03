import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/add_to_cart.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';

/// Free-delivery threshold from public remote config (₹999 today).
final freeDeliveryAboveProvider = FutureProvider<int?>((ref) async {
  final config = await ref.watch(repositoryProvider).publicConfig();
  final rules = config['delivery.rules'] as Map<String, dynamic>?;
  final v = rules?['freeDeliveryAbove'];
  return v is String ? toPaise(v) : null;
});

/// Delivery quote for the cart screen when an address is already chosen.
final cartQuoteProvider = FutureProvider.autoDispose<Quote?>((ref) async {
  final address = ref.watch(selectedAddressProvider);
  final cart = ref.watch(cartProvider).valueOrNull;
  if (address == null || cart == null || cart.lines.isEmpty) return null;
  return ref.watch(repositoryProvider).quote(address.id);
});

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: cart.maybeWhen(
          data: (c) => Text.rich(TextSpan(children: [
            const TextSpan(text: 'Your Cart '),
            if (c.lines.isNotEmpty) TextSpan(text: '(${c.lines.length} item${c.lines.length == 1 ? '' : 's'})', style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
          ])),
          orElse: () => const Text('Your Cart'),
        ),
        actions: [
          if ((cart.valueOrNull?.lines.length ?? 0) > 0)
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Clear cart?'),
                    content: const Text('All items will be removed from your cart.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                      FilledButton(clipBehavior: Clip.antiAlias, onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref.read(repositoryProvider).clearCart();
                  ref.invalidate(cartProvider);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Clear'),
            ),
        ],
      ),
      body: cart.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(cartProvider)),
        data: (c) => c.lines.isEmpty
            ? EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Your cart is empty',
                message: 'Fresh groceries from Jeya Hyper Store are a few taps away.',
                action: 'Start Shopping',
                onAction: () => context.go('/home'),
              )
            : RefreshIndicator(
                color: AppColors.brand700,
                onRefresh: () => ref.read(cartProvider.notifier).refresh(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    if (c.hasIssues) _IssuesBanner(),
                    _Card(child: Column(children: [
                      for (var i = 0; i < c.lines.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _CartLineTile(line: c.lines[i]),
                      ],
                    ])),
                    const SizedBox(height: 12),
                    _FreeDeliveryProgress(subtotal: toPaise(c.subtotal)),
                    const SizedBox(height: 12),
                    _BillSummary(cart: c),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: cart.valueOrNull?.lines.isNotEmpty == true ? _CheckoutBar(cart: cart.value!) : null,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
        child: child,
      );
}

class _IssuesBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF9A6100)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Some items changed in stock. Update your cart to continue.')),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(cartProvider.notifier).fix();
              } on ApiException catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
            child: const Text('Fix cart'),
          ),
        ]),
      );
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = line.product;
    return InkWell(
      onTap: () => context.push('/product/${p.slug}'),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ProductImage(url: p.imageUrl, name: p.name, size: 72),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
            Text(p.sizeLabel, style: text.labelSmall),
            const SizedBox(height: 4),
            Row(children: [
              Text(formatRupees(p.sellingPrice), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (p.hasDiscount) ...[
                const SizedBox(width: 6),
                Text(formatRupees(p.mrp), style: text.labelSmall?.copyWith(decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.offerRedSoft, borderRadius: BorderRadius.circular(4)),
                  child: Text('${p.discountPercent}% OFF', style: text.labelSmall?.copyWith(color: AppColors.offerRed, fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
            if (line.issueText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(line.issueText!, style: text.labelSmall?.copyWith(color: AppColors.offerRed, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(width: 116, child: AddToCartControl(product: p, height: 34)),
          const SizedBox(height: 8),
          Text(formatRupees(line.lineTotal), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}

class _FreeDeliveryProgress extends ConsumerWidget {
  const _FreeDeliveryProgress({required this.subtotal});
  final int subtotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = ref.watch(freeDeliveryAboveProvider).valueOrNull;
    if (threshold == null || threshold <= 0) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final done = subtotal >= threshold;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(children: [
        Icon(done ? Icons.celebration_rounded : Icons.local_shipping_outlined, color: AppColors.brand700),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              done ? 'Yay! You get FREE delivery' : 'Add ${formatPaise(threshold - subtotal)} more to get FREE delivery',
              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (subtotal / threshold).clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: Colors.white,
                color: AppColors.brand700,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Text('${formatPaise(subtotal)} / ${formatPaise(threshold)}', style: text.labelSmall),
      ]),
    );
  }
}

class _BillSummary extends ConsumerWidget {
  const _BillSummary({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final quote = ref.watch(cartQuoteProvider).valueOrNull;
    Widget row(String a, String b, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: bold ? text.titleSmall : text.bodyMedium?.copyWith(color: AppColors.inkMuted))),
            Text(b, style: (bold ? text.titleMedium : text.bodyMedium)?.copyWith(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color)),
          ]),
        );
    final delivery = quote == null ? 'At checkout' : (quote.freeDeliveryApplied || toPaise(quote.deliveryFee) == 0 ? 'FREE' : formatRupees(quote.deliveryFee));
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bill Summary', style: text.titleSmall),
        const SizedBox(height: 8),
        row('Item total (${cart.lines.length} items)', formatRupees(cart.subtotal)),
        row('Delivery charge', delivery, color: delivery == 'FREE' ? AppColors.brand700 : null),
        const Divider(height: 18),
        row('To pay', formatRupees(quote?.total ?? cart.subtotal), bold: true),
        if (toPaise(cart.savings) > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Text('You save ${formatRupees(cart.savings)}', style: text.labelMedium?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

class _CheckoutBar extends ConsumerWidget {
  const _CheckoutBar({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final quote = ref.watch(cartQuoteProvider).valueOrNull;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          // Festive texture during festivals, plain brand colour otherwise.
          child: Ink(decoration: AppDecor.brandFill(radius: AppRadius.lg, edge: false), child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: cart.hasIssues
                ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix the highlighted items first')))
                : () => context.push('/checkout'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(children: [
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(formatRupees(quote?.total ?? cart.subtotal), style: text.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  Text('Total', style: text.labelSmall?.copyWith(color: Colors.white70)),
                ]),
                const Spacer(),
                Text('Proceed to Checkout', style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ]),
            ),
          )),
        ),
      ),
    );
  }
}
