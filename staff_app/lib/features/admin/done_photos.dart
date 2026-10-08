import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'products_screen.dart';

/// Photos already added — mine ([staffId] null) or one helper's (admin review) — newest first.
/// Tap one to look at it closely and replace it.
class DonePhotosList extends ConsumerStatefulWidget {
  const DonePhotosList({super.key, this.staffId, this.header});
  final String? staffId;
  final Widget? header;

  @override
  ConsumerState<DonePhotosList> createState() => _DonePhotosListState();
}

class _DonePhotosListState extends ConsumerState<DonePhotosList> {
  final List<AdminProduct> _items = [];
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
      final page = await ref.read(repositoryProvider).donePhotos(staffId: widget.staffId, cursor: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
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
    final when = DateFormat('d MMM, h:mm a');
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _load();
          return false;
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
          ?widget.header,
          if (_error != null) ErrorView(message: _error!, onRetry: () => _load(reset: true)),
          if (_items.isEmpty && !_loading && _error == null)
            const EmptyView(icon: Icons.photo_library_outlined, title: 'No photos yet', subtitle: 'Photos added show here, newest first.'),
          for (final p in _items)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(width: 64, height: 64, child: CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.contain, errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined))),
                ),
                title: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [p.priceLabel, if (p.packSize != null) p.packSize!, if (p.photoAt != null) 'added ${when.format(p.photoAt!)}'].join(' · '),
                  style: text.bodySmall,
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _open(p),
              ),
            ),
          if (_loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        ]),
      ),
    );
  }
}

/// Admin → Photo work → a person → their photos.
class PersonPhotosScreen extends StatelessWidget {
  const PersonPhotosScreen({super.key, required this.staffId, required this.name});
  final String staffId;
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Photos by $name')),
        body: DonePhotosList(
          staffId: staffId,
          header: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Tap a photo to check it on a big screen, replace it or remove it.', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      );
}
