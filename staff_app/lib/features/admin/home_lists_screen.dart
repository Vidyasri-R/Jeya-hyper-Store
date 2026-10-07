import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Home: offers & popular. The products customers see under "Today's offers" and
/// "Popular in your store" on the app and website home, in this order. An empty list shows the
/// automatic one (biggest discounts / fast movers). Every change is saved straight away.
class HomeListsScreen extends ConsumerStatefulWidget {
  const HomeListsScreen({super.key});

  @override
  ConsumerState<HomeListsScreen> createState() => _HomeListsScreenState();
}

class _HomeListsScreenState extends ConsumerState<HomeListsScreen> {
  List<AdminProduct>? _offers;
  List<AdminProduct>? _popular;
  String? _error;
  bool _saving = false;

  static const _max = {0: 30, 1: 60};

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
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  List<AdminProduct> _list(int tab) => tab == 0 ? _offers! : _popular!;

  Future<void> _save() async {
    setState(() => _saving = true);
    await guard(context, () async {
      await ref.read(repositoryProvider).saveHomeLists(offers: [for (final p in _offers!) p.id], popular: [for (final p in _popular!) p.id]);
      return true;
    });
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _add(int tab) async {
    final list = _list(tab);
    if (list.length >= _max[tab]!) return showSnack(context, 'This list is full (${_max[tab]} products). Remove one first.', error: true);
    final picked = await showModalBottomSheet<AdminProduct>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductSearchSheet(exclude: {for (final p in list) p.id}),
    );
    if (picked == null || !mounted) return;
    setState(() => list.add(picked));
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
            bottom: TabBar(tabs: [
              Tab(text: "Today's offers${loaded ? ' (${_offers!.length})' : ''}"),
              Tab(text: 'Popular${loaded ? ' (${_popular!.length})' : ''}'),
            ]),
          ),
          floatingActionButton: loaded
              ? FloatingActionButton.extended(
                  onPressed: () => _add(DefaultTabController.of(context).index),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add product'),
                )
              : null,
          body: !loaded
              ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
              : TabBarView(children: [
                  _ListTab(
                    items: _offers!,
                    emptyText: 'Empty: the app shows the biggest discounts automatically.\nAdd products to choose them yourself.',
                    onChanged: () {
                      setState(() {});
                      _save();
                    },
                  ),
                  _ListTab(
                    items: _popular!,
                    emptyText: 'Empty: the app shows the fastest-moving products automatically.\nAdd products to choose them yourself.',
                    onChanged: () {
                      setState(() {});
                      _save();
                    },
                  ),
                ]),
        );
      }),
    );
  }
}

class _ListTab extends StatelessWidget {
  const _ListTab({required this.items, required this.emptyText, required this.onChanged});
  final List<AdminProduct> items;
  final String emptyText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (items.isEmpty) {
      return EmptyView(icon: Icons.auto_awesome_outlined, title: 'Automatic', subtitle: emptyText);
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text('Customers see these in this order. Drag ☰ to reorder. Sold-out products are skipped until they are back.', style: text.bodySmall),
      ),
      itemCount: items.length,
      onReorder: (from, to) {
        final p = items.removeAt(from);
        items.insert(to > from ? to - 1 : to, p);
        onChanged();
      },
      itemBuilder: (context, i) {
        final p = items[i];
        final hidden = !p.isActive || (double.tryParse(p.available) ?? 0) <= 0;
        return Card(
          key: ValueKey(p.id),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: ProductThumb(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl),
            title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              hidden ? 'Not shown now — out of stock' : '${formatRupees(p.sellingPrice)}${p.mrp != p.sellingPrice ? '  (MRP ${formatRupees(p.mrp)})' : ''}',
              style: hidden ? text.bodySmall?.copyWith(color: AppColors.offerRed) : text.bodySmall,
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  items.removeAt(i);
                  onChanged();
                },
              ),
              ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
            ]),
          ),
        );
      },
    );
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
