import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../checkout/razorpay_payment.dart';
import 'orders_screen.dart';

final orderDetailProvider = FutureProvider.autoDispose.family<Order, String>(
  (ref, id) => ref.watch(repositoryProvider).order(id),
);

/// Amazon-style tracking: Ordered → Packed → Out for delivery → Delivered.
const _milestones = [
  ('Ordered', ['placed', 'confirmed']),
  ('Packed', ['packing', 'ready_for_delivery']),
  ('Out for delivery', ['out_for_delivery']),
  ('Delivered', ['delivered']),
];

/// How often an open order page checks for the store's changes (status, packed quantities).
const _liveRefresh = Duration(seconds: 20);

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  String get orderId => widget.orderId;

  @override
  void initState() {
    super.initState();
    // Staff move the order along in the store app: follow it live while the page is open.
    _timer = Timer.periodic(_liveRefresh, (_) => _refreshIfOpen());
    _lifecycle = AppLifecycleListener(onResume: _refreshIfOpen);
  }

  void _refreshIfOpen() {
    final current = ref.read(orderDetailProvider(orderId)).valueOrNull;
    if (current == null || !current.isClosed) ref.invalidate(orderDetailProvider(orderId));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderDetailProvider(orderId));
    // Reached via the success screen (context.go) there is nothing to pop: Android back
    // would close the app, so send the user to the orders list instead.
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/orders');
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Order Details'),
          // Arriving from the success screen leaves nothing to pop — go to the orders list instead.
          leading: context.canPop()
              ? const BackButton()
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/orders'),
                ),
        ),
        body: order.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: AppColors.brand700),
          ),
          error: (e, _) => ErrorRetry(
            error: e,
            onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
          ),
          data: (o) => RefreshIndicator(
            color: AppColors.brand700,
            onRefresh: () async => ref.invalidate(orderDetailProvider(orderId)),
            child: _Body(order: o),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.order});
  final Order order;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _payment = RazorpayPayment();
  bool _paying = false;

  Order get order => widget.order;

  @override
  void dispose() {
    _payment.dispose();
    super.dispose();
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// Pay for an order still waiting for payment (the customer left the payment page).
  Future<void> _payNow() async {
    setState(() => _paying = true);
    final repo = ref.read(repositoryProvider);
    try {
      final init = await repo.startPayment(order.id);
      final auth = ref.read(authProvider);
      final outcome = await _payment.open(init, email: auth is SignedIn ? auth.user.email : null);
      if (!mounted) return;
      if (outcome is PaymentSucceeded) {
        await repo.confirmPayment(order.id, razorpayOrderId: outcome.orderId, paymentId: outcome.paymentId, signature: outcome.signature);
        if (!mounted) return;
        _snack('Payment received — thank you!');
      } else {
        _snack((outcome as PaymentFailed).message);
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _paying = false);
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersListProvider);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          order.paymentStatus == 'paid'
              ? 'Your payment will be refunded to the original payment method.'
              : order.awaitingPayment
              ? 'Nothing has been paid. Your items go back to your cart.'
              : 'Your order will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            clipBehavior: Clip.antiAlias,
            style: FilledButton.styleFrom(backgroundColor: AppColors.offerRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(repositoryProvider);
      await repo.cancelOrder(order.id);
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersListProvider);
      // Unpaid: the customer only stepped away from payment — give them their cart back.
      if (order.awaitingPayment) {
        try {
          await repo.mergeCart(order.items);
        } on ApiException {
          // Cart restore is a convenience; the cancel itself worked.
        }
        ref.invalidate(cartProvider);
        if (context.mounted) {
          _snack('Order cancelled — your items are back in the cart');
          context.go('/cart');
        }
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (bg, fg) = statusColors(order.status);
    final a = order.address;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          order.orderNumber,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: order.orderNumber),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Order number copied'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: text.labelMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Placed on ${DateFormat('d MMM yyyy, h:mm a').format(order.createdAt)}',
                style: text.bodySmall,
              ),
              if (order.status == 'delivered' && order.deliveredAt != null) ...[
                const SizedBox(height: 10),
                _DeliveryLine(icon: Icons.home_rounded, text: 'Delivered on ${DateFormat('EEE d MMM, h:mm a').format(order.deliveredAt!)}'),
              ] else if (!order.isClosed && !order.awaitingPayment && order.expectedDeliveryBy != null) ...[
                const SizedBox(height: 10),
                _DeliveryLine(icon: Icons.local_shipping_outlined, text: 'Expected delivery: ${deliveryPromise(order.expectedDeliveryBy!)}'),
              ],
              const SizedBox(height: 16),
              if (order.status == 'cancelled' ||
                  order.status == 'payment_failed')
                _ClosedBanner(order: order)
              else if (order.awaitingPayment)
                _PendingPaymentBanner(order: order, paying: _paying, onPay: _payNow)
              else
                _Timeline(order: order),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Items (${order.items.length})', style: text.titleSmall),
              const SizedBox(height: 6),
              for (final i in order.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.name, style: text.labelLarge),
                            Text(
                              '${formatQty(i.orderedMilli, i.unit)} × ${formatRupees(i.unitPrice)}',
                              style: text.labelSmall,
                            ),
                            if (i.choices != null) Text(describeChoices(i.choices!, i.unit), style: text.labelSmall),
                            if (i.isShort)
                              Text(
                                i.packedMilli == 0
                                    ? 'Not available — not charged'
                                    : 'Packed ${formatQty(i.packedMilli!, i.unit)} of ${formatQty(i.orderedMilli, i.unit)} — you pay only for what\u2019s packed',
                                style: text.labelSmall?.copyWith(color: AppColors.offerRed, fontWeight: FontWeight.w700),
                              ),
                          ],
                        ),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        if (i.isShort)
                          Text(
                            formatRupees(i.totalPrice),
                            style: text.labelSmall?.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.inkFaint),
                          ),
                        Text(
                          formatPaise(i.chargedPaise),
                          style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ]),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bill Details', style: text.titleSmall),
              const SizedBox(height: 6),
              _Row('Item total', formatRupees(order.subtotal)),
              _Row(
                'Delivery charge',
                toPaise(order.deliveryFee) == 0
                    ? 'FREE'
                    : formatRupees(order.deliveryFee),
              ),
              const Divider(height: 18),
              if (order.totalChanged) ...[
                _Row('Order total', formatRupees(order.totalAmount)),
                _Row('Items not available', '\u2212${formatPaise(toPaise(order.totalAmount) - toPaise(order.finalAmount!))}'),
              ],
              _Row(
                order.paymentStatus == 'paid' || order.status == 'delivered'
                    ? (order.isCod ? 'Paid on delivery' : 'Total paid')
                    : (order.isCod ? (order.totalChanged ? 'Final amount to pay on delivery' : 'To pay on delivery') : 'Total'),
                formatRupees(order.isCod ? order.payableAmount : order.totalAmount),
                bold: true,
              ),
              if (order.totalChanged && !order.isCod && order.paymentStatus != 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${formatPaise(toPaise(order.totalAmount) - toPaise(order.finalAmount!))} for items not available is refunded to your payment method.',
                    style: text.labelSmall?.copyWith(color: AppColors.brand800),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                order.isCod
                    ? 'Cash on delivery'
                    : 'Online payment · ${order.paymentStatus == 'refunded'
                          ? 'Refunded'
                          : order.paymentStatus == 'paid'
                          ? 'Payment received'
                          : 'Not paid yet'}',
                style: text.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Delivery Address', style: text.titleSmall),
              const SizedBox(height: 6),
              Text(
                '${a['recipientName'] ?? ''} · ${_formatPhone('${a['phone'] ?? ''}')}',
                style: text.labelLarge,
              ),
              Text(
                [
                  a['line1'],
                  a['line2'],
                  a['landmark'],
                  '${a['city'] ?? ''} – ${a['pincode'] ?? ''}',
                ].whereType<String>().where((s) => s.isNotEmpty).join(', '),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (order.canCancel)
          OutlinedButton(
            onPressed: () => _cancel(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.offerRed,
              side: const BorderSide(color: AppColors.offerRed),
            ),
            child: const Text('Cancel Order'),
          ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => context.push('/help'),
          icon: const Icon(Icons.support_agent_rounded),
          label: const Text('Need help with this order?'),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reached = _milestones.lastIndexWhere(
      (m) => m.$2.contains(order.status),
    );
    DateTime? timeFor(List<String> statuses) {
      for (final e in order.history.reversed) {
        if (statuses.contains(e.status)) return e.at;
      }
      return null;
    }

    return Column(
      children: [
        for (var i = 0; i < _milestones.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: i <= reached
                        ? AppColors.brand700
                        : AppColors.line,
                    child: Icon(
                      i <= reached ? Icons.check_rounded : Icons.circle,
                      size: i <= reached ? 15 : 7,
                      color: i <= reached ? Colors.white : AppColors.inkFaint,
                    ),
                  ),
                  if (i < _milestones.length - 1)
                    Container(
                      width: 2,
                      height: 30,
                      color: i < reached ? AppColors.brand700 : AppColors.line,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _milestones[i].$1,
                        style: text.titleSmall?.copyWith(
                          color: i <= reached
                              ? AppColors.ink
                              : AppColors.inkFaint,
                          fontWeight: i == reached
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      if (timeFor(_milestones[i].$2) case final t?)
                        Text(
                          DateFormat('d MMM, h:mm a').format(t),
                          style: text.labelSmall,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.order});
  final Order order;
  @override
  Widget build(BuildContext context) {
    final refunded = order.paymentStatus == 'refunded';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.offerRedSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.offerRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              order.status == 'payment_failed'
                  ? 'Payment was not completed, so this order was cancelled.'
                  : refunded
                  ? 'This order was cancelled. Your refund has been initiated (3–5 working days).'
                  : 'This order was cancelled.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPaymentBanner extends StatelessWidget {
  const _PendingPaymentBanner({required this.order, required this.paying, required this.onPay});
  final Order order;
  final bool paying;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final left = order.reservationExpiresAt?.difference(DateTime.now());
    final minutes = left == null ? null : (left.inSeconds / 60).ceil().clamp(0, 99);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFF9A6100)),
          const SizedBox(width: 10),
          Expanded(child: Text('Payment not completed', style: text.titleSmall)),
        ]),
        const SizedBox(height: 6),
        Text(
          [
            'This order is not confirmed until you pay.',
            if (minutes != null && minutes > 0) 'Pay within $minutes min or it is cancelled automatically.',
            'If money was already debited, this updates by itself within a few minutes.',
          ].join(' '),
          style: text.bodySmall,
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: paying ? null : onPay,
          icon: paying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_rounded, size: 18),
          label: Text('Pay ${formatRupees(order.totalAmount)} now'),
        ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.line),
    ),
    child: child,
  );
}

class _Row extends StatelessWidget {
  const _Row(this.a, this.b, {this.bold = false});
  final String a;
  final String b;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              a,
              style: bold
                  ? text.titleSmall
                  : text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ),
          Text(
            b,
            style: (bold ? text.titleMedium : text.bodyMedium)?.copyWith(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: b == 'FREE' ? AppColors.brand700 : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// "919876543210" → "+91 98765 43210"
String _formatPhone(String phone) =>
    phone.length == 12 && phone.startsWith('91')
    ? '+91 ${phone.substring(2, 7)} ${phone.substring(7)}'
    : phone;

class _DeliveryLine extends StatelessWidget {
  const _DeliveryLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(AppRadius.md)),
        child: Row(children: [
          Icon(icon, color: AppColors.brand700, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.brand800))),
        ]),
      );
}

