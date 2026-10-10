import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → "Same product, new code?": the store gives a product a new JHS code when its packaging
/// (EAN) changes. Pairs that look like one product wait here; "Same" moves the photo and details to
/// the new code, and the old one leaves the shop when its stock runs out.
class NewCodesScreen extends ConsumerStatefulWidget {
  const NewCodesScreen({super.key});

  @override
  ConsumerState<NewCodesScreen> createState() => _NewCodesScreenState();
}

class _NewCodesScreenState extends ConsumerState<NewCodesScreen> {
  List<({AdminProduct old, AdminProduct neu})>? _pairs;
  int _total = 0;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await ref.read(repositoryProvider).newCodes();
      if (!mounted) return;
      setState(() {
        _pairs = r.pairs;
        _total = r.total;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _decide(({AdminProduct old, AdminProduct neu}) pair, {required bool same}) async {
    setState(() => _busy.add(pair.neu.id));
    final copied = await guard(context, () => ref.read(repositoryProvider).decideNewCode(pair.old.id, pair.neu.id, same: same));
    if (!mounted) return;
    setState(() => _busy.remove(pair.neu.id));
    if (copied == null) return;
    showSnack(
      context,
      !same
          ? 'Kept as two products'
          : copied
          ? 'Linked — photo copied to ${pair.neu.itemCode} (helpers check it matches the new pack)'
          : 'Linked — ${pair.old.itemCode} leaves the shop when its stock runs out',
    );
    setState(() {
      _pairs = [for (final p in _pairs!) if (p.neu.id != pair.neu.id || p.old.id != pair.old.id) p];
      _total = (_total - 1).clamp(0, 1 << 30);
    });
    if (_pairs!.isEmpty && _total > 0) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pairs = _pairs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Same product, new code?'),
        actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          Text(
            'When a pack changes, GoFrugal often gets a new JHS code. These look like the same product: same brand, size and name, '
            'a believable price. "Same product" gives the new code the old one\'s photo, choices, Tamil name and description, '
            'and the old code leaves the shop once its stock is sold.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_error != null)
            ErrorView(message: _error!, onRetry: _load)
          else if (pairs == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (pairs.isEmpty)
            const EmptyView(icon: Icons.verified_outlined, title: 'Nothing to check', subtitle: 'New pairs show up here after a stock upload.')
          else ...[
            Text('$_total to check', style: text.titleSmall),
            const SizedBox(height: 8),
            for (final p in pairs) _PairCard(pair: p, busy: _busy.contains(p.neu.id), onDecide: (same) => _decide(p, same: same)),
            if (_total > pairs.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Showing ${pairs.length} of $_total — answer these to see more.', style: text.bodySmall, textAlign: TextAlign.center),
              ),
          ],
        ]),
      ),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({required this.pair, required this.busy, required this.onDecide});
  final ({AdminProduct old, AdminProduct neu}) pair;
  final bool busy;
  final ValueChanged<bool> onDecide;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final sides = [
      Expanded(child: _Side(label: 'Old code', p: pair.old)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 0, vertical: wide ? 0 : 4),
        child: Icon(wide ? Icons.arrow_forward_rounded : Icons.arrow_downward_rounded, color: AppColors.inkMuted),
      ),
      Expanded(child: _Side(label: 'New code', p: pair.neu)),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (wide) IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: sides)) else Column(children: [for (final w in sides) w is Expanded ? w.child : w]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton(onPressed: busy ? null : () => onDecide(false), child: const Text('Different products')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : () => onDecide(true),
                icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.link_rounded),
                label: const Text('Same product'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.label, required this.p});
  final String label;
  final AdminProduct p;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stock = double.tryParse(p.available) ?? 0;
    final bought = p.lastPurchaseAt == null ? null : DateFormat('d MMM yyyy').format(p.lastPurchaseAt!);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ProductThumb(url: p.imageUrl, placeholderUrl: p.imageUrl == null ? p.placeholderImageUrl : null, size: 64),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: text.labelSmall?.copyWith(color: AppColors.inkMuted, letterSpacing: 0.6)),
          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
          Text('JHS ${p.itemCode} · MRP ${formatRupees(p.mrp)}${p.packSize != null ? ' · ${p.packSize}' : ''}', style: text.bodySmall),
          Text(
            [
              if (!p.isActive) 'not on sale' else stock > 0 ? 'stock ${stock % 1 == 0 ? stock.toInt() : stock}' : 'out of stock',
              if (bought != null) 'bought $bought',
              p.imageUrl != null ? 'has photo' : 'no photo',
            ].join(' · '),
            style: text.labelSmall?.copyWith(color: p.imageUrl != null ? AppColors.green700 : AppColors.inkMuted),
          ),
        ]),
      ),
    ]);
  }
}
