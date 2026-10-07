import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout.dart';
import '../../widgets/web_frame.dart';
import '../../widgets/web_product_card.dart';
import '../home/web_home.dart';
import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/add_to_cart.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';

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
    if (isWideLayout(context)) return const _WebCart(); // web shop on laptops & tablets
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
                    const _PausedNotice(),
                    if (c.hasIssues) _IssuesBanner(),
                    _Card(child: Column(children: [
                      for (var i = 0; i < c.lines.length; i++) ...[
                        if (i > 0) const Divider(height: 20),
                        _CartLineTile(line: c.lines[i]),
                      ],
                    ])),
                    _MinimumOrderHint(subtotal: toPaise(c.subtotal)),
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
        ProductImage(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl, name: p.name, size: 72),
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
    // The quote is the server's live answer for this cart; the store's rules fill in before it arrives.
    final quoted = ref.watch(cartQuoteProvider).valueOrNull?.freeDeliveryAbove;
    final threshold = quoted != null ? toPaise(quoted) : ref.watch(storeRulesProvider).freeAbovePaise;
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

/// Admin → Store settings → Minimum order: say so in the cart, not only at checkout.
class _MinimumOrderHint extends ConsumerWidget {
  const _MinimumOrderHint({required this.subtotal});
  final int subtotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimum = ref.watch(storeRulesProvider).minOrderPaise;
    if (minimum <= 0 || subtotal >= minimum) return const SizedBox.shrink();
    return _Notice(
      icon: Icons.shopping_basket_outlined,
      text: 'Minimum order is ${formatPaise(minimum)} — add ${formatPaise(minimum - subtotal)} more to place your order.',
      top: 12,
    );
  }
}

/// Admin → Pause orders: the store's message, before anyone heads to checkout.
class _PausedNotice extends ConsumerWidget {
  const _PausedNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(storePausedMessageProvider).valueOrNull;
    if (message == null) return const SizedBox.shrink();
    return _Notice(icon: Icons.storefront_outlined, text: message, bottom: 12);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.top = 0, this.bottom = 0});
  final IconData icon;
  final String text;
  final double top, bottom;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: top, bottom: bottom),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8A5A00), fontWeight: FontWeight.w600))),
        ]),
      );
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


Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Clear cart?'),
      content: const Text('All items will be removed from your cart.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
      ],
    ),
  );
  if (ok == true) {
    await ref.read(repositoryProvider).clearCart();
    ref.invalidate(cartProvider);
  }
}

/// Web shop cart (laptops/tablets): item table on the left, order summary on the right.
class _WebCart extends ConsumerWidget {
  const _WebCart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final text = Theme.of(context).textTheme;
    final more = ref.watch(homeListsProvider).valueOrNull?.popular ?? const <Product>[];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: cart.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(cartProvider)),
        data: (c) {
          if (c.lines.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 40),
              EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'Your cart is empty',
                message: 'Groceries from Jeya Hyper Store are a few clicks away.',
                action: 'Start Shopping',
                onAction: () => context.go('/home'),
              ),
              const WebFooter(),
            ]);
          }
          final inCart = {for (final l in c.lines) l.product.id};
          final suggestions = more.where((p) => !inCart.contains(p.id)).toList();
          final wide = MediaQuery.sizeOf(context).width >= 1000;
          final table = Container(
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
            child: Column(children: [
              for (var i = 0; i < c.lines.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _WebCartRow(line: c.lines[i]),
              ],
            ]),
          );
          final summary = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _WebOrderSummary(cart: c),
            const SizedBox(height: 14),
            _FreeDeliveryProgress(subtotal: toPaise(c.subtotal)),
          ]);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: 'Your Cart ', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  TextSpan(text: '(${c.lines.length} item${c.lines.length == 1 ? '' : 's'})', style: text.titleMedium?.copyWith(color: AppColors.inkMuted)),
                ])),
                const Spacer(),
                TextButton.icon(onPressed: () => context.go('/home'), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Continue Shopping')),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmClear(context, ref),
                  style: TextButton.styleFrom(foregroundColor: AppColors.offerRed),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Clear Cart'),
                ),
              ]),
              const SizedBox(height: 14),
              const _PausedNotice(),
              if (c.hasIssues) _IssuesBanner(),
              _MinimumOrderHint(subtotal: toPaise(c.subtotal)),
              const SizedBox(height: 4),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: table),
                  const SizedBox(width: 20),
                  SizedBox(width: 380, child: summary),
                ])
              else ...[
                table,
                const SizedBox(height: 16),
                summary,
              ],
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 28),
                Text('Add more essentials', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text('Popular in your store', style: text.bodySmall),
                const SizedBox(height: 12),
                WebProductRow(products: suggestions),
              ],
              const WebFooter(),
            ],
          );
        },
      ),
    );
  }
}

class _WebCartRow extends ConsumerWidget {
  const _WebCartRow({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final p = line.product;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        InkWell(onTap: () => context.push('/product/${p.slug}'), child: ProductImage(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl, name: p.name, size: 72)),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => context.push('/product/${p.slug}'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(p.sizeLabel, style: text.bodySmall),
              if (line.issueText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(line.issueText!, style: text.labelSmall?.copyWith(color: AppColors.offerRed, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ),
        SizedBox(
          width: 130,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(formatRupees(p.sellingPrice), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (p.hasDiscount) ...[
                const SizedBox(width: 6),
                Text(formatRupees(p.mrp), style: text.labelSmall?.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.inkFaint)),
              ],
            ]),
            if (p.hasDiscount) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.offerRedSoft, borderRadius: BorderRadius.circular(4)),
                child: Text('${p.discountPercent}% OFF', style: text.labelSmall?.copyWith(color: AppColors.offerRed, fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ),
        SizedBox(width: 130, child: AddToCartControl(product: p, height: 38)),
        SizedBox(
          width: 100,
          child: Text(formatRupees(line.lineTotal), textAlign: TextAlign.right, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Remove ${p.name}',
          onPressed: () async {
            try {
              await ref.read(cartProvider.notifier).setQty(p, 0);
            } on ApiException catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
            }
          },
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.inkMuted),
        ),
      ]),
    );
  }
}

class _WebOrderSummary extends ConsumerWidget {
  const _WebOrderSummary({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final quote = ref.watch(cartQuoteProvider).valueOrNull;
    final discount = toPaise(cart.mrpTotal) - toPaise(cart.subtotal);
    final delivery = quote == null ? 'At checkout' : (quote.freeDeliveryApplied || toPaise(quote.deliveryFee) == 0 ? 'FREE' : formatRupees(quote.deliveryFee));
    Widget row(String a, String b, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(a, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted))),
            Text(b, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: color)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.brand700),
          const SizedBox(width: 8),
          Text('Order Summary', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        row('Subtotal (${cart.lines.length} items)', formatRupees(cart.mrpTotal)),
        if (discount > 0) row('Product discount', '− ${formatPaise(discount)}', color: AppColors.brand700),
        row('Delivery charge', delivery, color: delivery == 'FREE' ? AppColors.brand700 : null),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Total amount', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              Text(formatRupees(quote?.total ?? cart.subtotal), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: AppColors.brand800)),
            ]),
            if (toPaise(cart.savings) > 0) ...[
              const SizedBox(height: 4),
              Text('You saved ${formatRupees(cart.savings)} on this order!', style: text.labelLarge?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: cart.hasIssues
              ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix the highlighted items first')))
              : () => context.push('/checkout'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.arrow_forward_rounded),
          iconAlignment: IconAlignment.end,
          label: const Text('Proceed to Checkout'),
        ),
      ]),
    );
  }
}
