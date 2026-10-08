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

  Future<void> _open(AdminProduct p) async {
    final isAdmin = ref.read(currentStaffProvider)?.isAdmin ?? false;
    final changed = await showProductSheet(context, ref, p, photoOnly: !isAdmin);
    if (changed == true) await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = _counts['open'] ?? 0, done = _counts['done'] ?? 0, today = _counts['doneToday'] ?? 0;
    final total = open + done;
    return Scaffold(
      appBar: AppBar(title: const Text('My photos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/scan');
          if (mounted) await _load(reset: true);
        },
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan barcode'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _load();
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
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
              if (_items.isEmpty && !_loading && _error == null)
                const EmptyView(icon: Icons.photo_camera_back_outlined, title: 'Nothing assigned to you', subtitle: 'The store admin hands out products in Photo work. Pull down to refresh.'),
              for (final p in _items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ProductThumb(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl),
                    title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text([if (p.brand != null) p.brand!, if (p.category != null) p.category!, 'Code ${p.itemCode}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
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
    );
  }
}
