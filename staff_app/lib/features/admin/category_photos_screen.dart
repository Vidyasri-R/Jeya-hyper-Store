import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Category photos: the pictures customers see on category tiles, the category side bar
/// and banners. Any real photo works; it is cropped to a square on the server.
class CategoryPhotosScreen extends ConsumerStatefulWidget {
  const CategoryPhotosScreen({super.key});

  @override
  ConsumerState<CategoryPhotosScreen> createState() => _CategoryPhotosScreenState();
}

class _CategoryPhotosScreenState extends ConsumerState<CategoryPhotosScreen> {
  List<Map<String, dynamic>>? _categories;
  String? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(repositoryProvider).shopCategories();
      if (mounted) setState(() => _categories = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  Future<void> _change(Map<String, dynamic> c) async {
    final id = (c['id'] as num).toInt();
    final hasPhoto = c['imageUrl'] != null;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(c['name'] as String, style: Theme.of(context).textTheme.titleMedium)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose a photo'), onTap: () => Navigator.pop(context, 'gallery')),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () => Navigator.pop(context, 'camera')),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.offerRed),
              title: const Text('Remove photo (show the icon instead)', style: TextStyle(color: AppColors.offerRed)),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    final repo = ref.read(repositoryProvider);
    if (action == 'remove') {
      setState(() => _busyId = id);
      final ok = await guard(context, () async {
        await repo.removeCategoryPhoto(id);
        return true;
      });
      if (mounted) setState(() => _busyId = null);
      if (ok == true) await _load();
      return;
    }
    final file = await ImagePicker().pickImage(source: action == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final type = imageTypeOf(bytes);
    if (!mounted) return;
    if (type == null) return showSnack(context, 'Use a JPG, PNG or WebP picture', error: true);
    setState(() => _busyId = id);
    final url = await guard(context, () => repo.uploadCategoryPhoto(id, bytes, type));
    if (!mounted) return;
    setState(() => _busyId = null);
    if (url != null) {
      showSnack(context, 'Photo updated — customers see it within 5 minutes');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final all = _categories;
    final parents = all?.where((c) => c['parentId'] == null).toList() ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Category photos')),
      body: all == null
          ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Text('Tap a category to change its picture. Use a clear, real photo of the kind of products (no brand names or logos).', style: text.bodySmall),
                const SizedBox(height: 12),
                for (final p in parents) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 8), child: Text(p['name'] as String, style: text.titleMedium)),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _Tile(category: p, busy: _busyId == p['id'], onTap: () => _change(p)),
                    for (final c in all.where((c) => c['parentId'] == p['id'])) _Tile(category: c, busy: _busyId == c['id'], onTap: () => _change(c)),
                  ]),
                ],
              ]),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.category, required this.busy, required this.onTap});
  final Map<String, dynamic> category;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final url = category['imageUrl'] as String?;
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 96,
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(fit: StackFit.expand, children: [
                if (url != null)
                  CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, _, _) => const ColoredBox(color: AppColors.bg))
                else
                  const ColoredBox(color: AppColors.bg, child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.inkMuted, size: 32)),
                if (busy) const ColoredBox(color: Color(0x88FFFFFF), child: Center(child: CircularProgressIndicator())),
              ]),
            ),
          ),
          const SizedBox(height: 4),
          Text(category['name'] as String, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: text.labelSmall),
          Text('${category['products']} products', style: text.labelSmall?.copyWith(color: AppColors.inkMuted)),
        ]),
      ),
    );
  }
}
