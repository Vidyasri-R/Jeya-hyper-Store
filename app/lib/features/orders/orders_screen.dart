import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

final ordersListProvider = FutureProvider.autoDispose<List<Order>>((ref) async => (await ref.watch(repositoryProvider).orders()).orders);

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green700)),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(ordersListProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No orders yet',
                message: 'Your orders from Jeya Hyper Store will appear here.',
                action: 'Start Shopping',
                onAction: () => context.go('/home'),
              )
            : RefreshIndicator(
                color: AppColors.green700,
                onRefresh: () async => ref.invalidate(ordersListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => OrderCard(order: list[i]),
                ),
              ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (bg, fg) = statusColors(order.status);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/order/${order.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: const Icon(Icons.shopping_bag_outlined, color: AppColors.green700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.orderNumber, style: text.titleSmall),
                Text('${DateFormat('d MMM, h:mm a').format(order.createdAt)} · ${order.itemCount} item${order.itemCount == 1 ? '' : 's'}', style: text.bodySmall),
                const SizedBox(height: 6),
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                    child: Text(order.statusLabel, style: text.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                  ),
                  if (!order.isClosed && !order.awaitingPayment && order.expectedDeliveryBy != null)
                    Text(
                      deliveryDay(order.expectedDeliveryBy!) == 'Today' ? 'Arriving today' : 'Arriving ${deliveryDay(order.expectedDeliveryBy!) == 'Tomorrow' ? 'tomorrow' : deliveryDay(order.expectedDeliveryBy!)}',
                      style: text.labelSmall?.copyWith(color: AppColors.green800, fontWeight: FontWeight.w700),
                    ),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatRupees(order.totalAmount), style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ]),
          ]),
        ),
      ),
    );
  }
}

(Color, Color) statusColors(String status) => switch (status) {
      'delivered' => (AppColors.green100, AppColors.green800),
      'cancelled' || 'payment_failed' => (AppColors.offerRedSoft, AppColors.offerRed),
      'pending_payment' => (AppColors.amberSoft, const Color(0xFF9A6100)),
      _ => (AppColors.brandBlueSoft, AppColors.brandBlue),
    };
