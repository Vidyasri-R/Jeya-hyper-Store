import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/api_client.dart';
import '../../core/photo_cutout.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';

/// Admin → product → Choices: one POS item that is really several products — ice-cream flavours
/// at one MRP, pens labelled "Pen MRP 10" in different designs. Customers must pick one (by name
/// and photo) and packers see what was picked. Stock stays the POS item's.
class ChoicesEditorScreen extends ConsumerStatefulWidget {
  const ChoicesEditorScreen({super.key, required this.product});
  final AdminProduct product;

  @override
  ConsumerState<ChoicesEditorScreen> createState() => _ChoicesEditorScreenState();
}

class _Choice {
  _Choice(String name, this.image) : name = TextEditingController(text: name);
  final TextEditingController name;
  String? image;
}

const _labels = ['Flavour', 'Design', 'Colour', 'Type', 'Variety'];

class _ChoicesEditorScreenState extends ConsumerState<ChoicesEditorScreen> {
  late String _label = (widget.product.options?['label'] as String?) ?? 'Flavour';
  late final List<_Choice> _choices = [
    for (final v in (widget.product.options?['values'] as List? ?? const []))
      _Choice(v.toString(), ((widget.product.options?['images'] as Map?) ?? const {})[v]?.toString()),
  ];
  /// Off unless the admin ticks it: choices usually belong to one size only (e.g. just Arun ₹10).
  bool _allSizes = false;
  late int _othersWithChoices = widget.product.otherSizesWithChoices;
  int? _uploading;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (_choices.isEmpty) _choices.addAll([_Choice('', null), _Choice('', null)]);
  }

  @override
  void dispose() {
    for (final c in _choices) {
      c.name.dispose();
    }
    super.dispose();
  }

  Future<void> _photo(int i, ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (file == null) return;
    final original = await file.readAsBytes();
    final type = imageTypeOf(original);
    if (!mounted) return;
    if (type == null) return showSnack(context, 'Use a JPG, PNG or WebP photo', error: true);
    setState(() => _uploading = i);
    final (bytes, outType) = await cutOutProduct(file.path, original, type);
    if (!mounted) return;
    final url = await guard(context, () => ref.read(repositoryProvider).uploadChoicePhoto(widget.product.id, bytes, outType));
    if (!mounted) return;
    setState(() {
      _uploading = null;
      if (url != null) _choices[i].image = url;
    });
  }

  Future<void> _save({bool remove = false}) async {
    final named = [for (final c in _choices) if (c.name.text.trim().isNotEmpty) c];
    final names = [for (final c in named) c.name.text.trim()];
    if (!remove) {
      if (names.length < 2) return showSnack(context, 'Add at least two choices (or remove choices)', error: true);
      if (names.map((n) => n.toLowerCase()).toSet().length != names.length) return showSnack(context, 'Two choices have the same name', error: true);
    }
    final options = remove
        ? null
        : {
            'label': _label,
            'values': names,
            'images': {for (final c in named) if (c.image != null) c.name.text.trim(): c.image},
          };
    setState(() => _saving = true);
    try {
      final n = await ref.read(repositoryProvider).saveChoices(widget.product.id, options, allSizes: _allSizes && widget.product.variantGroup != null);
      if (!mounted) return;
      showSnack(context, remove ? 'Choices removed' : (n > 1 ? 'Choices saved for $n sizes' : 'Choices saved'));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.friendly, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearOthers() async {
    setState(() => _saving = true);
    try {
      final n = await ref.read(repositoryProvider).clearOtherSizesChoices(widget.product.id);
      if (!mounted) return;
      setState(() => _othersWithChoices = 0);
      showSnack(context, 'Choices removed from $n other ${n == 1 ? 'size' : 'sizes'}');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.friendly, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = widget.product;
    final had = p.options != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Choices')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
        Text(p.name, style: text.titleMedium),
        Text('Code ${p.itemCode}${p.variantLabel != null ? ' · size ${p.variantLabel}' : ''}', style: text.bodySmall),
        const SizedBox(height: 10),
        Text(
          'For one item in GoFrugal that is really several products — e.g. ice creams at the same MRP, or "Pen MRP 10" in different designs. '
          'Customers must pick one (by name and photo); packers see what was picked. Stock stays the item\'s.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 14),
        Text('Customers choose a…', style: text.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          for (final l in _labels) ChoiceChip(label: Text(l), selected: _label == l, onSelected: (_) => setState(() => _label = l)),
        ]),
        const SizedBox(height: 16),
        for (var i = 0; i < _choices.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                InkWell(
                  onTap: _uploading != null ? null : () => _photo(i, kIsWeb ? ImageSource.gallery : ImageSource.camera),
                  onLongPress: kIsWeb ? null : () => _photo(i, ImageSource.gallery),
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _uploading == i
                          ? const Center(child: CircularProgressIndicator())
                          : _choices[i].image != null
                          ? CachedNetworkImage(imageUrl: _choices[i].image!, fit: BoxFit.contain)
                          : const ColoredBox(color: AppColors.bg, child: Icon(Icons.add_a_photo_outlined, color: AppColors.inkMuted)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _choices[i].name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 40,
                    decoration: InputDecoration(labelText: '$_label ${i + 1}', hintText: _label == 'Flavour' ? 'e.g. Vanilla' : 'e.g. Blue gel pen', counterText: ''),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _choices.removeAt(i).name.dispose()),
                ),
              ]),
            ),
          ),
        TextButton.icon(
          onPressed: _choices.length >= 30 ? null : () => setState(() => _choices.add(_Choice('', null))),
          icon: const Icon(Icons.add_rounded),
          label: Text('Add a ${_label.toLowerCase()}'),
        ),
        Text(kIsWeb ? 'Tap the photo box to upload a picture.' : 'Tap the photo box to take a picture (long-press to pick from the gallery).', style: text.bodySmall),
        if (p.variantGroup != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _allSizes,
            onChanged: (v) => setState(() => _allSizes = v ?? false),
            title: const Text('Also for every other size / price of this product'),
            subtitle: Text(_allSizes ? 'Every size gets these choices' : 'Only ${p.variantLabel ?? 'this one'} gets these choices'),
          ),
        if (_othersWithChoices > 0)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_othersWithChoices other ${_othersWithChoices == 1 ? 'size has' : 'sizes have'} choices too', style: text.titleSmall?.copyWith(color: const Color(0xFF7A4D00))),
              const SizedBox(height: 2),
              Text('Added there by mistake? Take them off the other sizes — this one keeps its choices.', style: text.bodySmall),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                icon: const Icon(Icons.layers_clear_outlined),
                label: const Text('Remove from the other sizes'),
                onPressed: _saving ? null : _clearOthers,
              ),
            ]),
          ),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            if (had) ...[
              OutlinedButton(onPressed: _saving ? null : () => _save(remove: true), child: const Text('Remove choices')),
              const SizedBox(width: 10),
            ],
            Expanded(child: FilledButton(onPressed: _saving || _uploading != null ? null : _save, child: const Text('Save choices'))),
          ]),
        ),
      ),
    );
  }
}
