import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/image_drop.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → Category photos: each category's picture on the shop's tiles (else its drawn icon), and
/// the stand-in photo shown on its products that have no photo yet. Same tools as product photos.
class CategoryPhotosScreen extends ConsumerStatefulWidget {
  const CategoryPhotosScreen({super.key});

  @override
  ConsumerState<CategoryPhotosScreen> createState() => _CategoryPhotosScreenState();
}

class _CategoryPhotosScreenState extends ConsumerState<CategoryPhotosScreen> {
  List<Map<String, dynamic>>? _categories;
  String? _error;
  int? _busyId;
  /// true: the category's own picture on the shop's tiles; false: stand-in photo for its products.
  bool _tiles = true;
  String get _field => _tiles ? 'tileImageUrl' : 'imageUrl';

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

  /// Every category in screen order (main category, then its sub-categories): Enter / "Next" walks it.
  List<Map<String, dynamic>> get _ordered {
    final all = _categories ?? const [];
    return [
      for (final p in all.where((c) => c['parentId'] == null)) ...[p, ...all.where((c) => c['parentId'] == p['id'])],
    ];
  }

  /// Opens [c]; "Next category" / Enter goes straight on to the one after it.
  Future<void> _change(Map<String, dynamic> c) async {
    var current = c;
    while (mounted) {
      final next = ValueNotifier(false);
      final changed = await _sheet(current, next);
      if (changed == true) await _load();
      if (!next.value || !mounted) return;
      final list = _ordered;
      final at = list.indexWhere((x) => x['id'] == current['id']) + 1;
      if (at <= 0 || at >= list.length) return;
      current = list[at];
    }
  }

  /// The same tools as product photos: drag & drop, paste (Ctrl/⌘+V or right-click / long-press),
  /// upload, camera, copy the name to search for a picture.
  Future<bool?> _sheet(Map<String, dynamic> c, ValueNotifier<bool> next) {
    final id = (c['id'] as num).toInt();
    final name = c['name'] as String;
    final tiles = _tiles;
    final repo = ref.read(repositoryProvider);
    var imageUrl = c[_field] as String?;
    var busy = false;
    var changed = false;
    var nextWhenUploaded = false;

    return showActionSheet<bool>(
      context,
      title: name,
      builder: (context, setState, _) {
        final text = Theme.of(context).textTheme;

        Future<void> upload(Uint8List bytes, String type) async {
          setState(() => busy = true);
          final url = await guard(context, () => tiles ? repo.uploadCategoryTile(id, bytes, type) : repo.uploadCategoryPhoto(id, bytes, type));
          if (!context.mounted) return;
          setState(() {
            busy = false;
            if (url != null) {
              imageUrl = url;
              changed = true;
            }
          });
          if (url != null) showSnack(context, 'Picture saved — customers see it within 5 minutes');
          // Enter pressed while it was uploading: go on once it's saved.
          if (url != null && nextWhenUploaded && context.mounted) Navigator.pop(context, true);
          nextWhenUploaded = false;
        }

        void goNext() {
          next.value = true;
          if (busy) {
            nextWhenUploaded = true;
          } else {
            Navigator.pop(context, changed);
          }
        }

        Future<void> pick(ImageSource source) async {
          final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);
          if (file == null) return;
          final bytes = await file.readAsBytes();
          final type = imageTypeOf(bytes);
          if (!context.mounted) return;
          if (type == null) return showSnack(context, 'Use a JPG, PNG or WebP picture', error: true);
          await upload(bytes, type);
        }

        Future<void> dropped(DroppedImage image) async {
          if (busy) return;
          final type = imageTypeOf(image.bytes);
          if (type == null) return showSnack(context, 'Use a JPG, PNG or WebP picture', error: true);
          await upload(image.bytes, type);
        }

        return CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.enter): goNext, const SingleActivator(LogicalKeyboardKey.numpadEnter): goNext},
          child: Focus(
            autofocus: true,
            child: ImageDropZone(
              onImage: dropped,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: SelectableText(name, style: text.titleSmall)),
                  IconButton(
                    tooltip: 'Copy name',
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: name));
                      if (context.mounted) showSnack(context, 'Name copied');
                    },
                  ),
                ]),
                Text(
                  [tiles ? 'Category picture (tile in the shop)' : 'Stand-in for products without a photo', '${c['products']} products'].join(' · '),
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                // Right-click (website) / long-press (phone) → Paste photo.
                PastePhotoTarget(
                  enabled: !busy,
                  onImage: dropped,
                  onError: (message) => showSnack(context, message, error: true),
                  child: AspectRatio(
                    aspectRatio: 1.4,
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppColors.line)),
                      clipBehavior: Clip.antiAlias,
                      child: busy
                          ? const Center(child: CircularProgressIndicator())
                          : imageUrl == null
                          ? Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.add_photo_alternate_outlined, size: 48, color: AppColors.inkFaint),
                                const SizedBox(height: 6),
                                Text(kIsWeb ? 'Right-click here → Paste photo' : 'Long-press here → Paste photo', style: text.bodySmall),
                              ]),
                            )
                          : CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  if (!kIsWeb) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Take photo'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(kIsWeb ? 'Upload photo' : 'Gallery'),
                    ),
                  ),
                ]),
                if (imageUrl != null)
                  TextButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            final ok = await guard(context, () async {
                              tiles ? await repo.removeCategoryTile(id) : await repo.removeCategoryPhoto(id);
                              return true;
                            });
                            if (!context.mounted) return;
                            setState(() {
                              busy = false;
                              if (ok == true) {
                                imageUrl = null;
                                changed = true;
                              }
                            });
                          },
                    style: TextButton.styleFrom(foregroundColor: AppColors.offerRed),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(tiles ? 'Remove picture (show the icon instead)' : 'Remove stand-in photo'),
                  ),
                Text(
                  ImageDropZone.supported
                      ? 'Drag a picture onto this window, paste it (Ctrl+V / ⌘+V) or right-click the picture box → Paste photo. It uploads straight away.'
                      : 'Copied a picture? Long-press the picture box → Paste photo. Or take one / pick one from the gallery.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: goNext, child: Text(changed ? 'Next category →  (Enter)' : 'Skip to next category →  (Enter)')),
              ]),
            ),
          ),
        );
      },
    ).then((value) => value ?? changed);
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
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Category pictures'), icon: Icon(Icons.grid_view_rounded)),
                    ButtonSegment(value: false, label: Text('Product stand-ins'), icon: Icon(Icons.image_outlined)),
                  ],
                  selected: {_tiles},
                  onSelectionChanged: (v) => setState(() => _tiles = v.first),
                ),
                const SizedBox(height: 8),
                Text(
                  _tiles
                      ? 'The picture customers see on a category\'s tile (main categories and sub-categories). Without one, the shop shows its drawn icon. Tap a category to set it.'
                      : 'Products without their own photo show their category\'s photo until a real one is added. Use a clear photo of that kind of product, with no brand names or logos.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final p in parents) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(0, 12, 0, 8), child: Text(p['name'] as String, style: text.titleMedium)),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _Tile(category: p, field: _field, busy: _busyId == p['id'], onTap: () => _change(p)),
                    for (final c in all.where((c) => c['parentId'] == p['id'])) _Tile(category: c, field: _field, busy: _busyId == c['id'], onTap: () => _change(c)),
                  ]),
                ],
              ]),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.category, required this.field, required this.busy, required this.onTap});
  final Map<String, dynamic> category;
  final String field;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final url = category[field] as String?;
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
