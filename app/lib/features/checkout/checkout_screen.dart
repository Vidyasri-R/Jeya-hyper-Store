import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';
import 'razorpay_payment.dart';

final _quoteProvider = FutureProvider.autoDispose.family<Quote, String>((ref, addressId) => ref.watch(repositoryProvider).quote(addressId));

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  /// One key per checkout screen: double taps / retries return the same order.
  final _idempotencyKey = const Uuid().v4().replaceAll('-', '');
  final _note = TextEditingController();
  final _payment = RazorpayPayment();
  String? _method; // 'online' | 'cod'
  bool _placing = false;

  @override
  void dispose() {
    _payment.dispose();
    _note.dispose();
    super.dispose();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _place(Address address, Quote quote) async {
    final method = _method ?? (quote.onlineAvailable ? 'online' : 'cod');
    setState(() => _placing = true);
    final repo = ref.read(repositoryProvider);
    try {
      final order = await repo.placeOrder(
        addressId: address.id,
        paymentMethod: method,
        idempotencyKey: _idempotencyKey,
        expectedTotal: quote.total,
        note: _note.text.trim(),
      );
      ref.invalidate(cartProvider);
      if (!mounted) return;
      if (method == 'cod') return context.go('/order-success/${order.id}');
      await _payOnline(order);
    } on ApiException catch (e) {
      if (!mounted) return;
      switch (e.reason) {
        case 'total_changed':
          ref.invalidate(_quoteProvider(address.id));
          await showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Price updated'),
              content: Text('Prices or delivery charges changed. Your new total is ${formatRupees(e.details['total'] as String? ?? quote.total)}. Please review and place the order again.'),
              actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Review'))],
            ),
          );
        case 'stock_changed' || 'cart_needs_review':
          ref.invalidate(cartProvider);
          _snack(e.message);
          context.go('/cart');
        default:
          _snack(e.message);
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  /// Razorpay flow for a pending_payment order. Retry-safe: the server reuses the same gateway order.
  Future<void> _payOnline(Order order) async {
    final repo = ref.read(repositoryProvider);
    while (mounted) {
      final init = await repo.startPayment(order.id);
      final auth = ref.read(authProvider);
      final outcome = await _payment.open(init, email: auth is SignedIn ? auth.user.email : null);
      if (!mounted) return;
      if (outcome is PaymentSucceeded) {
        final status = await repo.confirmPayment(order.id, razorpayOrderId: outcome.orderId, paymentId: outcome.paymentId, signature: outcome.signature);
        if (!mounted) return;
        if (status == 'processing') await _waitForPayment(order.id);
        if (mounted) context.go('/order-success/${order.id}');
        return;
      }
      final failed = outcome as PaymentFailed;
      final retry = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: false,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(failed.cancelled ? Icons.info_outline_rounded : Icons.error_outline_rounded, size: 44, color: failed.cancelled ? AppColors.amber : AppColors.offerRed),
              const SizedBox(height: 10),
              Text(failed.message, textAlign: TextAlign.center, style: Theme.of(c).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Your items are held for a few minutes. You can try paying again.', textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodySmall),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Try again')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('View order')),
            ]),
          ),
        ),
      );
      if (retry != true) {
        if (mounted) context.go('/order/${order.id}');
        return;
      }
    }
  }

  Future<void> _waitForPayment(String orderId) async {
    final repo = ref.read(repositoryProvider);
    for (var i = 0; i < 20 && mounted; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final o = await repo.order(orderId);
      if (o.paymentStatus == 'paid' || o.isClosed) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final address = ref.watch(selectedAddressProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Checkout'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.green700, size: 18),
              const SizedBox(width: 4),
              Text('100% Secure', style: text.labelSmall?.copyWith(color: AppColors.green700, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
      body: addresses.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green700)),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(addressesProvider)),
        data: (list) {
          if (list.isEmpty || address == null) {
            return EmptyState(
              icon: Icons.add_location_alt_outlined,
              title: 'Add a delivery address',
              message: 'Drop a pin so we can calculate delivery from Jeya Hyper Store.',
              action: 'Add Address',
              onAction: () => context.push('/address'),
            );
          }
          final quote = ref.watch(_quoteProvider(address.id));
          return quote.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green700)),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(_quoteProvider(address.id))),
            data: (q) => _body(context, address, q),
          );
        },
      ),
      bottomNavigationBar: () {
        final address = ref.watch(selectedAddressProvider);
        final q = address == null ? null : ref.watch(_quoteProvider(address.id)).valueOrNull;
        if (address == null || q == null) return null;
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
            child: Row(children: [
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(formatRupees(q.total), style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Total to pay', style: text.labelSmall),
                ]),
              ),
              FilledButton(
                onPressed: q.canPlaceOrder && !_placing ? () => _place(address, q) : null,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28)),
                child: _placing
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Row(children: [Text('Place Order'), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, size: 20)]),
              ),
            ]),
          ),
        );
      }(),
    );
  }

  Widget _body(BuildContext context, Address address, Quote q) {
    final text = Theme.of(context).textTheme;
    _method ??= q.onlineAvailable ? 'online' : 'cod';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _Steps(current: 1),
        const SizedBox(height: 12),
        for (final b in q.blockers)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.offerRedSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.offerRed),
              const SizedBox(width: 10),
              Expanded(child: Text(b.message)),
              if (b.reason == 'cart_needs_review') TextButton(onPressed: () => context.go('/cart'), child: const Text('Review')),
            ]),
          ),
        _Section(
          number: 1,
          title: 'Delivery Address',
          action: TextButton(onPressed: () => context.push('/addresses?select=1'), child: const Text('Change')),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(address.title.toLowerCase() == 'work' ? Icons.business_rounded : Icons.home_rounded, color: AppColors.green700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${address.title} · ${address.recipientName}', style: text.titleSmall),
                const SizedBox(height: 2),
                Text(address.oneLine, style: text.bodySmall),
              ]),
            ),
          ]),
        ),
        _Section(
          number: 2,
          title: 'Delivery',
          child: Row(children: [
            const Icon(Icons.bolt_rounded, color: AppColors.green700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Same-day delivery', style: text.titleSmall),
                Text(q.distanceKm != null ? '${q.distanceKm!.toStringAsFixed(1)} km from Jeya Hyper Store' : 'From Jeya Hyper Store, Trichy', style: text.bodySmall),
              ]),
            ),
            Text(q.freeDeliveryApplied || toPaise(q.deliveryFee) == 0 ? 'FREE' : formatRupees(q.deliveryFee),
                style: text.titleSmall?.copyWith(color: AppColors.green700, fontWeight: FontWeight.w800)),
          ]),
        ),
        _Section(
          number: 3,
          title: 'Payment Method',
          child: Column(children: [
            if (q.onlineAvailable)
              _PayOption(
                value: 'online',
                group: _method!,
                icon: Icons.account_balance_wallet_outlined,
                title: 'Pay Online',
                subtitle: 'UPI (GPay, PhonePe, Paytm), cards, netbanking, wallets',
                badge: 'Recommended',
                onTap: () => setState(() => _method = 'online'),
              ),
            if (q.codAvailable)
              _PayOption(
                value: 'cod',
                group: _method!,
                icon: Icons.payments_outlined,
                title: 'Cash on Delivery',
                subtitle: 'Pay with cash or UPI when your order arrives',
                onTap: () => setState(() => _method = 'cod'),
              ),
          ]),
        ),
        _Section(
          title: 'Order Summary',
          child: Column(children: [
            for (final l in q.lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  ProductImage(url: l.product.imageUrl, name: l.product.name, size: 44, radius: AppRadius.sm),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge),
                      Text('Qty ${formatQty(l.qtyMilli, l.product.unit)} × ${formatRupees(l.product.sellingPrice)}', style: text.labelSmall),
                    ]),
                  ),
                  Text(formatRupees(l.lineTotal), style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
            const Divider(height: 20),
            _BillRow('Item total', formatRupees(q.subtotal)),
            _BillRow('Delivery charge', q.freeDeliveryApplied || toPaise(q.deliveryFee) == 0 ? 'FREE' : formatRupees(q.deliveryFee)),
            const Divider(height: 18),
            _BillRow('Total amount', formatRupees(q.total), bold: true),
            if (toPaise(q.savings) > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text('You save ${formatRupees(q.savings)}', style: text.labelMedium?.copyWith(color: AppColors.green700, fontWeight: FontWeight.w700)),
              ),
          ]),
        ),
        _Section(
          title: 'Delivery instructions (optional)',
          child: TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'e.g. Ring the bell, leave with security', counterText: ''),
          ),
        ),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.current});
  final int current;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget dot(int i, String label) {
      final done = i < current;
      final active = i == current;
      return Column(children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: done || active ? AppColors.green700 : AppColors.line,
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text('${i + 1}', style: text.labelSmall?.copyWith(color: active ? Colors.white : AppColors.inkMuted, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 4),
        Text(label, style: text.labelSmall?.copyWith(color: active || done ? AppColors.ink : AppColors.inkFaint, fontWeight: FontWeight.w600)),
      ]);
    }

    Widget bar(bool on) => Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 16), color: on ? AppColors.green700 : AppColors.line));
    return Row(children: [dot(0, 'Cart'), bar(current > 0), dot(1, 'Delivery'), bar(current > 1), dot(2, 'Payment')]);
  }
}

class _Section extends StatelessWidget {
  const _Section({this.number, required this.title, required this.child, this.action});
  final int? number;
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(number != null ? '$number. $title' : title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          ?action,
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}

class _PayOption extends StatelessWidget {
  const _PayOption({required this.value, required this.group, required this.icon, required this.title, required this.subtitle, required this.onTap, this.badge});
  final String value;
  final String group;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final selected = value == group;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.green50 : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.green700 : AppColors.line, width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.green700 : AppColors.inkFaint),
          const SizedBox(width: 10),
          Icon(icon, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(title, style: text.titleSmall),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.green700, borderRadius: BorderRadius.circular(10)),
                    child: Text(badge!, style: text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              Text(subtitle, style: text.labelSmall),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: bold ? text.titleSmall : text.bodyMedium?.copyWith(color: AppColors.inkMuted))),
        Text(value,
            style: (bold ? text.titleMedium : text.bodyMedium)?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: value == 'FREE' ? AppColors.green700 : null,
            )),
      ]),
    );
  }
}
