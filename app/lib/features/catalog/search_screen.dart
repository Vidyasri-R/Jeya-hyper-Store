import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../state/recent_searches.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image.dart';
import 'product_grid.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  final _focus = FocusNode();
  Timer? _debounce;
  List<Suggestion> _suggestions = const [];
  String? _submitted;

  @override
  void initState() {
    super.initState();
    _submitted = widget.initialQuery;
    if (_submitted == null) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() => _submitted = null);
    final q = value.trim();
    if (q.length < 2) return setState(() => _suggestions = const []);
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final s = await ref.read(repositoryProvider).suggest(q);
        if (mounted && _controller.text.trim() == q) setState(() => _suggestions = s);
      } catch (_) {
        // Suggestions are a nicety; ignore failures.
      }
    });
  }

  void _submit(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(query);
    _controller.text = query;
    _focus.unfocus();
    setState(() {
      _submitted = query;
      _suggestions = const [];
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    ref.watch(recentSearchesProvider);
    final recent = ref.read(recentSearchesProvider.notifier).matching(_controller.text);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _submit,
            decoration: InputDecoration(
              hintText: 'Search rice, oil, milk…',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                        _focus.requestFocus();
                      },
                    ),
              fillColor: AppColors.bg,
            ),
          ),
        ),
      ),
      body: _submitted != null
          ? ProductGrid(
              key: ValueKey(_submitted),
              query: (category: null, q: _submitted, sort: null, inStock: false),
              emptyTitle: 'No results for "$_submitted"',
              header: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Results for "$_submitted"', style: text.titleSmall),
                  ),
                ),
              ],
            )
          : ListView(
              children: [
                if (recent.isNotEmpty && _controller.text.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                    child: Row(children: [
                      Expanded(child: Text('Recent searches', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                      TextButton(onPressed: () => ref.read(recentSearchesProvider.notifier).clear(), child: const Text('Clear')),
                    ]),
                  ),
                for (final r in recent)
                  ListTile(
                    leading: const Icon(Icons.history_rounded, color: AppColors.inkMuted),
                    title: Text(r, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'Remove from history',
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkFaint),
                      onPressed: () => ref.read(recentSearchesProvider.notifier).remove(r),
                    ),
                    onTap: () => _submit(r),
                  ),
                for (final s in _suggestions)
                  ListTile(
                    leading: ProductImage(url: s.imageUrl, placeholderUrl: s.placeholderImageUrl, name: s.name, size: 44, radius: AppRadius.sm),
                    title: Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'Search for this',
                      icon: const Icon(Icons.north_west_rounded, size: 18, color: AppColors.inkFaint),
                      onPressed: () => _submit(s.name),
                    ),
                    onTap: () {
                      ref.read(recentSearchesProvider.notifier).add(_controller.text);
                      context.push('/product/${s.slug}');
                    },
                  ),
                if (_suggestions.isEmpty && _controller.text.trim().isEmpty) ...[
                  const SectionHeader(title: 'Popular searches'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final s in const ['Ponni rice', 'Toor dal', 'Sunflower oil', 'Biscuits', 'Atta', 'Sugar', 'Soap', 'Tea'])
                        ActionChip(label: Text(s), onPressed: () => _submit(s)),
                    ]),
                  ),
                ],
              ],
            ),
    );
  }
}
