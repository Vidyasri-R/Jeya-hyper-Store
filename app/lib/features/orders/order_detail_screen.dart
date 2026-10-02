import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
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

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.green700),
          ),
          error: (e, _) => ErrorRetry(
            error: e,
            onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
          ),
          data: (o) => RefreshIndicator(
            color: AppColors.green700,
            onRefresh: () async => ref.invalidate(orderDetailProvider(orderId)),
            child: _Body(order: o),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.order});
  final Order order;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          order.paymentStatus == 'paid'
              ? 'Your payment will be refunded to the original payment method.'
              : 'Your order will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.offerRed),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(repositoryProvider).cancelOrder(order.id);
      ref.invalidate(orderDetailProvider(order.id));
      ref.invalidate(ordersListProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              const SizedBox(height: 16),
              if (order.status == 'cancelled' ||
                  order.status == 'payment_failed')
                _ClosedBanner(order: order)
              else if (order.awaitingPayment)
                const _PendingPaymentBanner()
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
                              '${formatQty(toMilli(i.quantity), i.unit)} × ${formatRupees(i.unitPrice)}',
                              style: text.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatRupees(i.totalPrice),
                        style: text.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
              _Row(
                order.paymentStatus == 'paid' || order.status == 'delivered'
                    ? (order.isCod ? 'Paid on delivery' : 'Total paid')
                    : (order.isCod ? 'To pay on delivery' : 'Total'),
                formatRupees(order.totalAmount),
                bold: true,
              ),
              const SizedBox(height: 4),
              Text(
                order.isCod
                    ? 'Cash on delivery'
                    : 'Paid online · ${order.paymentStatus == 'refunded'
                          ? 'Refunded'
                          : order.paymentStatus == 'paid'
                          ? 'Payment received'
                          : 'Awaiting payment'}',
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
                        ? AppColors.green700
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
                      color: i < reached ? AppColors.green700 : AppColors.line,
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
  const _PendingPaymentBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.amberSoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: const Row(
      children: [
        Icon(Icons.hourglass_top_rounded, color: Color(0xFF9A6100)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Waiting for payment. If money was debited, this updates automatically within a few minutes.',
          ),
        ),
      ],
    ),
  );
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
              color: b == 'FREE' ? AppColors.green700 : null,
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
