import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Home: offers & popular. The automatic lists always run (biggest discounts / fast movers);
/// the admin adds extra products, shown first in their order, and hides automatic ones they don't want.
class HomeListsScreen extends ConsumerStatefulWidget {
  const HomeListsScreen({super.key});

  @override
  ConsumerState<HomeListsScreen> createState() => _HomeListsScreenState();
}

class _HomeListsScreenState extends ConsumerState<HomeListsScreen> {
  HomeList? _offers;
  HomeList? _popular;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lists = await ref.read(repositoryProvider).homeLists();
      if (mounted) {
        setState(() {
          _offers = lists.offers;
          _popular = lists.popular;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await guard(context, () async {
      await ref.read(repositoryProvider).saveHomeLists(
            offers: [for (final p in _offers!.pinned) p.id],
            popular: [for (final p in _popular!.pinned) p.id],
            hiddenOffers: [for (final p in _offers!.hidden) p.id],
            hiddenPopular: [for (final p in _popular!.hidden) p.id],
          );
      return true;
    });
    if (!mounted) return;
    setState(() => _saving = false);
    // The automatic part changes when something is pinned / hidden: reload what customers see.
    if (ok == true) await _load();
  }

  Future<void> _add(HomeList list) async {
    if (list.pinned.length >= 100) return showSnack(context, 'Up to 100 extra products. Remove one first.', error: true);
    final picked = await showModalBottomSheet<AdminProduct>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductSearchSheet(exclude: {for (final p in list.pinned) p.id}),
    );
    if (picked == null || !mounted) return;
    setState(() {
      list.pinned.add(picked);
      list.hidden.removeWhere((p) => p.id == picked.id);
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _offers != null;
    return DefaultTabController(
      length: 2,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Home: offers & popular'),
            actions: [if (_saving) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))],
            bottom: const TabBar(tabs: [Tab(text: "Today's offers"), Tab(text: 'Popular')]),
          ),
          floatingActionButton: loaded
              ? FloatingActionButton.extended(
                  onPressed: () => _add(DefaultTabController.of(context).index == 0 ? _offers! : _popular!),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add product'),
                )
              : null,
          body: !loaded
              ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
              : TabBarView(children: [
                  _ListTab(
                    list: _offers!,
                    rule: 'Automatic: in stock and below MRP, biggest discount first (then "Show first" and fast-moving products). Top 12, one per product.',
                    onChanged: _save,
                  ),
                  _ListTab(
                    list: _popular!,
                    rule: 'Automatic: in stock, "Show first" products, then the fastest movers (restocked most often and most recently, daily needs first). Top 20, one per product.',
                    onChanged: _save,
                  ),
                ]),
        );
      }),
    );
  }
}

class _ListTab extends StatelessWidget {
  const _ListTab({required this.list, required this.rule, required this.onChanged});
  final HomeList list;
  final String rule;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(AdminProduct p, {required Widget trailing, Color? tint}) => Card(
          key: ValueKey('${p.id}-${tint?.toARGB32()}'),
          color: tint,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: ProductThumb(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl),
            title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              !p.isActive || (double.tryParse(p.available) ?? 0) <= 0
                  ? 'Not shown now — out of stock'
                  : '${formatRupees(p.sellingPrice)}${p.mrp != p.sellingPrice ? '  (MRP ${formatRupees(p.mrp)})' : ''}',
              style: text.bodySmall,
            ),
            trailing: trailing,
          ),
        );
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
      Text('Customers see your extra products first, then the automatic ones. Hide any automatic product you don\'t want; the list fills up with the next one.', style: text.bodySmall),
      const SizedBox(height: 12),
      Text('Your extra products (${list.pinned.length})', style: text.titleSmall),
      const SizedBox(height: 4),
      if (list.pinned.isEmpty) Text('None — tap Add product to put a product here.', style: text.bodySmall),
      if (list.pinned.isNotEmpty)
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (from, to) {
            final p = list.pinned.removeAt(from);
            list.pinned.insert(to > from ? to - 1 : to, p);
            onChanged();
          },
          children: [
            for (final (i, p) in list.pinned.indexed)
              row(
                p,
                tint: AppColors.green50,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      list.pinned.removeAt(i);
                      onChanged();
                    },
                  ),
                  ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
                ]),
              ),
          ],
        ),
      const SizedBox(height: 14),
      Row(children: [
        const Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.green700),
        const SizedBox(width: 6),
        Expanded(child: Text('Automatic (${list.automatic.length})', style: text.titleSmall)),
      ]),
      Text(rule, style: text.bodySmall),
      const SizedBox(height: 6),
      for (final p in list.automatic)
        row(
          p,
          trailing: TextButton.icon(
            icon: const Icon(Icons.visibility_off_outlined, size: 18),
            label: const Text('Hide'),
            onPressed: () {
              list.hidden.add(p);
              list.automatic.remove(p);
              onChanged();
            },
          ),
        ),
      if (list.hidden.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('Hidden from the automatic list (${list.hidden.length})', style: text.titleSmall),
        const SizedBox(height: 4),
        for (final p in list.hidden)
          row(
            p,
            tint: AppColors.bg,
            trailing: TextButton.icon(
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('Show again'),
              onPressed: () {
                list.hidden.remove(p);
                onChanged();
              },
            ),
          ),
      ],
    ]);
  }
}

/// Search the catalogue by name, brand, item code or barcode and pick one product.
class _ProductSearchSheet extends ConsumerStatefulWidget {
  const _ProductSearchSheet({required this.exclude});
  final Set<int> exclude;

  @override
  ConsumerState<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends ConsumerState<_ProductSearchSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<AdminProduct> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (q.trim().length < 2) return setState(() => _results = const []);
      setState(() => _loading = true);
      try {
        final (page, _) = await ref.read(repositoryProvider).products(query: q);
        if (mounted && _query.text == q) setState(() => _results = page.items);
      } on ApiException catch (e) {
        if (mounted) showSnack(context, e.friendly, error: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                onChanged: _search,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search name, brand, code or barcode'),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(children: [
                for (final p in _results)
                  ListTile(
                    enabled: !widget.exclude.contains(p.id),
                    leading: ProductThumb(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl),
                    title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      widget.exclude.contains(p.id) ? 'Already in the list' : '${formatRupees(p.sellingPrice)} · ${p.category ?? ''}',
                      style: text.bodySmall,
                    ),
                    onTap: () => Navigator.pop(context, p),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
