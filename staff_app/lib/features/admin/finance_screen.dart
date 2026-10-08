import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Finance: the online shop's sales, costs, margin, expenses and profit for a period.
/// Costs come from the daily stock file (Landing Cost); expenses are entered here.
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

enum _Period { today, week, month30, thisMonth, lastMonth }

const _periodNames = {_Period.today: 'Today', _Period.week: '7 days', _Period.month30: '30 days', _Period.thisMonth: 'This month', _Period.lastMonth: 'Last month'};

final _day = DateFormat('yyyy-MM-dd');

(String, String) _range(_Period p) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return switch (p) {
    _Period.today => (_day.format(today), _day.format(today)),
    _Period.week => (_day.format(today.subtract(const Duration(days: 6))), _day.format(today)),
    _Period.month30 => (_day.format(today.subtract(const Duration(days: 29))), _day.format(today)),
    _Period.thisMonth => (_day.format(DateTime(now.year, now.month)), _day.format(today)),
    _Period.lastMonth => (_day.format(DateTime(now.year, now.month - 1)), _day.format(DateTime(now.year, now.month, 0))),
  };
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  _Period _period = _Period.month30;
  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _expenses = const [];
  List<String> _categories = const [];
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final (from, to) = _range(_period);
    setState(() => _loading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final results = await Future.wait([repo.finance(from, to), repo.expenses(from, to)]);
      if (!mounted) return;
      final (list, categories) = results[1] as (List<Map<String, dynamic>>, List<String>);
      setState(() {
        _report = results[0] as Map<String, dynamic>;
        _expenses = list;
        _categories = categories;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addExpense() async {
    final added = await showActionSheet<bool>(
      context,
      title: 'Add an expense',
      fields: const {'amount': '', 'note': ''},
      builder: (context, setState, fields) => _ExpenseForm(categories: _categories, fields: fields),
    );
    if (added == true) await _load();
  }

  Future<void> _deleteExpense(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: Text('${e['category']} · ${formatRupees(e['amount'] as String)} on ${e['spentOn']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await guard(context, () async {
      await ref.read(repositoryProvider).removeExpense((e['id'] as num).toInt());
      return true;
    });
    if (done == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Finance (online shop)'), actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: r == null ? null : FloatingActionButton.extended(onPressed: _addExpense, icon: const Icon(Icons.add_rounded), label: const Text('Add expense')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), children: [
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final p in _Period.values)
            ChoiceChip(
              label: Text(_periodNames[p]!),
              selected: _period == p,
              onSelected: (_) {
                setState(() => _period = p);
                _load();
              },
            ),
        ]),
        const SizedBox(height: 12),
        if (_loading && r == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        if (_error != null && r == null) ErrorView(message: _error!, onRetry: _load),
        if (r != null) ..._sections(context, r),
      ]),
    );
  }

  List<Widget> _sections(BuildContext context, Map<String, dynamic> r) {
    final text = Theme.of(context).textTheme;
    final orders = Map<String, dynamic>.from(r['orders'] as Map);
    final income = Map<String, dynamic>.from(r['income'] as Map);
    final costs = Map<String, dynamic>.from(r['costs'] as Map);
    final profit = Map<String, dynamic>.from(r['profit'] as Map);
    final catalog = Map<String, dynamic>.from(r['catalog'] as Map);
    final coverage = (costs['costCoveragePercent'] as num?)?.toDouble();
    String rs(Object? v) => v == null ? '—' : formatRupees(v.toString());
    String pct(Object? v) => v == null ? '' : '${(v as num).toStringAsFixed(1)}%';
    final net = profit['net'] as String?;
    final netNegative = net != null && net.startsWith('-');

    Widget row(String label, String value, {String? hint, Color? color, bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: bold ? text.titleSmall : text.bodyMedium),
                if (hint != null) Text(hint, style: text.bodySmall),
              ]),
            ),
            Text(value, style: (bold ? text.titleMedium : text.bodyLarge)?.copyWith(color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ]),
        );
    Widget card(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: text.titleMedium), const SizedBox(height: 6), ...children])),
        );

    return [
      // ── headline ──
      SectionCard(
        color: net == null ? AppColors.bg : (netNegative ? AppColors.offerRedSoft : AppColors.green50),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Net profit', style: text.titleSmall),
          Text(net == null ? 'Needs product costs' : rs(net), style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: netNegative ? AppColors.offerRed : AppColors.green800)),
          if (net != null) Text('${pct(profit['netPercent'])} of sales · gross margin ${rs(profit['grossMargin'])} (${pct(profit['grossMarginPercent'])})', style: text.bodySmall),
          const SizedBox(height: 8),
          Text('${orders['count']} orders · ${orders['customers']} customers · average ${rs(orders['averageOrder'])}', style: text.bodyMedium),
        ]),
      ),
      const SizedBox(height: 12),
      if (coverage == null || coverage < 95)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SectionCard(
            color: AppColors.amberSoft,
            child: Text(
              (catalog['withCost'] as num? ?? 0) == 0
                  ? 'Product costs aren\'t loaded yet. Upload today\'s stock file (More → Upload stock file) — margin and profit fill in for orders placed after that.'
                  : 'Costs known for ${pct(coverage ?? 0)} of these sales (${catalog['withCost']} of ${catalog['active']} products have a cost). The rest is estimated at the same cost ratio.',
              style: text.bodyMedium,
            ),
          ),
        ),
      card('Money in', [
        row('Sales (billed to customers)', rs(income['sales']), bold: true),
        row('Items', rs(income['items']), hint: 'after premium discounts and short-packs'),
        row('Delivery charges collected', rs(income['deliveryFees']), hint: '${orders['freeDeliveryOrders']} orders had free delivery'),
        row('Premium customer discounts', '− ${rs(income['memberDiscounts'])}', hint: '${orders['memberOrders']} orders by premium customers'),
        row('Cash on delivery', rs(income['cod'])),
        row('Paid online', rs(income['online'])),
        row('GST included in sales', rs(income['gstInSales']), hint: 'payable to government (less input credit)'),
      ]),
      card('Money out', [
        row('Cost of goods sold', rs(costs['goods']), hint: 'Landing cost from the stock file', bold: true),
        row('Payment gateway fees', rs(costs['gatewayFees']), hint: 'Razorpay fee + GST on online payments'),
        row('Expenses', rs(costs['expenses']), bold: true),
        for (final e in (costs['expensesByCategory'] as List? ?? const []))
          Padding(padding: const EdgeInsets.only(left: 12), child: row((e as Map)['category'] as String, rs(e['amount']))),
        row('Refunds', rs(income['refunded']), hint: '${income['refunds']} refunds — already left out of sales'),
      ]),
      card('Profit', [
        row('Items sold', rs(income['items'])),
        row('− Cost of goods', rs(costs['goods'])),
        row('= Gross margin', rs(profit['grossMargin']), hint: pct(profit['grossMarginPercent']).isEmpty ? null : '${pct(profit['grossMarginPercent'])} of items', bold: true),
        row('+ Delivery charges', rs(income['deliveryFees'])),
        row('− Gateway fees', rs(costs['gatewayFees'])),
        row('− Expenses', rs(costs['expenses'])),
        row('= Net profit', rs(profit['net']), bold: true, color: netNegative ? AppColors.offerRed : AppColors.green800),
      ]),
      if ((r['byCategory'] as List).isNotEmpty)
        card('By category', [
          for (final c in r['byCategory'] as List)
            row((c as Map)['category'] as String, rs(c['sales']), hint: c['marginPercent'] == null ? '${c['orders']} orders' : '${c['orders']} orders · margin ${pct(c['marginPercent'])}'),
        ]),
      if ((r['topProducts'] as List).isNotEmpty)
        card('Best earners', [
          for (final p in r['topProducts'] as List) row((p as Map)['name'] as String, rs(p['margin']), hint: 'sold ${p['qty']} · ${rs(p['sales'])} · ${pct(p['marginPercent'])}'),
        ]),
      if ((r['lowMargin'] as List).isNotEmpty)
        card('Low or negative margin — check price / cost', [
          for (final p in r['lowMargin'] as List)
            row((p as Map)['name'] as String, pct(p['marginPercent']), hint: 'sold ${p['qty']} · ${rs(p['sales'])}', color: AppColors.offerRed),
        ]),
      card('Expenses in this period', [
        if (_expenses.isEmpty) Text('None yet. Add delivery staff pay, fuel, packing material… with the button below.', style: text.bodySmall),
        for (final e in _expenses)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${e['category']} · ${formatRupees(e['amount'] as String)}'),
            subtitle: Text([e['spentOn'] as String, if (e['note'] != null) e['note'] as String].join(' · ')),
            trailing: IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _deleteExpense(e)),
          ),
      ]),
      Text('Sales count orders the store accepted (cancelled and unpaid ones left out) at their final bill. Prices and costs include GST.', style: text.bodySmall),
    ];
  }
}

class _ExpenseForm extends ConsumerStatefulWidget {
  const _ExpenseForm({required this.categories, required this.fields});
  final List<String> categories;
  final Map<String, TextEditingController> fields;

  @override
  ConsumerState<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<_ExpenseForm> {
  late String _category = widget.categories.isEmpty ? 'Other' : widget.categories.first;
  DateTime _date = DateTime.now();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final amount = widget.fields['amount']!;
    final note = widget.fields['note']!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (final c in widget.categories) ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
      ),
      const SizedBox(height: 12),
      TextField(controller: note, maxLength: 200, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. Ravi — October salary')),
      OutlinedButton.icon(
        icon: const Icon(Icons.event_outlined),
        label: Text('Date: ${DateFormat('d MMM yyyy').format(_date)}'),
        onPressed: () async {
          final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2026), lastDate: DateTime.now());
          if (picked != null) setState(() => _date = picked);
        },
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _busy
            ? null
            : () async {
                final value = amount.text.trim();
                if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(value) || double.parse(value) <= 0) {
                  return showSnack(context, 'Enter an amount like 450 or 450.50', error: true);
                }
                setState(() => _busy = true);
                final ok = await guard(context, () async {
                  await ref.read(repositoryProvider).addExpense(spentOn: _day.format(_date), category: _category, amount: value, note: note.text.trim().isEmpty ? null : note.text.trim());
                  return true;
                });
                if (!context.mounted) return;
                setState(() => _busy = false);
                if (ok == true) Navigator.pop(context, true);
              },
        child: const Text('Save expense'),
      ),
    ]);
  }
}
