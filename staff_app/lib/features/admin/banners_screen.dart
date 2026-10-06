import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'brand_colour_card.dart';

/// Admin → Home banners: the carousel at the top of the customer app's Home (public config
/// `home.banners`). Up to [maxBanners]; an empty list brings back the app's built-in banners.
/// Festival banners (Store settings → Festival theme) still show first on their dates.
const maxBanners = 8;

/// Soft and deep card colours for text banners (null = the brand's soft colour).
const bannerColours = <(String, String?)>[
  ('Brand', null),
  ('Cream', '#FFF4DC'),
  ('Sky', '#E8EEFA'),
  ('Rose', '#FDE8E8'),
  ('Mint', '#EFF8F1'),
  ('Lavender', '#F3EAFB'),
  ('Deep blue', '#1E4FA8'),
  ('Maroon', '#8E1B2E'),
];

String newBannerId() {
  final r = Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return 'b-${List.generate(10, (_) => chars[r.nextInt(chars.length)]).join()}';
}

Map<String, dynamic> blankBanner() => {
      'id': newBannerId(),
      'active': true,
      'image': null,
      'tag': null,
      'title': null,
      'subtitle': null,
      'cta': 'Shop now',
      'background': null,
      'link': {'type': 'none'},
      'startsAt': null,
      'endsAt': null,
    };

String _day(DateTime d) => DateFormat('d MMM').format(d);
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// One line on when a banner shows.
String bannerWhen(Map<String, dynamic> b, DateTime now) {
  if (b['active'] != true) return 'Off';
  final from = _date(b['startsAt']), until = _date(b['endsAt']);
  if (until != null && now.isAfter(until)) return 'Ended ${_day(until)}';
  if (from != null && now.isBefore(from)) return 'Starts ${_day(from)}${until != null ? ' · ends ${_day(until)}' : ''}';
  return until != null ? 'Live until ${_day(until)}' : 'Live';
}

/// One line on where a tap goes.
String bannerLink(Map<String, dynamic> b) {
  final link = Map<String, dynamic>.from((b['link'] as Map?) ?? const {});
  return switch (link['type']) {
    'search' => 'Opens search: “${link['value']}”',
    'category' => 'Opens category: ${link['label'] ?? link['value']}',
    'product' => 'Opens product: ${link['label'] ?? link['value']}',
    _ => 'No link',
  };
}

/// What the server stores: the editor keeps a `label` for pickers, the server doesn't.
Map<String, dynamic> forServer(Map<String, dynamic> b) {
  final link = Map<String, dynamic>.from((b['link'] as Map?) ?? const {'type': 'none'})..remove('label');
  return {...b, 'link': link['type'] == 'none' ? {'type': 'none'} : link};
}

class BannersScreen extends ConsumerStatefulWidget {
  const BannersScreen({super.key});

  @override
  ConsumerState<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends ConsumerState<BannersScreen> {
  List<Map<String, dynamic>>? _banners;
  Color _brand = const Color(0xFF1B7A3E);
  String? _error;
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await ref.read(repositoryProvider).settings();
      final raw = settings['home.banners'];
      final brand = settings['app.brand'];
      if (!mounted) return;
      setState(() {
        _banners = [for (final b in (raw is List ? raw : const [])) Map<String, dynamic>.from(b as Map)];
        _brand = parseHex(brand is Map ? brand['color'] as String? ?? '' : '') ?? _brand;
        _error = null;
        _dirty = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.friendly);
    }
  }

  void _change(void Function(List<Map<String, dynamic>>) edit) => setState(() {
        edit(_banners!);
        _dirty = true;
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await guard(context, () => ref.read(repositoryProvider).saveSetting('home.banners', [for (final b in _banners!) forServer(b)]));
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved != null) _dirty = false;
    });
    if (saved != null) showSnack(context, 'Banners saved — customers see them the next time they open the app');
  }

  Future<void> _edit({int? index}) async {
    final start = index == null ? blankBanner() : Map<String, dynamic>.from(_banners![index]);
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => BannerEditorScreen(banner: start, brand: _brand, isNew: index == null)),
    );
    if (result == null) return;
    _change((list) => index == null ? list.add(result) : list[index] = result);
  }

  @override
  Widget build(BuildContext context) {
    final list = _banners;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave without saving?'),
            content: const Text('Your banner changes are not saved yet.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Home banners')),
        floatingActionButton: list == null || list.length >= maxBanners
            ? null
            : FloatingActionButton.extended(onPressed: () => _edit(), icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Add banner')),
        bottomNavigationBar: list == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(onPressed: !_dirty || _saving ? null : _save, child: Text(_saving ? 'Saving…' : (_dirty ? 'Save banners' : 'All changes saved'))),
                ),
              ),
        body: list == null
            ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
            : list.isEmpty
                ? const EmptyView(
                    icon: Icons.view_carousel_outlined,
                    title: 'No banners yet',
                    subtitle: 'Customers see the app’s built-in banners. Add your own offers, festival pictures or announcements.',
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    header: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('Shown in this order (drag ≡ to reorder). ${list.length} of $maxBanners.', style: text.bodySmall),
                    ),
                    itemCount: list.length,
                    onReorder: (from, to) => _change((l) => l.insert(to > from ? to - 1 : to, l.removeAt(from))),
                    itemBuilder: (context, i) {
                      final b = list[i];
                      return Padding(
                        key: ValueKey(b['id']),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SectionCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            BannerPreview(banner: b, brand: _brand, height: 120),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(bannerWhen(b, now), style: text.labelLarge),
                                  Text(bannerLink(b), style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ]),
                              ),
                              Switch(
                                value: b['active'] == true,
                                onChanged: (v) => _change((l) => l[i] = {...b, 'active': v}),
                              ),
                            ]),
                            Row(children: [
                              TextButton.icon(onPressed: () => _edit(index: i), icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
                              TextButton.icon(
                                onPressed: () => _change((l) => l.removeAt(i)),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Remove'),
                              ),
                              const Spacer(),
                              ReorderableDragStartListener(index: i, child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded))),
                            ]),
                          ]),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

/// What the banner looks like in the customer app's Home carousel (same layout rules).
class BannerPreview extends StatelessWidget {
  const BannerPreview({super.key, required this.banner, required this.brand, this.height = 150});
  final Map<String, dynamic> banner;
  final Color brand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shades = brandShades(brand);
    String? str(String k) => banner[k] is String && (banner[k] as String).trim().isNotEmpty ? (banner[k] as String).trim() : null;
    final image = str('image'), title = str('title'), tag = str('tag'), subtitle = str('subtitle'), cta = str('cta');
    final hasLink = ((banner['link'] as Map?)?['type'] ?? 'none') != 'none';
    final bg = parseHex(str('background') ?? '') ?? shades.soft;
    final onPhoto = image != null;
    final dark = !onPhoto && bg.computeLuminance() < 0.4;
    final ink = onPhoto || dark ? Colors.white : shades.dark;
    final scale = height / 176;

    Widget? picture;
    if (image != null) picture = CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, placeholder: (_, _) => ColoredBox(color: shades.soft));

    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18 * scale + 4)),
        clipBehavior: Clip.antiAlias,
        child: image != null && title == null
            ? picture
            : Stack(fit: StackFit.expand, children: [
                if (picture != null) ...[
                  picture,
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xCC000000), Color(0x66000000), Color(0x00000000)], stops: [0, 0.55, 1]))),
                ],
                Padding(
                  padding: EdgeInsets.all(14 * scale + 2),
                  child: FittedBox(
                    alignment: Alignment.topLeft,
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 300,
                      height: 148,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (tag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: onPhoto ? Colors.white : shades.button, borderRadius: BorderRadius.circular(20)),
                            child: Text(tag.toUpperCase(), style: text.labelSmall?.copyWith(color: onPhoto ? shades.dark : Colors.white, fontWeight: FontWeight.w800)),
                          ),
                        if (tag != null) const SizedBox(height: 8),
                        Text(title ?? 'Add a title or a picture', maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleLarge?.copyWith(color: ink, fontWeight: FontWeight.w800, height: 1.1)),
                        if (subtitle != null) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: onPhoto || dark ? Colors.white : null)),
                        const Spacer(),
                        if (cta != null && hasLink)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(color: onPhoto ? Colors.white : shades.headerStart, borderRadius: BorderRadius.circular(20)),
                            child: Text('$cta →', style: text.labelLarge?.copyWith(color: onPhoto ? shades.dark : Colors.white, fontWeight: FontWeight.w700)),
                          ),
                      ]),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }
}

class BannerEditorScreen extends ConsumerStatefulWidget {
  const BannerEditorScreen({super.key, required this.banner, required this.brand, required this.isNew});
  final Map<String, dynamic> banner;
  final Color brand;
  final bool isNew;

  @override
  ConsumerState<BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends ConsumerState<BannerEditorScreen> {
  late final Map<String, dynamic> _b = Map<String, dynamic>.from(widget.banner);
  late final Map<String, dynamic> _link = Map<String, dynamic>.from((_b['link'] as Map?) ?? const {'type': 'none'});
  late final _fields = {
    for (final k in ['tag', 'title', 'subtitle', 'cta']) k: TextEditingController(text: (_b[k] as String?) ?? ''),
  };
  late final _search = TextEditingController(text: _link['type'] == 'search' ? (_link['value'] as String? ?? '') : '');
  bool _uploading = false;
  List<({String slug, String name})>? _categories;

  @override
  void initState() {
    super.initState();
    for (final e in _fields.entries) {
      e.value.addListener(() => setState(() => _b[e.key] = e.value.text.trim().isEmpty ? null : e.value.text.trim()));
    }
    _search.addListener(() => setState(() => _link['value'] = _search.text.trim()));
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _search.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _current => {..._b, 'link': _link['type'] == 'none' ? {'type': 'none'} : Map<String, dynamic>.from(_link)};

  String? get _problem {
    if (_b['image'] == null && _b['title'] == null) return 'Add a picture or a title';
    final type = _link['type'];
    if (type != 'none' && ((_link['value'] as String?) ?? '').isEmpty) {
      return switch (type) { 'search' => 'Type what to search for', 'category' => 'Pick a category', _ => 'Pick a product' };
    }
    final from = _date(_b['startsAt']), until = _date(_b['endsAt']);
    if (from != null && until != null && !until.isAfter(from)) return 'End date must be after the start date';
    return null;
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 2400, maxHeight: 2400, imageQuality: 88);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final type = imageTypeOf(bytes);
    if (!mounted) return;
    if (type == null) return showSnack(context, 'Use a JPG, PNG or WebP picture', error: true);
    setState(() => _uploading = true);
    final url = await guard(context, () => ref.read(repositoryProvider).uploadBannerImage(bytes, type));
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _b['image'] = url;
    });
  }

  Future<void> _pickCategory() async {
    _categories ??= await guard(context, () => ref.read(repositoryProvider).bannerCategories());
    if (!mounted || _categories == null) return;
    final picked = await showModalBottomSheet<({String slug, String name})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: ListView(children: [
            const ListTile(title: Text('Open which category?')),
            for (final c in _categories!) ListTile(title: Text(c.name), onTap: () => Navigator.pop(context, c)),
          ]),
        ),
      ),
    );
    if (picked != null) setState(() => _link..['value'] = picked.slug..['label'] = picked.name);
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<({String slug, String name})>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ProductPicker(search: ref.read(repositoryProvider).bannerProducts),
    );
    if (picked != null) setState(() => _link..['value'] = picked.slug..['label'] = picked.name);
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final current = _date(start ? _b['startsAt'] : _b['endsAt']);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 400)),
      helpText: start ? 'Show the banner from' : 'Show the banner until',
    );
    if (picked == null) return;
    setState(() {
      final at = start ? DateTime(picked.year, picked.month, picked.day) : DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      _b[start ? 'startsAt' : 'endsAt'] = at.toUtc().toIso8601String();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final problem = _problem;
    final type = _link['type'] as String? ?? 'none';
    final from = _date(_b['startsAt']), until = _date(_b['endsAt']);
    return Scaffold(
      appBar: AppBar(title: Text(widget.isNew ? 'New banner' : 'Edit banner')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (problem != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(problem, style: text.bodySmall, textAlign: TextAlign.center)),
            FilledButton(onPressed: problem == null && !_uploading ? () => Navigator.pop(context, _current) : null, child: const Text('Done')),
          ]),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Preview', style: text.labelLarge),
        const SizedBox(height: 6),
        BannerPreview(banner: _current, brand: widget.brand),
        const SizedBox(height: 18),

        Text('Picture (optional)', style: text.titleSmall),
        Text('Wide pictures work best (2 : 1, e.g. 1200 × 600). With no title, the picture is the whole banner.', style: text.bodySmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(onPressed: _uploading ? null : () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Choose picture')),
          OutlinedButton.icon(onPressed: _uploading ? null : () => _pickImage(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera')),
          if (_b['image'] != null) TextButton.icon(onPressed: () => setState(() => _b['image'] = null), icon: const Icon(Icons.hide_image_outlined), label: const Text('Remove picture')),
          if (_uploading) const Padding(padding: EdgeInsets.all(8), child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        ]),
        const SizedBox(height: 18),

        Text('Text', style: text.titleSmall),
        const SizedBox(height: 8),
        TextField(controller: _fields['tag'], maxLength: 24, decoration: const InputDecoration(labelText: 'Small tag (optional)', hintText: 'DIWALI OFFER')),
        TextField(controller: _fields['title'], maxLength: 60, decoration: const InputDecoration(labelText: 'Title', hintText: 'Sweets & snacks')),
        TextField(controller: _fields['subtitle'], maxLength: 90, decoration: const InputDecoration(labelText: 'Line under the title (optional)', hintText: 'Murukku, laddoo & more')),
        TextField(controller: _fields['cta'], maxLength: 20, decoration: const InputDecoration(labelText: 'Button text', hintText: 'Shop now', helperText: 'Shown when the banner opens something')),
        const SizedBox(height: 12),

        if (_b['image'] == null) ...[
          Text('Card colour', style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (name, hex) in bannerColours)
              ChoiceChip(
                label: Text(name),
                avatar: CircleAvatar(backgroundColor: parseHex(hex ?? '') ?? brandShades(widget.brand).soft),
                selected: _b['background'] == hex,
                onSelected: (_) => setState(() => _b['background'] = hex),
              ),
          ]),
          const SizedBox(height: 18),
        ],

        Text('When tapped', style: text.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'none', label: Text('Nothing')),
            ButtonSegment(value: 'search', label: Text('Search')),
            ButtonSegment(value: 'category', label: Text('Category')),
            ButtonSegment(value: 'product', label: Text('Product')),
          ],
          selected: {type},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() {
            _link
              ..clear()
              ..['type'] = s.first;
            if (s.first == 'search') _link['value'] = _search.text.trim();
          }),
        ),
        const SizedBox(height: 10),
        if (type == 'search') TextField(controller: _search, maxLength: 60, decoration: const InputDecoration(labelText: 'Search for', hintText: 'sweets')),
        if (type == 'category')
          OutlinedButton.icon(onPressed: _pickCategory, icon: const Icon(Icons.category_outlined), label: Text((_link['label'] ?? _link['value'] ?? 'Pick a category') as String)),
        if (type == 'product')
          OutlinedButton.icon(onPressed: _pickProduct, icon: const Icon(Icons.inventory_2_outlined), label: Text((_link['label'] ?? _link['value'] ?? 'Pick a product') as String)),
        const SizedBox(height: 18),

        Text('When to show (optional)', style: text.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          InputChip(
            label: Text(from == null ? 'From: now' : 'From ${DateFormat('EEE d MMM').format(from)}'),
            onPressed: () => _pickDate(start: true),
            onDeleted: from == null ? null : () => setState(() => _b['startsAt'] = null),
          ),
          InputChip(
            label: Text(until == null ? 'Until: you turn it off' : 'Until ${DateFormat('EEE d MMM').format(until)}'),
            onPressed: () => _pickDate(start: false),
            onDeleted: until == null ? null : () => setState(() => _b['endsAt'] = null),
          ),
        ]),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.search});
  final Future<List<({String slug, String name})>> Function(String) search;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  List<({String slug, String name})> _results = const [];
  String _query = '';
  bool _busy = false;

  Future<void> _run(String q) async {
    _query = q.trim();
    if (_query.length < 2) return setState(() => _results = const []);
    setState(() => _busy = true);
    try {
      final results = await widget.search(_query);
      if (mounted && q.trim() == _query) setState(() => _results = results);
    } on ApiException {
      if (mounted) setState(() => _results = const []);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(labelText: 'Find the product', prefixIcon: const Icon(Icons.search_rounded), suffixIcon: _busy ? const Padding(padding: EdgeInsets.all(12), child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null),
                onChanged: _run,
              ),
            ),
            Expanded(
              child: ListView(children: [
                for (final p in _results) ListTile(title: Text(p.name), onTap: () => Navigator.pop(context, p)),
                if (_results.isEmpty && _query.length >= 2 && !_busy) const ListTile(title: Text('No products found')),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
