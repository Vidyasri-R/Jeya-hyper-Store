import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/image_drop.dart';
import '../../core/money.dart';
import '../../core/photo_cutout.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'choices_editor.dart';

/// Every product: search, filter (photo, choices, category, hidden…) and edit — photo, name, category,
/// size, brand, hide from the shop, Tamil name, description, choices, priority.
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  final List<AdminProduct> _items = [];
  Map<String, int> _counts = const {};
  String _filter = 'all';
  ({int id, String name})? _category;
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

  /// Opens [p]; "Next product" / Enter goes straight on to the one after it in the list.
  Future<void> _openFrom(AdminProduct p) async {
    var current = p;
    while (mounted) {
      final next = ValueNotifier(false);
      final was = _items.indexWhere((x) => x.id == current.id);
      final changed = await showProductSheet(context, ref, current, next: next);
      if (changed == true) await _reload();
      if (!next.value || !mounted) return;
      final still = _items.indexWhere((x) => x.id == current.id);
      final at = still >= 0 ? still + 1 : was;
      if (at < 0 || at >= _items.length) return;
      current = _items[at];
    }
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
      final (page, counts) = await ref.read(repositoryProvider).products(query: _search.text, filter: _filter, categoryId: _category?.id, cursor: reset ? null : _cursor);
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
        title: const Text('Products'),
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InputChip(
                        avatar: const Icon(Icons.category_outlined, size: 18),
                        label: Text(_category == null ? 'All categories' : _category!.name.split(' › ').last),
                        selected: _category != null,
                        onPressed: () async {
                          final picked = await pickCategory(context, ref, current: _category?.id);
                          if (picked == null || !mounted) return;
                          setState(() => _category = picked);
                          _reload();
                        },
                        onDeleted: _category == null
                            ? null
                            : () {
                                setState(() => _category = null);
                                _reload();
                              },
                      ),
                      const SizedBox(width: 8),
                      for (final (key, label) in const [
                        ('all', 'All'),
                        ('no_image', 'No photo'),
                        ('recheck', 'New packaging'),
                        ('with_image', 'With photo'),
                        ('choices', 'Has choices'),
                        ('edited', 'Changed by you'),
                        ('inactive', 'Hidden'),
                      ]) ...[
                        ChoiceChip(
                          label: Text(label),
                          selected: _filter == key,
                          onSelected: (_) {
                            setState(() => _filter = key);
                            _reload();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
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
                onTap: () => _openFrom(p),
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
                            if (p.category != null) Text(p.category!, style: text.labelSmall?.copyWith(color: AppColors.green800), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (!p.isActive || p.options != null || p.lockedFields.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(spacing: 4, runSpacing: 4, children: [
                                  if (!p.isActive) const Pill('Hidden', fg: AppColors.inkMuted, bg: AppColors.bg, icon: Icons.visibility_off_outlined),
                                  if (p.options != null) Pill('${(p.options!['values'] as List).length} ${(p.options!['label'] ?? 'choice').toString().toLowerCase()}s', fg: AppColors.brandBlue, bg: AppColors.brandBlueSoft, icon: Icons.style_outlined),
                                  if (p.lockedFields.any((f) => f != 'is_active')) const Pill('Changed by you', fg: Color(0xFF8A5A00), bg: AppColors.amberSoft, icon: Icons.edit_outlined),
                                ]),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('MRP ${formatRupees(p.mrp)}', style: text.titleSmall),
                          if (p.sellingPrice != p.mrp) Text('Sells ${formatRupees(p.sellingPrice)}', style: text.labelSmall),
                          if (p.imageUrl == null)
                            const Pill('Add photo', fg: AppColors.brandBlue, bg: AppColors.brandBlueSoft, icon: Icons.add_a_photo_outlined)
                          else if (p.needsRecheck)
                            const Pill('New packaging', fg: Color(0xFF8A5A00), bg: AppColors.amberSoft, icon: Icons.published_with_changes_rounded),
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
/// [next]: set to true when the user asks for the next product (Enter key or "Next product"), so a
/// list can open it straight away.
Future<bool?> showProductSheet(BuildContext context, WidgetRef ref, AdminProduct product, {bool photoOnly = false, ValueNotifier<bool>? next}) {
  var featured = product.sortRank > 0;
  var hidden = !product.isActive;
  var category = product.categoryId == null ? null : (id: product.categoryId!, name: product.category ?? 'Category ${product.categoryId}');
  var imageUrl = product.imageUrl;
  var busy = false;
  var changed = false;
  var nextWhenUploaded = false;
  /// White-background clean-up for the next upload: off unless the picker switches it on.
  var clean = false;

  return showActionSheet<bool>(
    context,
    title: product.name,
    fields: {
      'nameTa': product.nameTa ?? '',
      'description': product.description ?? '',
      'name': product.name,
      'brand': product.brand ?? '',
      'packSize': product.packSize ?? '',
    },
    builder: (context, setState, fields) {
      final text = Theme.of(context).textTheme;
      final nameTa = fields['nameTa']!;
      final description = fields['description']!;
      final name = fields['name']!;
      final brand = fields['brand']!;
      final packSize = fields['packSize']!;
      final edited = [
        for (final (f, label) in const [('name', 'name'), ('brand', 'brand'), ('category_id', 'category'), ('pack_size', 'size')])
          if (product.lockedFields.contains(f)) label,
      ];

      Future<void> upload(Uint8List bytes, String type) async {
        final url = await guard(context, () => ref.read(repositoryProvider).uploadPhoto(product.id, bytes, type, clean: clean));
        if (!context.mounted) return;
        setState(() {
          busy = false;
          if (url != null) {
            imageUrl = url;
            changed = true;
          }
        });
        if (url != null) showSnack(context, 'Photo saved — customers see it within a minute');
        // Enter pressed while it was uploading: go on once it's saved.
        if (url != null && nextWhenUploaded && context.mounted) Navigator.pop(context, true);
        nextWhenUploaded = false;
      }

      void goNext() {
        if (next == null) return;
        next.value = true;
        if (busy) {
          nextWhenUploaded = true; // still uploading the pasted photo
        } else {
          Navigator.pop(context, changed);
        }
      }

      Future<void> pick(ImageSource source) async {
        final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
        if (file == null) return;
        final original = await file.readAsBytes();
        final originalType = imageTypeOf(original);
        if (!context.mounted) return;
        if (originalType == null) return showSnack(context, 'Use a JPG, PNG or WebP photo', error: true);
        setState(() => busy = true);
        // Android cuts the product out on the phone; the server then puts it on pure white.
        final (bytes, type) = clean ? await cutOutProduct(file.path, original, originalType) : (original, originalType);
        if (!context.mounted) return;
        await upload(bytes, type);
      }

      /// Website: a picture dragged onto the page or pasted (Ctrl/⌘+V).
      Future<void> dropped(DroppedImage image) async {
        if (busy) return;
        final type = imageTypeOf(image.bytes);
        if (type == null) return showSnack(context, 'Use a JPG, PNG or WebP picture', error: true);
        setState(() => busy = true);
        await upload(image.bytes, type);
      }

      // Typing in Tamil name / description: Enter belongs to the text box.
      void enterNext() {
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused != null && (focused.widget is EditableText || focused.findAncestorWidgetOfExactType<EditableText>() != null)) return;
        goNext();
      }

      // Enter (outside the text fields) → next product: paste, Enter, paste, Enter…
      return CallbackShortcuts(
        bindings: next == null
            ? const {}
            : {const SingleActivator(LogicalKeyboardKey.enter): enterNext, const SingleActivator(LogicalKeyboardKey.numpadEnter): enterNext},
        child: Focus(
        autofocus: true,
        child: ImageDropZone(
        onImage: dropped,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Copy the name to search for a free photo (or to paste anywhere).
          Row(children: [
            Expanded(child: SelectableText(product.name, style: text.titleSmall)),
            IconButton(
              tooltip: 'Copy name',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: product.name));
                if (context.mounted) showSnack(context, 'Name copied');
              },
            ),
          ]),
          Text(
            [product.priceLabel, if (product.packSize != null) product.packSize!].join(' · '),
            style: text.titleSmall?.copyWith(color: AppColors.green800, fontWeight: FontWeight.w700),
          ),
          if (product.barcode != null)
            Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: CopyChip(label: 'EAN', value: product.barcode!))),
          Text(
            [
              if (product.brand != null) product.brand!,
              'Code ${product.itemCode}',
            ].join(' · '),
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          if (product.needsRecheck && imageUrl == product.imageUrl) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  product.photoCheckReason == 'new_code'
                      ? 'Photo copied from this product\'s old code — check it matches the new pack.'
                      : 'New barcode in the stock file — the packaging may have changed.',
                  style: text.titleSmall?.copyWith(color: const Color(0xFF7A4D00)),
                ),
                const SizedBox(height: 2),
                Text('Compare with the pack on the shelf: take a new photo, or keep this one.', style: text.bodySmall),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Photo is still right'),
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          final ok = await guard(context, () async {
                            await ref.read(repositoryProvider).confirmPhoto(product.id);
                            return true;
                          });
                          if (!context.mounted) return;
                          setState(() => busy = false);
                          if (ok == true) Navigator.pop(context, true);
                        },
                ),
              ]),
            ),
          ],
          // Right-click (website) / long-press (phone) → Paste photo.
          PastePhotoTarget(
            enabled: !busy,
            onImage: dropped,
            onError: (message) => showSnack(context, message, error: true),
            child: AspectRatio(
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
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.image_not_supported_outlined, size: 48, color: AppColors.inkFaint),
                        const SizedBox(height: 6),
                        Text(kIsWeb ? 'Right-click here → Paste photo' : 'Long-press here → Paste photo', style: text.bodySmall),
                      ]),
                    )
                  : CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.contain),
            ),
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
          // Some pictures look worse after the clean-up (white parts of the product get eaten): off = as it is.
          SwitchListTile(
            value: clean,
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: busy ? null : (v) => setState(() => clean = v),
            title: const Text('Clean up background (make it white)'),
            subtitle: Text(clean ? 'On: background turned white, picture centred' : 'Off: the next picture is saved exactly as it is'),
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
          Text(
            ImageDropZone.supported
                ? 'Drag a photo onto this window, paste it (Ctrl+V / ⌘+V) or right-click the photo box → Paste photo. It uploads straight away (switch on "Clean up background" first to make the background white).'
                : 'Copied a picture? Long-press the photo box → Paste photo. Or take one in the light box / on plain white paper (switch on "Clean up background" to make it pure white).',
            style: text.bodySmall,
          ),
          if (photoOnly) ...[
            const SizedBox(height: 12),
            if (next != null)
              FilledButton.tonal(onPressed: goNext, child: Text(changed ? 'Next product →  (Enter)' : 'Skip to next product →  (Enter)'))
            else
              FilledButton.tonal(onPressed: () => Navigator.pop(context, changed), child: Text(changed ? 'Done' : 'Close')),
          ],
          if (!photoOnly) ...[
          const Divider(height: 28),
          Text('Shop details', style: text.titleSmall),
          const SizedBox(height: 2),
          Text('Your changes stay when the next stock file is uploaded. Prices and stock always come from the stock file.', style: text.bodySmall),
          const SizedBox(height: 10),
          TextField(
            controller: name,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Name in the shop', counterText: ''),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: brand, maxLength: 120, decoration: const InputDecoration(labelText: 'Brand', counterText: ''))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: packSize, maxLength: 40, decoration: const InputDecoration(labelText: 'Size / pack', hintText: 'e.g. 500 g', counterText: ''))),
          ]),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.category_outlined),
            title: Text(category?.name ?? 'No category'),
            subtitle: const Text('Category — tap to move the product'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final picked = await pickCategory(context, ref, current: category?.id);
              if (picked != null) setState(() => category = picked);
            },
          ),
          SwitchListTile(
            value: hidden,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => hidden = v),
            title: const Text('Hide from the shop'),
            subtitle: const Text('Customers don\'t see it, even after the next stock upload'),
          ),
          if (edited.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.restore_rounded),
                label: Text('Use the stock file\'s ${edited.join(', ')} again'),
                onPressed: busy
                    ? null
                    : () async {
                        setState(() => busy = true);
                        final ok = await guard(context, () async {
                          await ref.read(repositoryProvider).updateProduct(product.id, {
                            'useStockFile': [for (final f in product.lockedFields) if (f != 'is_active') f],
                          });
                          return true;
                        });
                        if (!context.mounted) return;
                        setState(() => busy = false);
                        if (ok == true) {
                          showSnack(context, 'The next stock upload brings back the stock file\'s ${edited.join(', ')}');
                          Navigator.pop(context, true);
                        }
                      },
              ),
            ),
          const SizedBox(height: 4),
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.style_outlined),
            title: Text(product.options == null ? 'Add choices (flavours / designs)' : 'Choices: ${(product.options!['values'] as List).join(', ')}', maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: const Text('One item, several flavours or designs — customers pick one'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ChoicesEditorScreen(product: product)));
              if (saved == true && context.mounted) Navigator.pop(context, true);
            },
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
                    final newName = name.text.trim();
                    if (newName.length < 2) return showSnack(context, 'Enter the product name', error: true);
                    setState(() => busy = true);
                    final ok = await guard(context, () async {
                      await ref.read(repositoryProvider).updateProduct(product.id, {
                        'nameTa': nameTa.text.trim(),
                        'description': description.text.trim(),
                        'sortRank': featured ? (product.sortRank > 0 ? product.sortRank : 100) : 0,
                        if (newName != product.name) 'name': newName,
                        if (brand.text.trim() != (product.brand ?? '')) 'brand': brand.text.trim(),
                        if (packSize.text.trim() != (product.packSize ?? '')) 'packSize': packSize.text.trim(),
                        if (category != null && category!.id != product.categoryId) 'categoryId': category!.id,
                        if (hidden != !product.isActive) 'hidden': hidden,
                      });
                      return true;
                    });
                    if (!context.mounted) return;
                    setState(() => busy = false);
                    if (ok == true) Navigator.pop(context, true);
                  },
            child: const Text('Save details'),
          ),
          if (next != null) TextButton(onPressed: goNext, child: const Text('Next product →')),
          ],
        ],
        ),
      ),
        ),
      );
    },
  ).then((value) => value ?? changed);
}

/// Searchable list of every shop category ("Dairy, Bread & Eggs › Ice Creams").
Future<({int id, String name})?> pickCategory(BuildContext context, WidgetRef ref, {int? current}) {
  return showModalBottomSheet<({int id, String name})>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => _CategoryPicker(current: current),
  );
}

class _CategoryPicker extends ConsumerStatefulWidget {
  const _CategoryPicker({this.current});
  final int? current;

  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  late Future<List<({int id, String name})>> _all = ref.read(repositoryProvider).categoryOptions();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: const InputDecoration(hintText: 'Find a category', prefixIcon: Icon(Icons.search_rounded), isDense: true),
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: _all,
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(message: 'Could not load the categories', onRetry: () => setState(() => _all = ref.read(repositoryProvider).categoryOptions()));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = [for (final c in snap.data!) if (_q.isEmpty || c.name.toLowerCase().contains(_q)) c];
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final sub = c.name.contains(' › ');
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(left: sub ? 32 : 16, right: 16),
                    title: Text(sub ? c.name.split(' › ').last : c.name, style: sub ? text.bodyMedium : text.titleSmall),
                    subtitle: sub ? Text(c.name.substring(0, c.name.lastIndexOf(' › ')), style: text.labelSmall) : null,
                    trailing: c.id == widget.current ? const Icon(Icons.check_rounded, color: AppColors.green600) : null,
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
