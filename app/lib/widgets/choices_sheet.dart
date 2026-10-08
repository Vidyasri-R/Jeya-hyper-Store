import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import 'product_image.dart';

/// Pick how many of each flavour/colour (one store item sold in several). Returns the split —
/// empty means "remove from cart" — or null if dismissed.
Future<Choices?> showChoicesSheet(BuildContext context, Product product, {Choices? current}) {
  return showModalBottomSheet<Choices>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ChoicesSheet(product: product, current: current ?? const {}),
  );
}

class _ChoicesSheet extends StatefulWidget {
  const _ChoicesSheet({required this.product, required this.current});
  final Product product;
  final Choices current;

  @override
  State<_ChoicesSheet> createState() => _ChoicesSheetState();
}

class _ChoicesSheetState extends State<_ChoicesSheet> {
  late final Map<String, int> _qty = {for (final v in widget.product.options!.values) v: widget.current[v] ?? 0};

  int get _total => _qty.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = widget.product;
    final options = p.options!;
    final step = p.stepMilli;
    final atMax = _total + step > p.maxMilli;
    final had = widget.current.values.any((q) => q > 0);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(p.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Choose the ${options.label.toLowerCase()} · ${formatRupees(p.sellingPrice)} each', style: text.bodySmall),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final v in options.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      if (options.images[v] != null) ...[
                        ProductImage(url: options.images[v], name: v, size: 64, radius: AppRadius.sm),
                        const SizedBox(width: 12),
                      ],
                      Expanded(child: Text(v, style: text.titleSmall)),
                      _RoundButton(icon: Icons.remove, onTap: (_qty[v] ?? 0) == 0 ? null : () => setState(() => _qty[v] = (_qty[v]! - step).clamp(0, 1 << 30))),
                      SizedBox(
                        width: 44,
                        child: Text(formatQty(_qty[v] ?? 0, p.unit), textAlign: TextAlign.center, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      _RoundButton(icon: Icons.add, onTap: atMax ? null : () => setState(() => _qty[v] = (_qty[v] ?? 0) + step)),
                    ]),
                  ),
              ]),
            ),
            if (atMax) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Only ${formatQty(p.maxMilli, p.unit)} available', style: text.bodySmall?.copyWith(color: AppColors.offerRed))),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _total == 0 && !had ? null : () => Navigator.pop(context, {for (final e in _qty.entries) if (e.value > 0) e.key: e.value}),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(_total == 0
                  ? 'Remove from cart'
                  : '${had ? 'Update' : 'Add'} ${formatQty(_total, p.unit)} · ${formatPaise((toPaise(p.sellingPrice) * _total / 1000).round())}'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(onPressed: onTap, icon: Icon(icon, size: 18), visualDensity: VisualDensity.compact);
}
