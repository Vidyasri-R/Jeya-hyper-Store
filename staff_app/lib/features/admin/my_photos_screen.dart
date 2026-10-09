import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/image_drop.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'done_photos.dart';
import 'photo_race_screen.dart';
import 'products_screen.dart';

/// My photo work: the products the admin assigned to me, most important first. Tap one (or scan
/// its barcode), add the photo — the app puts it on a white background — and it leaves the list.
class MyPhotosScreen extends ConsumerStatefulWidget {
  const MyPhotosScreen({super.key});

  @override
  ConsumerState<MyPhotosScreen> createState() => _MyPhotosScreenState();
}

class _MyPhotosScreenState extends ConsumerState<MyPhotosScreen> {
  final List<AdminProduct> _items = [];
  Map<String, int> _counts = const {};
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  bool _taking = false;

  Future<void> _takeMore() async {
    setState(() => _taking = true);
    final n = await guard(context, () => ref.read(repositoryProvider).takeMorePhotos());
    if (!mounted) return;
    setState(() => _taking = false);
    if (n == null) return;
    showSnack(context, n == 0 ? 'No products left without photos 🎉' : '$n products added to your list');
    await _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (_done && !reset)) return;
    setState(() => _loading = true);
    try {
      final (page, counts) = await ref.read(repositoryProvider).myPhotos(cursor: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
        _counts = counts;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens [p]; "Next product" / Enter goes straight on to the one after it in the list.
  Future<void> _open(AdminProduct p) async {
    final isAdmin = ref.read(currentStaffProvider)?.isAdmin ?? false;
    var current = p;
    while (mounted) {
      final next = ValueNotifier(false);
      final was = _items.indexWhere((x) => x.id == current.id);
      final changed = await showProductSheet(context, ref, current, photoOnly: !isAdmin, next: next);
      if (changed == true) await _load(reset: true);
      if (!next.value || !mounted) return;
      // A product that got its photo leaves the list; the next one then sits where it was.
      final still = _items.indexWhere((x) => x.id == current.id);
      final at = still >= 0 ? still + 1 : was;
      if (at < 0 || at >= _items.length) {
        showSnack(context, _items.isEmpty ? 'All done — nothing left in your list' : 'That was the last one on this page');
        return;
      }
      current = _items[at];
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = _counts['open'] ?? 0, done = _counts['done'] ?? 0, today = _counts['doneToday'] ?? 0;
    final total = open + done;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('My photos'),
        bottom: TabBar(tabs: [Tab(text: 'To do ($open)'), Tab(text: 'Done ($done)')]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/scan');
          if (mounted) await _load(reset: true);
        },
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan barcode'),
      ),
      body: TabBarView(children: [
      RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _load();
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const PhotoRaceCard(),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(open == 0 ? 'All done!' : '$open products to photograph', style: text.titleMedium)),
                    Text('Today: $today', style: text.labelLarge?.copyWith(color: AppColors.green700, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 8, backgroundColor: AppColors.line, color: AppColors.green700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$done done${total > 0 ? ' of $total' : ''}. Any clear photo works — the app removes the background and puts the product on white.'
                    '${ImageDropZone.supported ? ' Tap ⧉ to copy a name; in a product you can drag a photo in or paste it (Ctrl+V).' : ''}',
                    style: text.bodySmall,
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (_error != null) ErrorView(message: _error!, onRetry: () => _load(reset: true)),
              if (_items.isEmpty && !_loading && _error == null) ...[
                EmptyView(
                  icon: done > 0 ? Icons.celebration_outlined : Icons.photo_camera_back_outlined,
                  title: done > 0 ? 'Your list is done — great work!' : 'Nothing assigned to you',
                  subtitle: (_counts['canTakeMore'] ?? 0) == 1
                      ? 'Take the next products yourself — the most important ones come first.'
                      : 'The store admin hands out products in Photo work. Pull down to refresh.',
                ),
                if ((_counts['canTakeMore'] ?? 0) == 1)
                  Center(
                    child: FilledButton.icon(
                      onPressed: _taking ? null : _takeMore,
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: Text('Get ${_counts['takeMoreBatch'] ?? 25} more products'),
                    ),
                  ),
              ],
              for (final p in _items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ProductThumb(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl),
                    title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        [p.priceLabel, if (p.packSize != null) p.packSize!].join(' · '),
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppColors.green800),
                      ),
                      if (p.needsRecheck)
                        Text('New packaging — check the photo', style: text.bodySmall?.copyWith(color: const Color(0xFF8A5A00), fontWeight: FontWeight.w700)),
                      Text([if (p.brand != null) p.brand!, if (p.category != null) p.category!, 'Code ${p.itemCode}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Copy name',
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: p.name));
                          if (context.mounted) showSnack(context, 'Copied: ${p.name}');
                        },
                      ),
                      const Icon(Icons.add_a_photo_outlined),
                    ]),
                    onTap: () => _open(p),
                  ),
                ),
              if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      ),
      // Photos I added: check them and replace any that came out wrong.
      DonePhotosList(
        key: ValueKey('done-$done'),
        header: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('Your photos, newest first. Tap one to replace it if it came out wrong.', style: text.bodySmall),
        ),
      ),
      ]),
      ),
    );
  }
}
