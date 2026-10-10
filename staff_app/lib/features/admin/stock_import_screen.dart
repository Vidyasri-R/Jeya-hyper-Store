import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/pick_file.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Upload stock file: GoFrugal → Reports → "Current Stock Detail" → export CSV (don't open
/// it in Excel), then upload here. Shows what will change; one tap imports products, prices, stock
/// and categories. Products missing from the file go out of stock (their photos are kept).
class StockImportScreen extends ConsumerStatefulWidget {
  const StockImportScreen({super.key});

  @override
  ConsumerState<StockImportScreen> createState() => _StockImportScreenState();
}

class _StockImportScreenState extends ConsumerState<StockImportScreen> {
  Map<String, dynamic>? _status;
  Uint8List? _file;
  String? _fileName;
  Map<String, dynamic>? _preview;
  Map<String, dynamic>? _result;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final s = await ref.read(repositoryProvider).stockImportStatus();
      if (mounted) setState(() => _status = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _pick() async {
    final PickedFile? f;
    try {
      f = await pickFile('csv');
    } catch (_) {
      if (mounted) showSnack(context, 'Couldn’t read that file. Try choosing it again.');
      return;
    }
    if (f == null || !mounted) return;
    setState(() {
      _file = f!.bytes;
      _fileName = f.name;
      _preview = null;
      _result = null;
    });
    await _runPreview();
  }

  Future<void> _runPreview() async {
    final file = _file;
    if (file == null) return;
    setState(() => _busy = true);
    final res = await guard(context, () => ref.read(repositoryProvider).importStockFile(file, apply: false));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res != null) _preview = Map<String, dynamic>.from(res['preview'] as Map);
    });
  }

  Future<void> _apply() async {
    final file = _file;
    if (file == null) return;
    setState(() => _busy = true);
    final res = await guard(context, () => ref.read(repositoryProvider).importStockFile(file, apply: true));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res != null) {
        _result = Map<String, dynamic>.from(res['result'] as Map);
        _preview = Map<String, dynamic>.from(res['preview'] as Map);
      }
    });
    if (res != null) {
      showSnack(context, 'Stock updated — customers see it within a minute');
      await _loadStatus();
    }
  }

  /// Move a whole POS group ([type]) or some of its products to a website category. Remembered for
  /// future uploads; products already in the shop move right away. Then preview again.
  Future<void> _move({required String key, required List<String> itemCodes, String? type}) async {
    final name = ((_status?['categories'] as List? ?? const []).cast<Map>().firstWhere((c) => c['key'] == key, orElse: () => {'name': key}))['name'];
    final moved = await guard(context, () => ref.read(repositoryProvider).moveProducts(category: key, itemCodes: itemCodes, type: type));
    if (moved == null || !mounted) return;
    showSnack(context, '${itemCodes.length} product${itemCodes.length == 1 ? '' : 's'} moved to $name');
    await _loadStatus();
    await _runPreview();
  }

  Future<void> _setDepartments(List<String> departments) async {
    final settings = Map<String, dynamic>.from((_status?['settings'] as Map?) ?? const {'departments': [], 'typeMap': {}});
    final saved = await guard(context, () => ref.read(repositoryProvider).saveSetting('catalog.import', {...settings, 'departments': departments}));
    if (saved == null || !mounted) return;
    await _loadStatus();
    await _runPreview();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _status?['last'] as Map?;
    final lastAt = DateTime.tryParse(last?['lastSuccessAt'] as String? ?? '')?.toLocal();
    final stale = lastAt == null || DateTime.now().difference(lastAt) > const Duration(hours: 24);
    final p = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload stock file')),
      body: _status == null && _error != null
          ? ErrorView(message: _error!, onRetry: _loadStatus)
          : ListView(padding: EdgeInsets.symmetric(vertical: 16, horizontal: ((MediaQuery.sizeOf(context).width - 900) / 2).clamp(16, double.infinity)), children: [
              SectionCard(
                color: stale ? AppColors.amberSoft : AppColors.green50,
                child: Row(children: [
                  Icon(stale ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: stale ? const Color(0xFF8A5A00) : AppColors.green700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lastAt == null
                          ? 'No stock file uploaded yet. The shop shows sample products until you do.'
                          : 'Last updated ${DateFormat('EEE d MMM, h:mm a').format(lastAt)}${stale ? ' — more than a day old. Upload today’s file.' : ''}',
                      style: text.bodyMedium,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Text('How to get the file', style: text.titleSmall),
              const SizedBox(height: 4),
              Text('In GoFrugal: Reports → Current Stock Detail → Export → CSV. Upload it straight away — don’t open and save it in Excel (that damages barcodes). Do this every morning, and again in the evening if you can.', style: text.bodySmall),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.upload_file_rounded),
                label: Text(_fileName == null ? 'Choose stock file (.csv)' : 'Choose a different file'),
              ),
              if (_fileName != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_fileName!, style: text.bodySmall, textAlign: TextAlign.center)),
              if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              if (p != null && !_busy) ...[
                const SizedBox(height: 16),
                if (_result != null)
                  SectionCard(
                    color: AppColors.green50,
                    child: Text(
                      'Done: ${(_result!['items'] as Map)['changed']} products updated, ${(_result!['items'] as Map)['deactivated']} now out of stock, '
                      '${(_result!['items'] as Map)['rejected']} skipped.',
                      style: text.titleSmall?.copyWith(color: AppColors.green800),
                    ),
                  ),
                if (_result != null && (_result!['possibleNewCodes'] as num? ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    color: AppColors.amberSoft,
                    child: Row(children: [
                      const Icon(Icons.link_rounded, color: Color(0xFF8A5A00)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_result!['possibleNewCodes']} new codes look like products you already have (new packaging?). Check them so photos carry over.',
                          style: text.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: () => context.push('/more/new-codes'), child: const Text('Review')),
                    ]),
                  ),
                ],
                if (_result != null) const SizedBox(height: 12),
                _PreviewSummary(preview: p),
                const SizedBox(height: 12),
                _Departments(preview: p, onChanged: _setDepartments),
                const SizedBox(height: 12),
                _OtherTypes(preview: p, categories: [for (final c in (_status?['categories'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)], onMove: _move),
                if ((p['problemCount'] as num? ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  _Problems(preview: p),
                ],
                const SizedBox(height: 16),
                if (_result == null)
                  FilledButton.icon(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text('Import ${NumberFormat.decimalPattern('en_IN').format(p['products'])} products now'),
                  ),
              ],
            ]),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  const _PreviewSummary({required this.preview});
  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final f = NumberFormat.decimalPattern('en_IN');
    int n(String k) => (preview[k] as num? ?? 0).toInt();
    Widget line(IconData icon, String label, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 10), Expanded(child: Text(label, style: text.bodyMedium))]),
        );
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What this file changes', style: text.titleMedium),
        const SizedBox(height: 8),
        line(Icons.inventory_2_outlined, '${f.format(n('products'))} products (${f.format(n('online'))} on sale) from ${f.format(n('rows'))} batch rows', AppColors.ink),
        if (n('added') > 0) line(Icons.add_circle_outline_rounded, '${f.format(n('added'))} new products', AppColors.green700),
        if (n('priceChanged') > 0) line(Icons.sell_outlined, '${f.format(n('priceChanged'))} price changes', AppColors.brandBlue),
        for (final s in (preview['priceSamples'] as List? ?? const []))
          Padding(
            padding: const EdgeInsets.only(left: 30, bottom: 2),
            child: Text('${(s as Map)['name']}: ${formatRupees(s['from'] as String)} → ${formatRupees(s['to'] as String)}', style: text.bodySmall),
          ),
        if (n('backInStock') > 0) line(Icons.restore_rounded, '${f.format(n('backInStock'))} back in stock', AppColors.green700),
        if (n('goingOut') > 0) line(Icons.remove_shopping_cart_outlined, '${f.format(n('goingOut'))} not in this file → out of stock (photos kept)', AppColors.offerRed),
        if (n('looseItems') > 0) line(Icons.scale_outlined, '${n('looseItems')} sold by weight (BULK / loose)', AppColors.inkMuted),
        if (n('newPackaging') > 0)
          line(Icons.published_with_changes_rounded, '${n('newPackaging')} with a new barcode (packaging changed?) → photo to re-check in Photo work', const Color(0xFF8A5A00)),
        const Divider(height: 20),
        Text('Categories in the shop', style: text.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in (preview['categories'] as List? ?? const []))
            if ((c as Map)['parent'] != null || c['key'] == 'other' || c['key'] == 'pooja' || c['key'] == 'baby' || c['key'] == 'pet' || c['key'] == 'stationery')
              Chip(label: Text('${c['name']} · ${c['products']}'), visualDensity: VisualDensity.compact),
        ]),
      ]),
    );
  }
}

class _Departments extends StatelessWidget {
  const _Departments({required this.preview, required this.onChanged});
  final Map<String, dynamic> preview;
  final void Function(List<String>) onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = Map<String, dynamic>.from((preview['departments'] as Map?) ?? const {});
    final selected = [for (final d in (preview['selectedDepartments'] as List? ?? const [])) (d as String).replaceAll(' ', '').toUpperCase()];
    String norm(String d) => (d == '(blank)' ? '' : d).replaceAll(' ', '').toUpperCase();
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Departments sold online', style: text.titleSmall),
        Text('Ticked departments go to the shop. Others (gifts, toys, footwear…) stay in-store only.', style: text.bodySmall),
        for (final e in all.entries)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: selected.contains(norm(e.key)),
            title: Text('${e.key} · ${e.value} rows'),
            onChanged: (on) {
              final next = {...selected};
              on == true ? next.add(norm(e.key)) : next.remove(norm(e.key));
              onChanged(next.toList());
            },
          ),
      ]),
    );
  }
}

class _OtherTypes extends StatelessWidget {
  const _OtherTypes({required this.preview, required this.categories, required this.onMove});
  final Map<String, dynamic> preview;
  final List<Map<String, dynamic>> categories;
  final Future<void> Function({required String key, required List<String> itemCodes, String? type}) onMove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final types = [for (final t in (preview['otherTypes'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
    if (types.isEmpty) return const SizedBox.shrink();
    final leafs = categories.where((c) => c['parent'] != null || ['pooja', 'baby', 'pet', 'stationery'].contains(c['key'])).toList();
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('In "More Items" — move them to a better place', style: text.titleSmall),
        Text('These POS groups didn’t match a category. Tap a group to see its products and move some of them, or move the whole group (remembered for future uploads).', style: text.bodySmall),
        const SizedBox(height: 6),
        const Divider(height: 1),
        for (final t in types) ...[
          InkWell(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => _GroupSheet(group: t, leafs: leafs, onMove: onMove),
            ),
            child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['type'] as String, style: text.bodyMedium),
                  Text(
                    [for (final i in (t['items'] as List? ?? const []).take(3)) (i as Map)['name']].join(', ') + ((t['count'] as num) > 3 ? '…' : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ]),
              ),
              Text('${t['count']} ›', style: text.bodySmall),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                tooltip: 'Move all of ${t['type']}',
                onSelected: (key) => onMove(key: key, itemCodes: [for (final i in (t['items'] as List? ?? const [])) (i as Map)['itemCode'] as String], type: t['type'] as String),
                itemBuilder: (_) => [for (final c in leafs) PopupMenuItem(value: c['key'] as String, child: Text(c['name'] as String))],
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Move all'), Icon(Icons.arrow_drop_down)]),
                ),
              ),
            ]),
          ),
          ),
          const Divider(height: 1),
        ],
      ]),
    );
  }
}

/// One "More Items" group: its products, each movable on its own (or all together).
class _GroupSheet extends StatefulWidget {
  const _GroupSheet({required this.group, required this.leafs, required this.onMove});
  final Map<String, dynamic> group;
  final List<Map<String, dynamic>> leafs;
  final Future<void> Function({required String key, required List<String> itemCodes, String? type}) onMove;

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  late final List<Map<String, dynamic>> _items = [for (final i in (widget.group['items'] as List? ?? const [])) Map<String, dynamic>.from(i as Map)];
  final _picked = <String>{};
  bool _busy = false;

  Future<void> _moveTo(String key, List<String> codes, {bool all = false}) async {
    setState(() => _busy = true);
    await widget.onMove(key: key, itemCodes: codes, type: all ? widget.group['type'] as String : null);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _items.removeWhere((i) => codes.contains(i['itemCode']));
      _picked.clear();
    });
    if (_items.isEmpty) Navigator.pop(context);
  }

  Widget _menu(String label, void Function(String key) onSelected) => PopupMenuButton<String>(
        enabled: !_busy,
        onSelected: onSelected,
        itemBuilder: (_) => [for (final c in widget.leafs) PopupMenuItem(value: c['key'] as String, child: Text(c['name'] as String))],
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label), const Icon(Icons.arrow_drop_down)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.group['type']} · ${_items.length} products', style: text.titleMedium),
              Text('Tick products and move them, or move the whole group.', style: text.bodySmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (_picked.isNotEmpty) _menu('Move ${_picked.length} ticked', (key) => _moveTo(key, _picked.toList())),
                _menu('Move all ${_items.length}', (key) => _moveTo(key, [for (final i in _items) i['itemCode'] as String], all: true)),
              ]),
            ]),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (_, k) {
                final i = _items[k];
                final code = i['itemCode'] as String;
                return CheckboxListTile(
                  dense: true,
                  value: _picked.contains(code),
                  onChanged: _busy ? null : (v) => setState(() => v == true ? _picked.add(code) : _picked.remove(code)),
                  title: Text(i['name'] as String),
                  subtitle: Text('MRP ${formatRupees(i['mrp'] as String)} · stock ${double.tryParse(i['stock'] as String)?.toStringAsFixed(0) ?? i['stock']} · code $code'),
                  secondary: _menu('Move', (key) => _moveTo(key, [code])),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Problems extends StatelessWidget {
  const _Problems({required this.preview});
  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      color: AppColors.offerRedSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${preview['problemCount']} rows skipped', style: text.titleSmall),
        Text('Fix these in GoFrugal if they should be sold online.', style: text.bodySmall),
        const SizedBox(height: 6),
        for (final pr in (preview['problems'] as List? ?? const []).take(15))
          Text('• ${(pr as Map)['name']} (${pr['itemCode']}): ${pr['reason']}', style: text.bodySmall),
      ]),
    );
  }
}
