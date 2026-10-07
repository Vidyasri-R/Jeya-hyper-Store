import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout.dart';
import 'web_categories.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import 'product_grid.dart';

/// Products per row on phones. 3 = compact cards (preview); 2 = the earlier, roomier layout.
const _productsPerRow = 3;

const _sorts = {'popular': 'Popular', 'price_asc': 'Price: Low to High', 'price_desc': 'Price: High to Low', 'name_asc': 'Name: A–Z'};

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key, this.initialSlug});
  final String? initialSlug;

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _rootSlug;
  String? _childSlug;
  String _sort = 'popular';
  bool _inStock = false;

  @override
  void didUpdateWidget(covariant CategoriesScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialSlug != old.initialSlug) {
      _rootSlug = null;
      _childSlug = null;
    }
  }

  void _resolveInitial(List<Category> roots) {
    if (_rootSlug != null || roots.isEmpty) return;
    final wanted = widget.initialSlug;
    for (final r in roots) {
      if (r.slug == wanted) {
        _rootSlug = r.slug;
        return;
      }
      for (final c in r.children) {
        if (c.slug == wanted) {
          _rootSlug = r.slug;
          _childSlug = c.slug;
          return;
        }
      }
    }
    _rootSlug = roots.first.slug;
  }

  @override
  Widget build(BuildContext context) {
    if (isWideLayout(context)) return WebCategoryPage(initialSlug: widget.initialSlug); // web shop on laptops & tablets
    final categories = ref.watch(categoriesProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          Image.asset('assets/brand/logo_mark.png', height: 30),
          const SizedBox(width: 8),
          Text('Categories', style: text.titleLarge),
        ]),
        actions: [
          IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: categories.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
        data: (roots) {
          if (roots.isEmpty) return const EmptyState(icon: Icons.storefront_outlined, title: 'No categories yet');
          _resolveInitial(roots);
          final root = roots.firstWhere((r) => r.slug == _rootSlug, orElse: () => roots.first);
          final activeSlug = _childSlug ?? root.slug;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Rail(
                roots: roots,
                selected: root.slug,
                onSelect: (slug) => setState(() {
                  _rootSlug = slug;
                  _childSlug = null;
                }),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: ProductGrid(
                  key: ValueKey('$activeSlug|$_sort|$_inStock'),
                  phoneColumns: _productsPerRow,
                  query: (category: activeSlug, q: null, sort: _sort, inStock: _inStock),
                  header: [
                    SliverToBoxAdapter(child: _Banner(category: root)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
                        child: Row(children: [
                          Expanded(child: Text(root.name, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                          Text('${root.productCount} products', style: text.labelSmall),
                        ]),
                      ),
                    ),
                    if (root.children.isNotEmpty)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 46,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                            children: [
                              _Chip(label: 'All', selected: _childSlug == null, onTap: () => setState(() => _childSlug = null)),
                              for (final c in root.children)
                                _Chip(label: c.name, selected: _childSlug == c.slug, onTap: () => setState(() => _childSlug = c.slug)),
                            ],
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Row(children: [
                          _FilterButton(
                            icon: Icons.swap_vert_rounded,
                            label: _sort == 'popular' ? 'Sort' : _sorts[_sort]!,
                            onTap: () async {
                              final picked = await showModalBottomSheet<String>(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                                    for (final e in _sorts.entries)
                                      ListTile(
                                        title: Text(e.value),
                                        trailing: e.key == _sort ? Icon(Icons.check_rounded, color: AppColors.brand700) : null,
                                        onTap: () => Navigator.pop(context, e.key),
                                      ),
                                  ]),
                                ),
                              );
                              if (picked != null) setState(() => _sort = picked);
                            },
                          ),
                          const SizedBox(width: 8),
                          _FilterButton(
                            icon: _inStock ? Icons.check_circle_rounded : Icons.inventory_2_outlined,
                            label: 'In stock',
                            active: _inStock,
                            onTap: () => setState(() => _inStock = !_inStock),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const CartBar(),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.roots, required this.selected, required this.onSelect});
  final List<Category> roots;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: _productsPerRow >= 3 ? 76 : 84,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: roots.length,
        itemBuilder: (_, i) {
          final c = roots[i];
          final active = c.slug == selected;
          final v = categoryVisual(c.name);
          return InkWell(
            onTap: () => onSelect(c.slug),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: active ? AppColors.brand50 : null,
                border: Border(left: BorderSide(color: active ? AppColors.brand700 : Colors.transparent, width: 3)),
              ),
              child: Column(children: [
                c.imageUrl != null
                    ? Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: active ? AppColors.brand700 : Colors.transparent, width: 2),
                        ),
                        child: CategoryPhoto(url: c.imageUrl!, radius: AppRadius.md - 2),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: active ? Colors.white : v.bg, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: Icon(v.icon, color: v.fg, size: 24),
                      ),
                const SizedBox(height: 6),
                Text(c.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: active ? AppColors.brand800 : AppColors.inkMuted,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      height: 1.15,
                    )),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = categoryVisual(category.name);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(colors: [v.bg, Color.lerp(v.bg, v.fg, 0.18)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        if (category.imageUrl != null)
          Positioned(top: 0, right: 0, bottom: 0, width: 130, child: CategoryPhoto(url: category.imageUrl!, radius: 0))
        else
          Positioned(right: -10, bottom: -18, child: Icon(v.icon, size: 130, color: v.fg.withValues(alpha: 0.16))),
        Padding(
          padding: EdgeInsets.fromLTRB(14, 14, category.imageUrl != null ? 140 : 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(category.name, style: text.titleLarge?.copyWith(color: AppColors.brand900, fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 4),
            Text('Fresh stock from Jeya Hyper Store', style: text.bodySmall?.copyWith(color: AppColors.ink)),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: active ? AppColors.brand700 : AppColors.ink,
          side: BorderSide(color: active ? AppColors.brand700 : AppColors.line),
          backgroundColor: active ? AppColors.brand50 : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
      );
}
