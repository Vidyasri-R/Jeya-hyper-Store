import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/festival_pack.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/festive_decor.dart';
import '../../widgets/product_card.dart';
import 'home_header.dart';
import 'web_home.dart';
import '../../core/layout.dart';
import '../../core/navigation.dart';
import '../../widgets/store_banner_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isWideLayout(context)) return const WebHome(); // web shop on laptops & tablets
    final categories = ref.watch(categoriesProvider);
    final lists = ref.watch(homeListsProvider);
    final paused = ref.watch(storePausedMessageProvider).valueOrNull;
    final festival = ref.watch(festivalProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: PetalOverlay(pack: festival?.pack, child: RefreshIndicator(
        color: AppColors.brand700,
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(homeListsProvider);
          ref.invalidate(publicConfigProvider);
          await ref.read(homeListsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: HomeHeader()),
            if (paused != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Row(children: [
                    const Icon(Icons.storefront_outlined, color: Color(0xFF8A5A00)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(paused, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8A5A00), fontWeight: FontWeight.w600))),
                  ]),
                ),
              ),
            SliverToBoxAdapter(
              child: categories.when(
                data: (list) => _QuickCategories(roots: list),
                loading: () => const _QuickCategoriesSkeleton(),
                error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(categoriesProvider)),
              ),
            ),
            const SliverToBoxAdapter(child: _HeroCarousel()),
            ...lists.when(
              data: (home) {
                final items = home.popular;
                return [
                  if (home.offers.isNotEmpty) ...[
                    SliverToBoxAdapter(child: SectionHeader(title: "Today's Offers", subtitle: 'Best savings in store today', onSeeAll: () => context.go('/categories'))),
                    SliverToBoxAdapter(child: _ProductRail(products: home.offers)),
                  ],
                  SliverToBoxAdapter(
                    child: categories.maybeWhen(
                      data: (list) => _ShopByCategory(roots: list),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ),
                  SliverToBoxAdapter(child: SectionHeader(title: 'Popular in your store', subtitle: 'What Trichy is buying', onSeeAll: () => context.go('/categories'))),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: productGridDelegate(context),
                      delegate: SliverChildBuilderDelegate((_, i) => ProductCard(product: items[i], compact: compactProducts(context)), childCount: items.length),
                    ),
                  ),
                ];
              },
              loading: () => [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate: productGridDelegate(context),
                    delegate: SliverChildBuilderDelegate((_, _) => const ShimmerBox(), childCount: 4),
                  ),
                ),
              ],
              error: (e, _) => [SliverToBoxAdapter(child: ErrorRetry(error: e, onRetry: () => ref.invalidate(homeListsProvider)))],
            ),
            const SliverToBoxAdapter(child: _StorePromise()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      )),
      bottomNavigationBar: const CartBar(),
    );
  }
}

class _QuickCategories extends StatelessWidget {
  const _QuickCategories({required this.roots});
  final List<Category> roots;

  @override
  Widget build(BuildContext context) {
    final top = roots.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in top)
            Expanded(child: CategoryTile(name: c.name, imageUrl: c.imageUrl, size: 56, onTap: () => context.go('/categories?c=${c.slug}'))),
          Expanded(
            child: InkWell(
              onTap: () => context.go('/categories'),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Column(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(AppRadius.lg)),
                  child: Icon(Icons.apps_rounded, color: AppColors.brand700, size: 28),
                ),
                const SizedBox(height: 6),
                Text('View All', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCategoriesSkeleton extends StatelessWidget {
  const _QuickCategoriesSkeleton();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(6, (_) => const ShimmerBox(width: 52, height: 52))),
      );
}

class _HeroBanner {
  const _HeroBanner(this.tag, this.title, this.subtitle, this.highlight, this.cta, this.icon, this.colors, this.route);
  final String tag, title, subtitle, highlight, cta;
  final IconData icon;
  final List<Color> colors;
  final String route;
}

/// Everyday banners; the delivery and payment ones follow Admin → Store settings.
List<_HeroBanner> _everydayBanners(StoreRules rules) {
  final free = rules.freeAbovePaise;
  final minimum = rules.minOrderPaise > 0 ? ' · min. order ${formatPaise(rules.minOrderPaise)}' : '';
  return [
    _HeroBanner('DAILY ESSENTIALS', 'Groceries\nat your doorstep', 'Rice, dal, oil & daily needs', 'From our Trichy store', 'Shop Now', Icons.shopping_basket_rounded,
        [AppColors.brand50, AppColors.brand100], '/categories'), // follows Admin → Brand colour
    // {speed} → the store's delivery promise, e.g. "Next-day delivery".
    _HeroBanner(
      free == null ? 'HOME DELIVERY' : 'FREE DELIVERY',
      free == null ? 'Delivered\nto your door' : (free == 0 ? 'Free delivery\non every order' : 'Free delivery\non ${formatPaise(free)}+'),
      '{speed} from your store$minimum',
      '',
      'Start Shopping',
      Icons.delivery_dining_rounded,
      const [Color(0xFFFFF1D6), Color(0xFFFFE2A8)],
      '/categories',
    ),
    _HeroBanner(
      'PAY YOUR WAY',
      rules.cod && rules.online ? 'UPI, cards\nor cash on delivery' : (rules.online ? 'UPI, cards\n& netbanking' : 'Cash on\ndelivery'),
      rules.online ? 'Safe & secure payments' : 'Pay when your order arrives',
      '',
      'Explore',
      Icons.verified_user_rounded,
      const [Color(0xFFE5ECFA), Color(0xFFCCD9F5)],
      '/categories',
    ),
  ];
}

class _HeroCarousel extends ConsumerStatefulWidget {
  const _HeroCarousel();
  @override
  ConsumerState<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends ConsumerState<_HeroCarousel> {
  // Phones peek at the next banner; wide screens show two or three side by side.
  late final _controller = PageController(viewportFraction: _fraction(MediaQuery.sizeOf(context).width));

  static double _fraction(double width) => width >= 1100 ? 0.34 : (width >= 700 ? 0.5 : 0.92);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final festive = ref.watch(festivalProvider)?.pack?.banners ?? const <FestivalBanner>[];
    final store = ref.watch(storeBannersProvider);
    final banners = store.isEmpty ? _everydayBanners(ref.watch(storeRulesProvider)) : const <_HeroBanner>[];
    return Column(
      children: [
        const SizedBox(height: 14),
        SizedBox(
          // Sized for 2-line titles at large accessibility font sizes (no overflow on small phones).
          height: 176,
          // Marketing art has a fixed height: cap text growth so large accessibility sizes still fit.
          child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.1, child: PageView.builder(
            controller: _controller,
            padEnds: _controller.viewportFraction > 0.9, // wide: start at the left edge
            itemCount: festive.length + store.length + banners.length,
            itemBuilder: (context, i) {
              if (i < festive.length) {
                return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FestiveBannerCard(festive[i]));
              }
              if (i < festive.length + store.length) {
                return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: StoreBannerCard(store[i - festive.length]));
              }
              final b = banners[i - festive.length - store.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => openRoute(context, b.route),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      gradient: LinearGradient(colors: b.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(children: [
                      Positioned(
                        right: -18,
                        bottom: -22,
                        child: Icon(b.icon, size: 170, color: AppColors.brand800.withValues(alpha: 0.10)),
                      ),
                      Positioned(right: 14, top: 14, child: Image.asset('assets/brand/logo_mark.png', height: 44)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.brand700, borderRadius: BorderRadius.circular(20)),
                              child: Text(b.tag, style: text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                            ),
                            const SizedBox(height: 8),
                            Text(b.title, style: text.titleLarge?.copyWith(height: 1.1, color: AppColors.brand900, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Consumer(
                              builder: (context, ref, _) => Text(
                                b.subtitle.replaceAll('{speed}', ref.watch(deliverySpeedProvider).headline),
                                style: text.bodySmall?.copyWith(color: AppColors.ink),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: AppColors.brand800, borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(b.cta, style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          )),
        ),
        const SizedBox(height: 10),
        SmoothPageIndicator(
          controller: _controller,
          count: festive.length + store.length + banners.length,
          effect: ExpandingDotsEffect(dotHeight: 6, dotWidth: 6, activeDotColor: AppColors.brand700, dotColor: AppColors.line),
        ),
      ],
    );
  }
}

class _ProductRail extends StatelessWidget {
  const _ProductRail({required this.products});
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final compact = compactProducts(context);
    final cardWidth = productRailCardWidth(context);
    return SizedBox(
      height: cardWidth + (compact ? 118 : 132),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => SizedBox(width: compact ? 6 : 10),
        itemBuilder: (_, i) => ProductCard(product: products[i], width: cardWidth, compact: compact),
      ),
    );
  }
}

class _ShopByCategory extends StatelessWidget {
  const _ShopByCategory({required this.roots});
  final List<Category> roots;

  @override
  Widget build(BuildContext context) {
    // Leaf categories read best here ("Atta, Rice & Dal", "Masalas") — fall back to roots.
    final leaves = [for (final r in roots) ...(r.children.isEmpty ? [r] : r.children)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Shop by Category', onSeeAll: () => context.go('/categories')),
        SizedBox(
          height: 104,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: leaves.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (_, i) => CategoryTile(
              name: leaves[i].name,
              imageUrl: leaves[i].imageUrl,
              onTap: () => context.go('/categories?c=${leaves[i].slug}'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StorePromise extends ConsumerWidget {
  const _StorePromise();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    Widget item(IconData icon, String title, String sub) => Expanded(
          child: Column(children: [
            Icon(icon, color: AppColors.brand700),
            const SizedBox(height: 6),
            Text(title, style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            Text(sub, style: text.labelSmall, textAlign: TextAlign.center),
          ]),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: AppColors.brand50, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Row(children: [
        item(Icons.local_shipping_outlined, ref.watch(deliverySpeedProvider).headline, 'Across Trichy'),
        item(Icons.verified_outlined, 'Quality checked', 'Every order'),
        item(Icons.storefront_outlined, 'Your local store', 'Trusted for years'),
      ]),
    );
  }
}
