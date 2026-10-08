import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/web_frame.dart';
import '../../widgets/web_product_card.dart';

/// Web shop category page (laptops/tablets): category sidebar with the in-stock filter, a title
/// banner, sort, and a grid of product cards that loads more as you scroll.
class WebCategoryPage extends ConsumerStatefulWidget {
  const WebCategoryPage({super.key, this.initialSlug});
  final String? initialSlug;
  @override
  ConsumerState<WebCategoryPage> createState() => _WebCategoryPageState();
}

class _WebCategoryPageState extends ConsumerState<WebCategoryPage> {
  String? _rootSlug;
  String? _childSlug;
  String _sort = 'popular';
  bool _inStock = false;

  @override
  void didUpdateWidget(covariant WebCategoryPage old) {
    super.didUpdateWidget(old);
    if (widget.initialSlug != old.initialSlug) {
      _rootSlug = null;
      _childSlug = null;
    }
  }

  void _resolve(List<Category> roots) {
    if (_rootSlug != null || roots.isEmpty) return;
    for (final r in roots) {
      if (r.slug == widget.initialSlug) {
        _rootSlug = r.slug;
        return;
      }
      for (final c in r.children) {
        if (c.slug == widget.initialSlug) {
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
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: categories.when(
        loading: () => Center(child: CircularProgressIndicator(color: AppColors.brand700)),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
        data: (roots) {
          if (roots.isEmpty) return const EmptyState(icon: Icons.storefront_outlined, title: 'No categories yet');
          _resolve(roots);
          final root = roots.firstWhere((r) => r.slug == _rootSlug, orElse: () => roots.first);
          final child = root.children.where((c) => c.slug == _childSlug).firstOrNull;
          final active = child ?? root;
          final query = (category: active.slug, q: null, sort: _sort, inStock: _inStock);
          final sidebar = _Sidebar(
            roots: roots,
            root: root,
            childSlug: _childSlug,
            inStock: _inStock,
            onRoot: (slug) => setState(() {
              _rootSlug = slug;
              _childSlug = null;
            }),
            onChild: (slug) => setState(() => _childSlug = slug),
            onInStock: (v) => setState(() => _inStock = v),
          );
          return LayoutBuilder(builder: (context, c) {
            final showSidebar = c.maxWidth >= 960;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (showSidebar) SizedBox(width: 260, child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 16, 0, 24), child: sidebar)),
              Expanded(
                child: _Results(
                  key: ValueKey(query),
                  query: query,
                  root: root,
                  active: active,
                  sort: _sort,
                  onSort: (s) => setState(() => _sort = s),
                  chips: showSidebar ? null : root,
                  childSlug: _childSlug,
                  onChild: (slug) => setState(() => _childSlug = slug),
                ),
              ),
            ]);
          });
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.roots,
    required this.root,
    required this.childSlug,
    required this.inStock,
    required this.onRoot,
    required this.onChild,
    required this.onInStock,
  });
  final List<Category> roots;
  final Category root;
  final String? childSlug;
  final bool inStock;
  final void Function(String) onRoot;
  final void Function(String?) onChild;
  final void Function(bool) onInStock;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget item(String label, {required bool selected, required VoidCallback onTap, bool bold = false, double indent = 0}) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.fromLTRB(10 + indent, 9, 10, 9),
            decoration: BoxDecoration(color: selected ? AppColors.brand50 : null, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Expanded(
                child: Text(label,
                    style: (bold ? text.titleSmall : text.bodyMedium)?.copyWith(
                      fontWeight: selected || bold ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.brand800 : AppColors.ink,
                    )),
              ),
              if (!bold) Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkFaint),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final r in roots) ...[
            item(r.name, selected: r.slug == root.slug && childSlug == null, bold: true, onTap: () => onRoot(r.slug)),
            if (r.slug == root.slug)
              for (final c in r.children) item(c.name, selected: c.slug == childSlug, indent: 10, onTap: () => onChild(c.slug)),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      _Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Availability', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          CheckboxListTile(
            value: inStock,
            onChanged: (v) => onInStock(v ?? false),
            title: const Text('In stock only'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ]),
      ),
    ]);
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
        child: child,
      );
}

class _Results extends ConsumerWidget {
  const _Results({
    super.key,
    required this.query,
    required this.root,
    required this.active,
    required this.sort,
    required this.onSort,
    required this.chips,
    required this.childSlug,
    required this.onChild,
  });
  final ProductQuery query;
  final Category root;
  final Category active;
  final String sort;
  final void Function(String) onSort;
  final Category? chips; // sub-category chips when there's no sidebar (tablets)
  final String? childSlug;
  final void Function(String?) onChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final state = ref.watch(productListProvider(query));
    final controller = ref.read(productListProvider(query).notifier);
    final rules = ref.watch(storeRulesProvider);
    final speed = ref.watch(deliverySpeedProvider);
    final free = rules.freeAbovePaise;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 800) controller.loadMore();
        return false;
      },
      child: CustomScrollView(slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverList.list(children: [
            // breadcrumb
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              TextButton(onPressed: () => context.go('/home'), style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)), child: const Text('Home')),
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkFaint),
              TextButton(onPressed: () => onChild(null), style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)), child: Text(root.name)),
              if (active != root) ...[
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkFaint),
                Text(active.name, style: text.labelLarge),
              ],
            ]),
            const SizedBox(height: 8),
            // title banner
            Container(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(colors: [AppColors.brand900, AppColors.brand700], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(active.name, style: text.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Fresh stock from Jeya Hyper Store, Trichy', style: text.titleSmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 16),
                Wrap(spacing: 28, runSpacing: 10, children: [
                  for (final (icon, title, sub) in [
                    (Icons.local_shipping_outlined, speed.headline, 'From our own store'),
                    if (free != null && free > 0) (Icons.savings_outlined, 'Free delivery', 'Above ${formatPaise(free)}'),
                    (Icons.replay_rounded, 'Easy returns', 'Report within 24 hours'),
                  ])
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text(sub, style: text.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                      ]),
                    ]),
                ]),
                ])),
                if (active.tileImageUrl ?? root.tileImageUrl case final picture?)
                  Container(
                    width: 150,
                    height: 130,
                    margin: const EdgeInsets.only(left: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    clipBehavior: Clip.antiAlias,
                    child: CategoryPicture(url: picture, padding: 6, fallback: const SizedBox.shrink()),
                  )
                else if (categoryArt(active.name) ?? categoryArt(root.name) case final art?)
                  Container(
                    width: 150,
                    height: 130,
                    margin: const EdgeInsets.only(left: 16),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(16)),
                    child: Image.asset(art, fit: BoxFit.contain),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            if (chips != null && chips!.children.isNotEmpty) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(label: const Text('All'), selected: childSlug == null, onSelected: (_) => onChild(null), showCheckmark: false),
                for (final c in chips!.children) ChoiceChip(label: Text(c.name), selected: childSlug == c.slug, onSelected: (_) => onChild(c.slug), showCheckmark: false),
              ]),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Text(active.name, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Text('(${active.productCount} products)', style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
              const Spacer(),
              Text('Sort by', style: text.bodyMedium),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: sort,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(10),
                items: const [
                  DropdownMenuItem(value: 'popular', child: Text('Popularity')),
                  DropdownMenuItem(value: 'price_asc', child: Text('Price: low to high')),
                  DropdownMenuItem(value: 'price_desc', child: Text('Price: high to low')),
                  DropdownMenuItem(value: 'name_asc', child: Text('Name: A to Z')),
                ],
                onChanged: (v) => v == null ? null : onSort(v),
              ),
            ]),
            const SizedBox(height: 12),
          ]),
        ),
        if (state.items.isEmpty && state.loading)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
        else if (state.items.isEmpty && state.error != null)
          SliverToBoxAdapter(child: ErrorRetry(error: state.error!, onRetry: () => ref.invalidate(productListProvider(query))))
        else if (state.items.isEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: EmptyState(icon: Icons.search_off_rounded, title: 'No products here yet')))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverLayoutBuilder(builder: (context, constraints) {
              const gap = 14.0;
              final cols = ((constraints.crossAxisExtent + gap) / (190 + gap)).floor().clamp(2, 6);
              final w = (constraints.crossAxisExtent - gap * (cols - 1)) / cols;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: gap, mainAxisSpacing: gap, mainAxisExtent: w / 1.15 + 178),
                delegate: SliverChildBuilderDelegate((_, i) => WebProductCard(product: state.items[i]), childCount: state.items.length),
              );
            }),
          ),
        if (state.items.isNotEmpty && !state.done)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
        if (state.items.isNotEmpty && state.done)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Showing all ${state.items.length} products', style: text.bodySmall)),
            ),
          ),
        const SliverToBoxAdapter(child: WebFooter()),
      ]),
    );
  }
}
