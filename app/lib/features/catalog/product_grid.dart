import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/product_card.dart';

/// Infinite-scroll product grid for any (category, search, sort) query.
class ProductGrid extends ConsumerWidget {
  const ProductGrid({super.key, required this.query, this.header = const [], this.emptyTitle = 'No products here yet'});

  final ProductQuery query;
  final List<Widget> header;
  final String emptyTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productListProvider(query));
    final controller = ref.read(productListProvider(query).notifier);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) controller.loadMore();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          ...header,
          if (state.items.isEmpty && state.loading)
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: productGridDelegate(context),
                delegate: SliverChildBuilderDelegate((_, _) => const ShimmerBox(), childCount: 6),
              ),
            )
          else if (state.items.isEmpty && state.error != null)
            SliverFillRemaining(hasScrollBody: false, child: ErrorRetry(error: state.error!, onRetry: () => ref.invalidate(productListProvider(query))))
          else if (state.items.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.search_off_rounded, title: emptyTitle))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent > 520 ? 3 : 2;
                  final colWidth = (constraints.crossAxisExtent - 10 * (columns - 1)) / columns;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: colWidth + 132, // square image + name/size/price/button
                    ),
                    delegate: SliverChildBuilderDelegate((_, i) => ProductCard(product: state.items[i]), childCount: state.items.length),
                  );
                },
              ),
            ),
          if (state.items.isNotEmpty && !state.done)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.green700))),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
