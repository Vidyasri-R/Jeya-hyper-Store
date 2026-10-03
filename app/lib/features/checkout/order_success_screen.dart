import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

final _orderProvider = FutureProvider.autoDispose.family((ref, String id) => ref.watch(repositoryProvider).order(id));

class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(_orderProvider(orderId)).valueOrNull;
    final text = Theme.of(context).textTheme;
    final paidPending = order?.awaitingPayment == true;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(color: AppColors.brand50, shape: BoxShape.circle),
                child: Icon(paidPending ? Icons.hourglass_top_rounded : Icons.check_circle_rounded, size: 72, color: AppColors.brand700),
              ),
              const SizedBox(height: 22),
              Text(paidPending ? 'Confirming your payment…' : 'Order placed!', style: text.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              if (order != null) ...[
                Text('Order ${order.orderNumber}', style: text.titleSmall?.copyWith(color: AppColors.inkMuted)),
                const SizedBox(height: 4),
                Text(
                  order.isCod ? 'Pay ${formatRupees(order.totalAmount)} when it arrives' : 'Paid ${formatRupees(order.totalAmount)} online',
                  style: text.bodyMedium,
                ),
                if (order.expectedDeliveryBy != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_shipping_outlined, color: AppColors.brand700, size: 20),
                      const SizedBox(width: 8),
                      Text('Expected delivery: ${deliveryPromise(order.expectedDeliveryBy!)}',
                          style: text.titleSmall?.copyWith(color: AppColors.brand800)),
                    ]),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Text('We’re packing your order at Jeya Hyper Store. You’ll get updates as it moves.',
                  textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
              const Spacer(),
              FilledButton(clipBehavior: Clip.antiAlias, onPressed: () => context.go('/order/$orderId'), child: const Text('Track Order')),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => context.go('/home'), child: const Text('Continue Shopping')),
            ]),
          ),
        ),
      ),
    );
  }
}
