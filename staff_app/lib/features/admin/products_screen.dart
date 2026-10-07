import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/money.dart';
import '../../core/photo_cutout.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Product photos (one per product) and the fields the store owns: Tamil name, description, priority.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  final List<AdminProduct> _items = [];
  Map<String, int> _counts = const {};
  String _filter = 'no_image';
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    _cursor = null;
    _done = false;
    await _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (_done && !reset)) return;
    setState(() => _loading = true);
    try {
      final (page, counts) = await ref.read(repositoryProvider).products(query: _search.text, filter: _filter, cursor: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _counts = counts;
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final active = _counts['active'] ?? 0;
    final withImage = _counts['withImage'] ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product photos'),
        actions: [
          IconButton(onPressed: () => context.push('/scan'), tooltip: 'Scan a barcode', icon: const Icon(Icons.qr_code_scanner_rounded)),
          IconButton(onPressed: () => context.go('/more/photo-work'), tooltip: 'Photo work', icon: const Icon(Icons.assignment_ind_outlined)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active > 0) ...[
                  Text('$withImage of $active products have a photo', style: text.bodySmall),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: withImage / active, minHeight: 6, backgroundColor: AppColors.line, color: AppColors.green600),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _search,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), _reload);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search name, brand, item code or barcode',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (key, label) in const [('no_image', 'No photo'), ('with_image', 'With photo'), ('all', 'All'), ('inactive', 'Hidden')])
                      ChoiceChip(
                        label: Text(label),
                        selected: _filter == key,
                        onSelected: (_) {
                          setState(() => _filter = key);
                          _reload();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _list(context)),
        ],
      ),
    );
  }

  Widget _list(BuildContext context) {
    if (_items.isEmpty && _loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty && _error != null) return ErrorView(message: _error!, onRetry: _reload);
    if (_items.isEmpty) {
      return EmptyView(
        icon: Icons.photo_library_outlined,
        title: _filter == 'no_image' && _search.text.isEmpty ? 'Every product has a photo 🎉' : 'No products found',
      );
    }
    final text = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _reload,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _load();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: _items.length + (_done ? 0 : 1),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              );
            }
            final p = _items[index];
            return Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () async {
                  final changed = await showProductSheet(context, ref, p);
                  if (changed == true) _reload();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      ProductThumb(url: p.imageUrl, placeholderUrl: p.placeholderImageUrl, size: 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(
                              [if (p.brand != null) p.brand!, if (p.packSize != null) p.packSize!, p.itemCode].join(' · '),
                              style: text.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatRupees(p.sellingPrice), style: text.titleSmall),
                          if (p.imageUrl == null)
                            const Pill('Add photo', fg: AppColors.brandBlue, bg: AppColors.brandBlueSoft, icon: Icons.add_a_photo_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Returns true when something changed (so the list reloads).
/// [photoOnly]: just the photo (photo helpers and staff); admins also edit the store's product details.
Future<bool?> showProductSheet(BuildContext context, WidgetRef ref, AdminProduct product, {bool photoOnly = false}) {
  var featured = product.sortRank > 0;
  var imageUrl = product.imageUrl;
  var busy = false;
  var changed = false;

  return showActionSheet<bool>(
    context,
    title: product.name,
    fields: {'nameTa': product.nameTa ?? '', 'description': product.description ?? ''},
    builder: (context, setState, fields) {
      final text = Theme.of(context).textTheme;
      final nameTa = fields['nameTa']!;
      final description = fields['description']!;

      Future<void> pick(ImageSource source) async {
        final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
        if (file == null) return;
        final original = await file.readAsBytes();
        final originalType = imageTypeOf(original);
        if (!context.mounted) return;
        if (originalType == null) return showSnack(context, 'Use a JPG, PNG or WebP photo', error: true);
        setState(() => busy = true);
        // Android cuts the product out on the phone; the server then puts it on pure white.
        final (bytes, type) = await cutOutProduct(file.path, original, originalType);
        if (!context.mounted) return;
        final url = await guard(context, () => ref.read(repositoryProvider).uploadPhoto(product.id, bytes, type));
        if (!context.mounted) return;
        setState(() {
          busy = false;
          if (url != null) {
            imageUrl = url;
            changed = true;
          }
        });
        if (url != null) showSnack(context, 'Photo saved — customers see it within a minute');
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            [
              if (product.brand != null) product.brand!,
              if (product.packSize != null) product.packSize!,
              'Code ${product.itemCode}',
              if (product.barcode != null) product.barcode!,
            ].join(' · '),
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1.4,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: busy
                  ? const Center(child: CircularProgressIndicator())
                  : imageUrl == null
                  ? const Center(child: Icon(Icons.image_not_supported_outlined, size: 48, color: AppColors.inkFaint))
                  : CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
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
            ],
          ),
          if (imageUrl != null && !photoOnly)
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final ok = await guard(context, () async {
                        await ref.read(repositoryProvider).removePhoto(product.id);
                        return true;
                      });
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
              label: const Text('Remove photo'),
            ),
          Text('Tip: product in the light box or on plain white paper. The app removes the background and centres it on white.', style: text.bodySmall),
          if (photoOnly) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: () => Navigator.pop(context, changed), child: Text(changed ? 'Done — next product' : 'Close')),
          ],
          if (!photoOnly) ...[
          const Divider(height: 28),
          TextField(
            controller: nameTa,
            decoration: const InputDecoration(labelText: 'Tamil name (optional)', hintText: 'e.g. பொன்னி அரிசி'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: description,
            maxLines: 3,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
          SwitchListTile(
            value: featured,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => featured = v),
            title: const Text('Show first (popular)'),
            subtitle: const Text('Listed at the top of its category'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    final ok = await guard(context, () async {
                      await ref.read(repositoryProvider).updateProduct(product.id, {
                        'nameTa': nameTa.text.trim(),
                        'description': description.text.trim(),
                        'sortRank': featured ? (product.sortRank > 0 ? product.sortRank : 100) : 0,
                      });
                      return true;
                    });
                    if (!context.mounted) return;
                    setState(() => busy = false);
                    if (ok == true) Navigator.pop(context, true);
                  },
            child: const Text('Save details'),
          ),
          ],
        ],
      );
    },
  ).then((value) => value ?? changed);
}
