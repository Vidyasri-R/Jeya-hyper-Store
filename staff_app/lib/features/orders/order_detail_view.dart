import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Full-screen route on phones (`/order/:id`).
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) => OrderDetailView(orderId: orderId, embedded: false);
}

/// Everything needed to pack and deliver one order, with its next step as one big button.
class OrderDetailView extends ConsumerStatefulWidget {
  const OrderDetailView({super.key, required this.orderId, required this.embedded});
  final String orderId;
  final bool embedded;

  @override
  ConsumerState<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends ConsumerState<OrderDetailView> {
  OrderDetail? _order;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final order = await ref.read(repositoryProvider).order(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  /// Runs a status change; on "someone else already moved it" reloads instead of failing.
  Future<void> _run(Future<OrderDetail> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _order = updated);
      if (done != null) showSnack(context, done);
      ref.read(boardProvider.notifier).refresh();
      ref.invalidate(orderListRefreshProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      showSnack(context, e.friendly, error: true);
      if (e.reason == 'order_changed') await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onNext(OrderDetail order, NextAction next) async {
    final repo = ref.read(repositoryProvider);
    switch (next.to) {
      case 'ready_for_delivery':
        final packed = await _askPacked(context, order);
        if (packed == null) return;
        await _run(
          () => repo.advance(order.id, from: order.status, to: next.to, packedItems: packed),
          done: 'Marked packed',
        );
      case 'delivered':
        if (order.isCod) {
          final cash = await _askCash(context, order);
          if (cash == null) return;
          await _run(
            () => repo.advance(order.id, from: order.status, to: next.to, codCollectedAmount: cash.$1, note: cash.$2),
            done: 'Delivered — cash recorded',
          );
        } else {
          final ok = await _confirm(context, 'Mark as delivered?', 'Order #${order.orderNumber.split('-').last} was handed to ${order.recipientName}.');
          if (ok) {
            await _run(
              () => repo.advance(order.id, from: order.status, to: next.to),
              done: 'Delivered',
            );
          }
        }
      default:
        await _run(
          () => repo.advance(order.id, from: order.status, to: next.to),
          done: StatusStyle.label(next.to),
        );
    }
  }

  Future<void> _onCancel(OrderDetail order) async {
    final reason = await _askCancelReason(context, order);
    if (reason == null) return;
    await _run(
      () => ref.read(repositoryProvider).cancel(order.id, from: order.status, reason: reason),
      done: 'Order cancelled',
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final body = order == null
        ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
        : RefreshIndicator(onRefresh: _load, child: _content(context, order));

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(order == null ? 'Order' : 'Order #${order.orderNumber.split('-').last}'),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: body,
      bottomNavigationBar: order == null ? null : _actionBar(order),
    );
  }

  Widget? _actionBar(OrderDetail order) {
    final next = order.next;
    if (next == null && !order.canCancel) return null;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            if (order.canCancel)
              TextButton(
                onPressed: _busy ? null : () => _onCancel(order),
                style: TextButton.styleFrom(foregroundColor: AppColors.offerRed),
                child: const Text('Cancel order'),
              ),
            if (next != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _onNext(order, next),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : Icon(_iconFor(next.to)),
                  label: Text(next.label),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String to) => switch (to) {
    'packing' || 'confirmed' => Icons.inventory_2_outlined,
    'ready_for_delivery' => Icons.check_circle_outline_rounded,
    'out_for_delivery' => Icons.delivery_dining_rounded,
    'delivered' => Icons.home_rounded,
    _ => Icons.arrow_forward_rounded,
  };

  Widget _content(BuildContext context, OrderDetail order) {
    final text = Theme.of(context).textTheme;
    final itemsTotal = order.items.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.orderNumber, style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text('Placed ${dayTime(order.placedAt ?? order.createdAt)}', style: text.bodySmall),
                ],
              ),
            ),
            StatusChip(order.status),
          ],
        ),
        if (widget.embedded) ...[
          const SizedBox(height: 12),
          if (_actionBar(order) case final bar?) ClipRRect(borderRadius: BorderRadius.circular(AppRadius.lg), child: bar),
        ],
        if (order.cancelledReason != null) ...[
          const SizedBox(height: 12),
          SectionCard(
            color: AppColors.offerRedSoft,
            child: Text(order.cancelledReason!, style: text.bodyMedium?.copyWith(color: AppColors.offerRed)),
          ),
        ],
        const SizedBox(height: 14),
        _customerCard(context, order),
        const SizedBox(height: 12),
        _paymentCard(context, order),
        const SizedBox(height: 18),
        Text('$itemsTotal item${itemsTotal == 1 ? '' : 's'}', style: text.titleMedium),
        const SizedBox(height: 8),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, item) in order.items.indexed) ...[if (index > 0) const Divider(height: 1), _ItemRow(item: item)],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _totals(context, order),
        const SizedBox(height: 18),
        Text('Timeline', style: text.titleMedium),
        const SizedBox(height: 8),
        SectionCard(
          child: Column(
            children: [
              for (final entry in order.history.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.circle, size: 10, color: StatusStyle.colors(entry.status).$1),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${StatusStyle.label(entry.status)} · ${entry.by}', style: text.titleSmall),
                            if (entry.note != null) Text(entry.note!, style: text.bodySmall),
                          ],
                        ),
                      ),
                      Text(ago(entry.at), style: text.labelSmall),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _customerCard(BuildContext context, OrderDetail order) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_rounded, color: AppColors.green700),
              const SizedBox(width: 8),
              Expanded(child: Text(order.recipientName, style: text.titleMedium)),
              if (order.phone.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:+${order.phone}')),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: Text(_formatPhone(order.phone)),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.inkMuted, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(order.addressText, style: text.bodyMedium)),
            ],
          ),
          if (order.mapsUrl != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(order.mapsUrl!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Open in Maps'),
              ),
            ),
          ],
          if (order.customerNote != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.brandBlueSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Text(
                'Note: ${order.customerNote}',
                style: text.bodyMedium?.copyWith(color: AppColors.brandBlue, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentCard(BuildContext context, OrderDetail order) {
    final text = Theme.of(context).textTheme;
    final collect = toPaise(order.amountToCollect);
    final (title, subtitle, fg, bg) = switch (order) {
      OrderDetail(status: 'cancelled' || 'payment_failed', paymentStatus: 'pending' || 'failed') => (
        'Nothing to collect',
        order.isCod ? 'Order cancelled' : 'Order cancelled — no money was taken',
        AppColors.inkMuted,
        AppColors.line,
      ),
      OrderDetail(isCod: true, codCollected: final String collected) => (
        'Cash collected ${formatRupees(collected)}',
        'Cash on delivery',
        AppColors.green700,
        AppColors.green50,
      ),
      OrderDetail(isCod: true) when collect > 0 => (
        'Collect ${formatRupees(order.amountToCollect)} in cash',
        'Cash on delivery',
        const Color(0xFF8A5A00),
        AppColors.amberSoft,
      ),
      OrderDetail(paymentStatus: 'paid') => ('Paid online — collect nothing', 'Prepaid', AppColors.green700, AppColors.green50),
      OrderDetail(paymentStatus: 'refunded') => ('Refunded', 'Online payment returned to the customer', AppColors.offerRed, AppColors.offerRedSoft),
      OrderDetail(paymentStatus: 'partially_refunded') => (
        'Paid online — partly refunded',
        'Difference for short-packed items returned',
        AppColors.green700,
        AppColors.green50,
      ),
      _ => ('Payment ${order.paymentStatus.replaceAll('_', ' ')}', order.isCod ? 'Cash on delivery' : 'Online', AppColors.inkMuted, AppColors.line),
    };
    return SectionCard(
      color: bg,
      child: Row(
        children: [
          Icon(order.isCod ? Icons.payments_rounded : Icons.verified_rounded, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(color: fg)),
                Text(subtitle, style: text.bodySmall),
                for (final refund in order.refunds) Text('Refund ${formatRupees(refund['amount'].toString())} · ${refund['status']}', style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totals(BuildContext context, OrderDetail order) {
    final text = Theme.of(context).textTheme;
    Widget row(String label, String value, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style ?? text.bodyMedium)),
          Text(value, style: style ?? text.bodyMedium),
        ],
      ),
    );
    return SectionCard(
      child: Column(
        children: [
          row('Items', formatRupees(order.subtotal)),
          row('Delivery', toPaise(order.deliveryFee) == 0 ? 'Free' : formatRupees(order.deliveryFee)),
          row(
            'Order total',
            formatRupees(order.totalAmount),
            style: order.finalAmount != null ? text.bodyMedium?.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.inkMuted) : text.titleMedium,
          ),
          if (order.finalAmount != null) row('Final (as packed)', formatRupees(order.finalAmount!), style: text.titleMedium),
        ],
      ),
    );
  }
}

String _formatPhone(String phone) {
  final digits = phone.startsWith('91') && phone.length == 12 ? phone.substring(2) : phone;
  return digits.length == 10 ? '${digits.substring(0, 5)} ${digits.substring(5)}' : digits;
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ordered = formatQty(item.quantityMilli, item.unit);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductThumb(url: item.imageUrl, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  [if (item.packSize != null) item.packSize!, 'Code ${item.itemCode}', if (item.barcode != null) item.barcode!].join(' · '),
                  style: text.bodySmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.green50, borderRadius: BorderRadius.circular(6)),
                      child: Text('× $ordered', style: text.titleSmall?.copyWith(color: AppColors.green800)),
                    ),
                    if (item.packedShort)
                      Pill('Packed ${formatQty(toMilli(item.packedQuantity!), item.unit)}', fg: const Color(0xFF8A5A00), bg: AppColors.amberSoft),
                    if (item.isLoose) const Pill('Weigh', icon: Icons.scale_outlined),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.packedShort) ...[
                // Packed less than ordered: what the customer now pays for this line.
                Text(formatRupees(item.totalPrice), style: text.labelSmall?.copyWith(decoration: TextDecoration.lineThrough)),
                Text(formatPaise((toPaise(item.unitPrice) * toMilli(item.packedQuantity!) / 1000).round()), style: text.titleSmall),
              ] else
                Text(formatRupees(item.totalPrice), style: text.titleSmall),
              Text('${formatRupees(item.unitPrice)}${item.isLoose ? '/${item.unit}' : ' each'}', style: text.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────── sheets ───────────── */

Future<bool> _confirm(BuildContext context, String title, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
        ],
      ),
    ) ??
    false;

/// Returns the items packed LESS than ordered ([] = everything packed in full), or null if dismissed.
Future<List<Map<String, dynamic>>?> _askPacked(BuildContext context, OrderDetail order) {
  final packed = {for (final item in order.items) item.productId: item.quantityMilli};
  String? error;
  return showActionSheet<List<Map<String, dynamic>>>(
    context,
    title: 'Pack order #${order.orderNumber.split('-').last}',
    fields: {for (final item in order.items.where((i) => i.isLoose)) 'p${item.productId}': milliToString(item.quantityMilli)},
    builder: (context, setState, fields) {
      final text = Theme.of(context).textTheme;
      var totalPaise = toPaise(order.deliveryFee);
      for (final item in order.items) {
        final milli = packed[item.productId]!;
        totalPaise += milli == item.quantityMilli ? toPaise(item.totalPrice) : (toPaise(item.unitPrice) * milli / 1000).round();
      }
      final short = order.items.where((item) => packed[item.productId]! < item.quantityMilli).length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Everything is marked as packed in full. Change only what is short — for loose items enter the weighed amount.', style: text.bodySmall),
          const SizedBox(height: 12),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  ProductThumb(url: item.imageUrl, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        Text('Ordered ${formatQty(item.quantityMilli, item.unit)}', style: text.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.isLoose)
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: fields['p${item.productId}'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,5}(\.\d{0,3})?'))],
                        decoration: InputDecoration(
                          suffixText: item.unit,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        onChanged: (value) {
                          final milli = _parseMilli(value);
                          setState(() {
                            packed[item.productId] = milli.clamp(0, item.quantityMilli);
                            error = milli > item.quantityMilli ? "Can't pack more than ordered (${formatQty(item.quantityMilli, item.unit)})" : null;
                          });
                        },
                      ),
                    )
                  else
                    _Stepper(
                      value: packed[item.productId]! ~/ 1000,
                      max: item.quantityMilli ~/ 1000,
                      onChanged: (v) => setState(() => packed[item.productId] = v * 1000),
                    ),
                ],
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(error!, style: text.bodySmall?.copyWith(color: AppColors.offerRed)),
            ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(child: Text(short == 0 ? 'All items packed' : '$short item${short == 1 ? '' : 's'} short', style: text.titleSmall)),
              Text('Total ${formatPaise(totalPaise)}', style: text.titleMedium),
            ],
          ),
          if (short > 0 && !order.isCod) Text('The difference is refunded to the customer automatically when delivered.', style: text.bodySmall),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: error != null || packed.values.every((v) => v == 0)
                ? null
                : () => Navigator.pop(context, [
                    for (final item in order.items)
                      if (packed[item.productId]! < item.quantityMilli) {'productId': item.productId, 'packedQuantity': milliToString(packed[item.productId]!)},
                  ]),
            child: Text(short == 0 ? 'Mark packed' : 'Mark packed with changes'),
          ),
        ],
      );
    },
  );
}

/// Lenient while typing: "", ".", "0." and "1.2" are all fine.
int _parseMilli(String value) {
  final cleaned = value.startsWith('.') ? '0$value' : value;
  final normalized = cleaned.endsWith('.') ? '${cleaned}0' : cleaned;
  try {
    return normalized.isEmpty ? 0 : toMilli(normalized);
  } on FormatException {
    return 0;
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.max, required this.onChanged});
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(visualDensity: VisualDensity.compact, onPressed: value > 0 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_rounded)),
        SizedBox(
          width: 44,
          child: Text('$value/$max', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
        ),
        IconButton(visualDensity: VisualDensity.compact, onPressed: value < max ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_rounded)),
      ],
    ),
  );
}

/// Returns (amount collected, note) or null if dismissed.
Future<(String, String?)?> _askCash(BuildContext context, OrderDetail order) {
  var different = false;
  String? error;
  return showActionSheet<(String, String?)>(
    context,
    title: 'Collect cash',
    fields: {'amount': order.amountToCollect, 'note': ''},
    builder: (context, setState, fields) {
      final text = Theme.of(context).textTheme;
      final amount = fields['amount']!;
      final note = fields['note']!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            color: AppColors.amberSoft,
            child: Column(
              children: [
                Text('Amount to collect', style: text.bodySmall),
                Text(formatRupees(order.amountToCollect), style: text.headlineMedium?.copyWith(color: const Color(0xFF8A5A00))),
                Text('from ${order.recipientName}', style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: different,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => different = v ?? false),
            title: const Text('Collected a different amount'),
          ),
          if (different) ...[
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?'))],
              decoration: const InputDecoration(labelText: 'Cash collected', prefixText: '₹ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Why is it different?', hintText: 'e.g. customer returned 1 item'),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(error!, style: text.bodySmall?.copyWith(color: AppColors.offerRed)),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            onPressed: () {
              if (!different) return Navigator.pop(context, (order.amountToCollect, null));
              final value = amount.text.trim();
              if (value.isEmpty || value.endsWith('.')) return setState(() => error = 'Enter the amount collected');
              if (note.text.trim().length < 2) return setState(() => error = 'Add a short note explaining the difference');
              Navigator.pop(context, (value, note.text.trim()));
            },
            label: Text(different ? 'Delivered — cash recorded' : 'Collected ${formatRupees(order.amountToCollect)} · Delivered'),
          ),
        ],
      );
    },
  );
}

Future<String?> _askCancelReason(BuildContext context, OrderDetail order) {
  const reasons = ['Items out of stock', 'Customer asked to cancel', 'Could not reach the customer', 'Address too far / not serviceable'];
  String? picked;
  return showActionSheet<String>(
    context,
    title: 'Cancel order #${order.orderNumber.split('-').last}?',
    fields: const {'other': ''},
    builder: (context, setState, fields) {
      final text = Theme.of(context).textTheme;
      final other = fields['other']!;
      final reason = picked == 'Other' ? other.text.trim() : picked;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            order.paymentStatus == 'paid'
                ? 'The customer paid online — they will be refunded in full automatically.'
                : 'The customer sees the reason in their app.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in [...reasons, 'Other']) ChoiceChip(label: Text(r), selected: picked == r, onSelected: (_) => setState(() => picked = r)),
            ],
          ),
          if (picked == 'Other') ...[
            const SizedBox(height: 12),
            TextField(
              controller: other,
              autofocus: true,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.offerRed),
            onPressed: reason == null || reason.length < 3 ? null : () => Navigator.pop(context, reason),
            child: const Text('Cancel order'),
          ),
        ],
      );
    },
  );
}
