import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Sales at a glance: today / 7 / 30 days, daily bars, best sellers.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _days = 7;
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ref.read(repositoryProvider).dashboard(_days);
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: data == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Today')),
                      ButtonSegment(value: 7, label: Text('7 days')),
                      ButtonSegment(value: 30, label: Text('30 days')),
                      ButtonSegment(value: 90, label: Text('90 days')),
                    ],
                    selected: {_days},
                    onSelectionChanged: (s) {
                      setState(() => _days = s.first);
                      _load();
                    },
                  ),
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 16),
                  _Kpis(data: data),
                  const SizedBox(height: 16),
                  if (_days > 1) _DailyBars(daily: [for (final d in data['daily'] as List) Map<String, dynamic>.from(d as Map)]),
                  const SizedBox(height: 16),
                  _TopProducts(items: [for (final p in data['topProducts'] as List) Map<String, dynamic>.from(p as Map)]),
                ],
              ),
            ),
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final totals = Map<String, dynamic>.from(data['totals'] as Map);
    final previous = Map<String, dynamic>.from(data['previous'] as Map);
    final sales = toPaise(totals['sales'] as String);
    final prevSales = toPaise(previous['sales'] as String);
    final change = prevSales == 0 ? null : ((sales - prevSales) * 100 / prevSales).round();

    Widget kpi(String label, String value, {String? hint, Color? color}) => Expanded(
      child: SectionCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.bodySmall),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: text.titleLarge?.copyWith(color: color)),
            ),
            if (hint != null) Text(hint, style: text.labelSmall),
          ],
        ),
      ),
    );

    return Column(
      children: [
        SectionCard(
          color: AppColors.green800,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sales', style: text.bodyMedium?.copyWith(color: Colors.white70)),
              Text(formatRupees(totals['sales'] as String), style: text.headlineMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                change == null
                    ? '${totals['orders']} orders'
                    : '${totals['orders']} orders · ${change >= 0 ? '▲' : '▼'} ${change.abs()}% vs previous ${data['days']} day${data['days'] == 1 ? '' : 's'}',
                style: text.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            kpi('Average order', formatRupees(totals['averageOrderValue'] as String)),
            const SizedBox(width: 10),
            kpi('Customers', '${totals['customers']}'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            kpi('Cash on delivery', formatRupees(totals['codSales'] as String)),
            const SizedBox(width: 10),
            kpi('Paid online', formatRupees(totals['onlineSales'] as String)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            kpi('Delivered', '${totals['delivered']}', color: AppColors.green700),
            const SizedBox(width: 10),
            kpi('Cancelled', '${totals['cancelled']}', color: (totals['cancelled'] as num) > 0 ? AppColors.offerRed : null),
          ],
        ),
      ],
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.daily});
  final List<Map<String, dynamic>> daily;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (daily.isEmpty) return const SizedBox.shrink();
    final max = daily.map((d) => toPaise(d['sales'] as String)).fold<int>(1, (a, b) => b > a ? b : a);
    final label = DateFormat('d MMM');
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales by day', style: text.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in daily)
                  Expanded(
                    child: Tooltip(
                      message: '${label.format(DateTime.parse(d['day'] as String))}: ${formatRupees(d['sales'] as String)} · ${d['orders']} orders',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: (toPaise(d['sales'] as String) / max).clamp(0.02, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(color: AppColors.green600, borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(label.format(DateTime.parse(daily.first['day'] as String)), style: text.labelSmall),
              const Spacer(),
              Text(label.format(DateTime.parse(daily.last['day'] as String)), style: text.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopProducts extends StatelessWidget {
  const _TopProducts({required this.items});
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Best sellers', style: text.titleMedium),
          const SizedBox(height: 8),
          if (items.isEmpty) Text('No sales in this period yet.', style: text.bodySmall),
          for (final (i, p) in items.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text('${i + 1}', style: text.titleSmall?.copyWith(color: AppColors.inkFaint)),
                  ),
                  Expanded(
                    child: Text(p['name'] as String, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text('×${p['quantity']}', style: text.bodySmall),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 84,
                    child: Text(formatRupees(p['sales'] as String), textAlign: TextAlign.end, style: text.titleSmall),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
