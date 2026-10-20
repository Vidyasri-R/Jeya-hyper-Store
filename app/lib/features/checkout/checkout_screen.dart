import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/layout.dart';
import '../../widgets/web_frame.dart';
import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/dates.dart';
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
              actions: [FilledButton(clipBehavior: Clip.antiAlias, onPressed: () => Navigator.pop(c), child: const Text('Review'))],
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
        final paid = status == 'processing' ? await _waitForPayment(order.id) : true;
        if (!mounted) return;
        // Never show "Order placed" for money that hasn't arrived: the order page says what's happening.
        context.go(paid ? '/order-success/${order.id}' : '/order/${order.id}');
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
              Text('Your order is not confirmed until you pay. Your items are held for a few minutes.', textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodySmall),
              const SizedBox(height: 18),
              FilledButton(clipBehavior: Clip.antiAlias, onPressed: () => Navigator.pop(c, true), child: const Text('Try again')),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel order, keep my cart')),
            ]),
          ),
        ),
      );
      if (retry != true) {
        // Not paying now: cancel the unpaid order and put the items back in the cart.
        try {
          await repo.cancelOrder(order.id, reason: 'Payment not completed');
          await repo.mergeCart(order.items.isNotEmpty ? order.items : (await repo.order(order.id)).items);
        } on ApiException {
          // Already cancelled / expired, or the cart couldn't be refilled: the order page explains.
          if (mounted) context.go('/order/${order.id}');
          return;
        } finally {
          ref.invalidate(cartProvider);
        }
        if (!mounted) return;
        _snack('Order cancelled — your items are back in the cart');
        context.go('/cart');
        return;
      }
    }
  }

  /// Polls ~60 s for a payment Razorpay reported as processing. True once it's actually paid.
  Future<bool> _waitForPayment(String orderId) async {
    final repo = ref.read(repositoryProvider);
    for (var i = 0; i < 20 && mounted; i++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final o = await repo.order(orderId);
      if (o.paymentStatus == 'paid') return true;
      if (o.isClosed) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (isWideLayout(context)) return _buildWide(context); // web shop on laptops & tablets
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
              Icon(Icons.verified_user_rounded, color: AppColors.brand700, size: 18),
              const SizedBox(width: 4),
              Text('100% Secure', style: text.labelSmall?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
      body: addresses.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
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
            loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
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
                clipBehavior: Clip.antiAlias,
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

  // ── web shop (laptops & tablets) ──────────────────────────────────────────

  Widget _buildWide(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final address = ref.watch(selectedAddressProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: addresses.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(addressesProvider)),
        data: (list) {
          if (list.isEmpty || address == null) {
            return ListView(children: [
              const SizedBox(height: 40),
              EmptyState(
                icon: Icons.add_location_alt_outlined,
                title: 'Add a delivery address',
                message: 'Drop a pin so we can calculate delivery from Jeya Hyper Store.',
                action: 'Add Address',
                onAction: () => context.push('/address'),
              ),
              const WebFooter(),
            ]);
          }
          final quote = ref.watch(_quoteProvider(address.id));
          return quote.when(
            loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(_quoteProvider(address.id))),
            data: (q) => _wideBody(context, list, address, q),
          );
        },
      ),
    );
  }

  Widget _wideBody(BuildContext context, List<Address> list, Address address, Quote q) {
    final text = Theme.of(context).textTheme;
    if (_method == null || (_method == 'online' && !q.onlineAvailable) || (_method == 'cod' && !q.codAvailable)) {
      _method = q.onlineAvailable ? 'online' : 'cod';
    }
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final free = q.freeDeliveryApplied || toPaise(q.deliveryFee) == 0;

    Widget section(int n, IconData icon, String title, Widget child) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.brand700, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text('$n. $title', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),
            child,
          ]),
        );

    final addressCards = LayoutBuilder(builder: (context, c) {
      const gap = 12.0;
      final cols = c.maxWidth >= 720 ? 3 : 2;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final a in list)
          SizedBox(
            width: w,
            child: InkWell(
              onTap: () => ref.read(selectedAddressIdProvider.notifier).state = a.id,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: a.id == address.id ? AppColors.brand50 : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: a.id == address.id ? AppColors.brand700 : AppColors.line, width: a.id == address.id ? 2 : 1),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(a.id == address.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: a.id == address.id ? AppColors.brand700 : AppColors.inkFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(a.title.toLowerCase() == 'work' ? Icons.business_rounded : Icons.home_rounded, size: 18, color: AppColors.ink),
                        const SizedBox(width: 6),
                        Text(a.title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 6),
                      Text(a.recipientName, style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      Text(a.oneLine, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                      Text(a.phone, style: text.bodySmall),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => context.push('/address?id=${a.id}'), child: const Text('Edit')),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        SizedBox(
          width: w,
          height: 150,
          child: OutlinedButton.icon(
            onPressed: () => context.push('/address'),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add new address'),
          ),
        ),
      ]);
    });

    final left = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final b in q.blockers)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.offerRedSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.offerRed),
            const SizedBox(width: 10),
            Expanded(child: Text(b.message)),
            if (b.reason == 'cart_needs_review') TextButton(onPressed: () => context.go('/cart'), child: const Text('Review')),
          ]),
        ),
      section(1, Icons.location_on_outlined, 'Delivery Address', addressCards),
      section(
        2,
        Icons.local_shipping_outlined,
        'Delivery',
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(Icons.check_circle_rounded, color: AppColors.brand700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  switch (q.expectedDeliveryBy) {
                    null => 'Home delivery',
                    final by when deliveryDay(by) == 'Today' => 'Delivery today',
                    final by => 'Delivery by ${deliveryDay(by) == 'Tomorrow' ? 'tomorrow' : deliveryDay(by)}',
                  },
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  [
                    if (q.expectedDeliveryBy != null) 'Expected ${deliveryPromise(q.expectedDeliveryBy!)}',
                    q.distanceKm != null ? '${q.distanceKm!.toStringAsFixed(1)} km from Jeya Hyper Store' : 'From Jeya Hyper Store, Trichy',
                  ].join(' · '),
                  style: text.bodySmall,
                ),
              ]),
            ),
            Text(free ? 'FREE' : formatRupees(q.deliveryFee), style: text.titleMedium?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
      section(
        3,
        Icons.payments_outlined,
        'Payment Method',
        Column(children: [
          if (q.onlineAvailable)
            _PayOption(
              value: 'online',
              group: _method!,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Pay Online',
              subtitle: 'UPI (GPay, PhonePe, Paytm), credit/debit cards, net banking, wallets',
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
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Delivery instructions (optional)', hintText: 'e.g. Ring the bell, leave with security', counterText: ''),
          ),
        ]),
      ),
    ]);

    final right = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.brand700),
          const SizedBox(width: 8),
          Text('Order Summary', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text('(${q.lines.length} items)', style: text.bodySmall),
          const Spacer(),
          TextButton(onPressed: () => context.go('/cart'), child: const Text('Edit cart')),
        ]),
        const SizedBox(height: 6),
        for (final l in q.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              ProductImage(url: l.product.imageUrl, placeholderUrl: l.product.placeholderImageUrl, name: l.product.name, size: 48, radius: 8),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                  Text('${formatQty(l.qtyMilli, l.product.unit)} × ${formatRupees(l.product.sellingPrice)}', style: text.labelSmall),
                  if (l.choices != null) Text(describeChoices(l.choices!, l.product.unit), style: text.labelSmall?.copyWith(color: AppColors.brand800)),
                ]),
              ),
              Text(formatRupees(l.lineTotal), style: text.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
        const Divider(height: 22),
        _BillRow('Item total', formatRupees(q.subtotal)),

        if (toPaise(q.discount) > 0) _BillRow('Premium discount (${q.memberLabel})', '− ${formatRupees(q.discount)}'),
        _BillRow('Delivery charge', free ? (q.memberFreeDelivery ? 'FREE (premium)' : 'FREE') : formatRupees(q.deliveryFee)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Total amount', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              Text(formatRupees(q.total), style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: AppColors.brand800)),
            ]),
            if (toPaise(q.savings) > 0) Text('You saved ${formatRupees(q.savings)} on this order!', style: text.labelLarge?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: q.canPlaceOrder && !_placing ? () => _place(address, q) : null,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          child: _placing
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text('Place Order — ${formatRupees(q.total)}', style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.inkMuted),
          const SizedBox(width: 6),
          Text('Secure and encrypted payment', style: text.labelSmall),
        ]),
      ]),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      children: [
        Text('Checkout', style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left),
            const SizedBox(width: 20),
            SizedBox(width: 400, child: right),
          ])
        else ...[
          left,
          right,
        ],
        const WebFooter(),
      ],
    );
  }

  Widget _body(BuildContext context, Address address, Quote q) {
    final text = Theme.of(context).textTheme;
    // The store can switch a payment option off (Admin → Payment options) while checkout is open.
    if (_method == null || (_method == 'online' && !q.onlineAvailable) || (_method == 'cod' && !q.codAvailable)) {
      _method = q.onlineAvailable ? 'online' : 'cod';
    }
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
              decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(address.title.toLowerCase() == 'work' ? Icons.business_rounded : Icons.home_rounded, color: AppColors.brand700),
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
            Icon(Icons.local_shipping_outlined, color: AppColors.brand700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  switch (q.expectedDeliveryBy) {
                    null => 'Home delivery',
                    final by when deliveryDay(by) == 'Today' => 'Delivery today',
                    final by => 'Delivery by ${deliveryDay(by) == 'Tomorrow' ? 'tomorrow' : deliveryDay(by)}',
                  },
                  style: text.titleSmall,
                ),
                Text(
                  [
                    if (q.expectedDeliveryBy != null) 'Expected ${deliveryPromise(q.expectedDeliveryBy!)}',
                    q.distanceKm != null ? '${q.distanceKm!.toStringAsFixed(1)} km from Jeya Hyper Store' : 'From Jeya Hyper Store, Trichy',
                  ].join(' · '),
                  style: text.bodySmall,
                ),
              ]),
            ),
            Text(q.freeDeliveryApplied || toPaise(q.deliveryFee) == 0 ? 'FREE' : formatRupees(q.deliveryFee),
                style: text.titleSmall?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w800)),
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
                  ProductImage(url: l.product.imageUrl, placeholderUrl: l.product.placeholderImageUrl, name: l.product.name, size: 44, radius: AppRadius.sm),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge),
                      Text('Qty ${formatQty(l.qtyMilli, l.product.unit)} × ${formatRupees(l.product.sellingPrice)}', style: text.labelSmall),
                      if (l.choices != null) Text(describeChoices(l.choices!, l.product.unit), style: text.labelSmall?.copyWith(color: AppColors.brand800)),
                    ]),
                  ),
                  Text(formatRupees(l.lineTotal), style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
            const Divider(height: 20),
            _BillRow('Item total', formatRupees(q.subtotal)),

            if (toPaise(q.discount) > 0) _BillRow('Premium discount (${q.memberLabel})', '− ${formatRupees(q.discount)}'),
            _BillRow('Delivery charge', q.freeDeliveryApplied || toPaise(q.deliveryFee) == 0 ? (q.memberFreeDelivery ? 'FREE (premium)' : 'FREE') : formatRupees(q.deliveryFee)),
            const Divider(height: 18),
            _BillRow('Total amount', formatRupees(q.total), bold: true),
            if (toPaise(q.savings) > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Text('You save ${formatRupees(q.savings)}', style: text.labelMedium?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w700)),
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
          backgroundColor: done || active ? AppColors.brand700 : AppColors.line,
          child: done
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : Text('${i + 1}', style: text.labelSmall?.copyWith(color: active ? Colors.white : AppColors.inkMuted, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 4),
        Text(label, style: text.labelSmall?.copyWith(color: active || done ? AppColors.ink : AppColors.inkFaint, fontWeight: FontWeight.w600)),
      ]);
    }

    Widget bar(bool on) => Expanded(child: Container(height: 2, margin: const EdgeInsets.only(bottom: 16), color: on ? AppColors.brand700 : AppColors.line));
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
          color: selected ? AppColors.brand50 : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: selected ? AppColors.brand700 : AppColors.line, width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? AppColors.brand700 : AppColors.inkFaint),
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
                    decoration: BoxDecoration(color: AppColors.brand700, borderRadius: BorderRadius.circular(10)),
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
              color: value == 'FREE' ? AppColors.brand700 : null,
            )),
      ]),
    );
  }
}
