import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/festival_pack.dart';
import '../../core/layout.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../../widgets/common.dart';
import '../../widgets/festive_decor.dart';
import '../../widgets/store_banner_card.dart';
import '../../widgets/web_frame.dart';
import '../../widgets/web_product_card.dart';

/// Popular in-stock products for the web Home (deals are the discounted ones among them).
final webHomeProductsProvider = FutureProvider<List<Product>>(
  (ref) async => (await ref.watch(repositoryProvider).products(sort: 'popular', inStock: true, limit: 50)).items,
);

/// Web shop Home for laptops and tablets: hero, categories, deals, category tiles, best sellers,
/// why-Jeya + store card, footer. Everything comes from the live catalogue and store settings.
class WebHome extends ConsumerStatefulWidget {
  const WebHome({super.key});
  @override
  ConsumerState<WebHome> createState() => _WebHomeState();
}

class _WebHomeState extends ConsumerState<WebHome> {
  final _dealsKey = GlobalKey();

  void _toDeals() {
    final ctx = _dealsKey.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final roots = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final products = ref.watch(webHomeProductsProvider).valueOrNull ?? const <Product>[];
    final paused = ref.watch(storePausedMessageProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          if (paused != null) _Pad(child: _Notice(text: paused)),
          _Pad(child: _Hero(roots: roots, onOffers: _toDeals)),
          const SizedBox(height: 24),
          if (roots.isNotEmpty) _Pad(child: _CategoryCircles(roots: roots)),
          const SizedBox(height: 24),
          _Pad(key: _dealsKey, child: _BestDeals(products: products)),
          const SizedBox(height: 28),
          if (roots.isNotEmpty) _Pad(child: _ShopByCategory(roots: roots)),
          const SizedBox(height: 28),
          if (products.isNotEmpty)
            _Pad(
              child: _Section(
                icon: Icons.emoji_events_outlined,
                title: 'Best Selling Products',
                subtitle: 'What Trichy is buying',
                action: ('View all', () => context.go('/categories')),
                child: WebProductRow(products: products),
              ),
            ),
          const SizedBox(height: 28),
          const _Pad(child: _WhyAndStore()),
          const WebFooter(),
        ],
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.storefront_outlined, color: Color(0xFF8A5A00)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF8A5A00), fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Section heading with an optional "View all" link.
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, this.subtitle, this.action, required this.child});
  final IconData icon;
  final String title;
  final String? subtitle;
  final (String, VoidCallback)? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Icon(icon, color: AppColors.brand700, size: 28),
        const SizedBox(width: 8),
        Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(width: 14),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(subtitle!, style: text.bodySmall)),
        ],
        const Spacer(),
        if (action != null)
          TextButton(
            onPressed: action!.$2,
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action!.$1), const SizedBox(width: 4), const Icon(Icons.arrow_forward_rounded, size: 18)]),
          ),
      ]),
      const SizedBox(height: 14),
      child,
    ]);
  }
}

// ── hero ────────────────────────────────────────────────────────────────────

class _Hero extends ConsumerWidget {
  const _Hero({required this.roots, required this.onOffers});
  final List<Category> roots;
  final VoidCallback onOffers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final rules = ref.watch(storeRulesProvider);
    final speed = ref.watch(deliverySpeedProvider);
    final total = roots.fold<int>(0, (sum, c) => sum + c.productCount);
    final free = rules.freeAbovePaise;
    final side = _sidePromos(ref);
    final showSide = width >= 1000 && side.isNotEmpty;

    final features = <(IconData, String, String)>[
      (Icons.inventory_2_outlined, 'Wide range', total > 0 ? '$total+ products' : 'Groceries & daily needs'),
      (Icons.local_shipping_outlined, speed.headline, free == null ? 'From our Trichy store' : (free == 0 ? 'Free on every order' : 'Free above ${formatPaise(free)}')),
      (Icons.verified_user_outlined, 'Secure payments', rules.online && rules.cod ? 'UPI, cards or cash' : (rules.online ? 'UPI & cards' : 'Cash on delivery')),
      (Icons.replay_rounded, 'Easy returns', 'Report within 24 hours'),
    ];

    final hero = Container(
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [AppColors.brand50, AppColors.surface, AppColors.brand50], begin: Alignment.topLeft, end: Alignment.bottomRight),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(32, 24, 24, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Row(children: [
            Expanded(
              flex: 6,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
                  child: Text("TRICHY'S NEIGHBOURHOOD SUPERMARKET", style: text.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.ink)),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Everything You Need.', style: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.05)),
                    Text('One Store.', style: text.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: AppColors.brand700, height: 1.05)),
                  ]),
                ),
                const SizedBox(height: 10),
                Text('Groceries, staples, household essentials and everyday needs — delivered to your doorstep.',
                    maxLines: 3, overflow: TextOverflow.ellipsis, style: text.bodyLarge?.copyWith(color: AppColors.inkMuted)),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/categories'),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Shop Now'),
                    iconAlignment: IconAlignment.end,
                    style: FilledButton.styleFrom(minimumSize: const Size(150, 48)),
                  ),
                  OutlinedButton(onPressed: onOffers, style: OutlinedButton.styleFrom(minimumSize: const Size(140, 48)), child: const Text('View Offers')),
                ]),
              ]),
            ),
            Expanded(flex: 5, child: Image.asset('assets/web/hero_basket.webp', fit: BoxFit.contain)),
          ]),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 28, runSpacing: 10, children: [
          for (final (icon, title, sub) in features)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppColors.brand700, size: 26),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(sub, style: text.labelSmall),
              ]),
            ]),
        ]),
      ]),
    );

    if (!showSide) return hero;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(flex: 7, child: hero),
      const SizedBox(width: 16),
      Expanded(
        flex: 3,
        child: Column(children: [
          SizedBox(height: 182, child: side[0]),
          const SizedBox(height: 16),
          SizedBox(height: 182, child: side.length > 1 ? side[1] : const SizedBox.shrink()),
        ]),
      ),
    ]);
  }

  /// Right of the hero: the store's own banners (Admin → Home banners), else the festival's,
  /// else two built-in promises (free delivery, payments).
  List<Widget> _sidePromos(WidgetRef ref) {
    final store = ref.watch(storeBannersProvider);
    if (store.isNotEmpty) return [for (final b in store.take(2)) StoreBannerCard(b)];
    final festive = ref.watch(festivalProvider)?.pack?.banners ?? const <FestivalBanner>[];
    if (festive.isNotEmpty) return [for (final b in festive.take(2)) FestiveBannerCard(b)];
    final rules = ref.watch(storeRulesProvider);
    final free = rules.freeAbovePaise;
    return [
      _PromoCard(
        tag: 'Free delivery',
        title: free == null ? 'Delivered to your door' : (free == 0 ? 'Free delivery on every order' : 'Free delivery on ${formatPaise(free)}+'),
        subtitle: 'From Jeya Hyper Store, Trichy',
        cta: 'Start shopping',
        image: 'assets/web/promo_delivery.webp',
        background: const Color(0xFFFFF4DC),
      ),
      _PromoCard(
        tag: 'Pay your way',
        title: rules.online ? 'UPI, cards or cash on delivery' : 'Cash on delivery',
        subtitle: 'Safe & secure payments',
        cta: 'Explore',
        image: 'assets/web/promo_payments.webp',
        background: const Color(0xFFE8EEFA),
      ),
    ];
  }
}

/// Built-in hero-side promo: text on the left, illustration on the right.
class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.tag, required this.title, required this.subtitle, required this.cta, required this.image, required this.background});
  final String tag, title, subtitle, cta, image;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/categories'),
        child: Stack(children: [
          Positioned(right: -6, bottom: 4, top: 30, width: 170, child: ExcludeSemantics(child: Image.asset(image, fit: BoxFit.contain, alignment: Alignment.bottomRight))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 150, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.brand700, borderRadius: BorderRadius.circular(20)),
                child: Text(tag.toUpperCase(), style: text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 8),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppColors.brand900, height: 1.15)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: AppColors.brand800, borderRadius: BorderRadius.circular(20)),
                child: Text('$cta →', style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── categories ──────────────────────────────────────────────────────────────

/// Round category picks (sub-categories, which read best: Rice, Dals, Oils…), scrollable.
class _CategoryCircles extends StatefulWidget {
  const _CategoryCircles({required this.roots});
  final List<Category> roots;
  @override
  State<_CategoryCircles> createState() => _CategoryCirclesState();
}

class _CategoryCirclesState extends State<_CategoryCircles> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _by(double dx) => _scroll.animateTo((_scroll.offset + dx).clamp(0, _scroll.position.maxScrollExtent), duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = [for (final r in widget.roots) ...(r.children.isEmpty ? [r] : r.children)];
    return SizedBox(
      height: 150,
      child: Row(children: [
        IconButton.outlined(onPressed: () => _by(-480), tooltip: 'Scroll left', icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final c = items[i];
              final v = categoryVisual(c.name);
              return SizedBox(
                width: 108,
                child: InkWell(
                  onTap: () => context.go('/categories?c=${c.slug}'),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(children: [
                    const SizedBox(height: 6),
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: v.bg, border: Border.all(color: AppColors.line)),
                      clipBehavior: Clip.antiAlias,
                      child: c.imageUrl != null
                          ? CachedNetworkImage(imageUrl: c.imageUrl!, fit: BoxFit.cover)
                          : (categoryArt(c.name) != null ? Padding(padding: const EdgeInsets.all(8), child: Image.asset(categoryArt(c.name)!, fit: BoxFit.contain)) : Icon(v.icon, color: v.fg, size: 40)),
                    ),
                    const SizedBox(height: 8),
                    Text(c.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                ),
              );
            },
          ),
        ),
        IconButton.outlined(onPressed: () => _by(480), tooltip: 'Scroll right', icon: const Icon(Icons.chevron_right_rounded)),
      ]),
    );
  }
}

// ── deals ───────────────────────────────────────────────────────────────────

class _BestDeals extends StatefulWidget {
  const _BestDeals({required this.products});
  final List<Product> products;
  @override
  State<_BestDeals> createState() => _BestDealsState();
}

class _BestDealsState extends State<_BestDeals> {
  int _filter = 0; // 0 all · 1 under ₹99 · 2 20%+ off

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final deals = widget.products.where((p) => p.hasDiscount).toList()..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    if (deals.isEmpty) return const SizedBox.shrink();
    final shown = switch (_filter) {
      1 => deals.where((p) => toPaise(p.sellingPrice) < 9900).toList(),
      2 => deals.where((p) => p.discountPercent >= 20).toList(),
      _ => deals,
    };
    final best = deals.first.discountPercent;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 200,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Today's Best Deals", style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.1)),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Up to ', style: text.titleMedium),
              TextSpan(text: '$best% OFF', style: text.titleMedium?.copyWith(color: AppColors.offerRed, fontWeight: FontWeight.w800)),
            ])),
            const SizedBox(height: 8),
            Text('Great offers on your daily essentials.', style: text.bodySmall),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.go('/categories'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              iconAlignment: IconAlignment.end,
              label: const Text('Shop all'),
            ),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, children: [
              for (final (i, label) in [(0, 'All'), (1, 'Under ₹99'), (2, '20%+ OFF')])
                ChoiceChip(label: Text(label), selected: _filter == i, onSelected: (_) => setState(() => _filter = i), showCheckmark: false),
            ]),
            const SizedBox(height: 14),
            shown.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Text('No deals in this range right now.', style: text.bodyMedium))
                : WebProductRow(products: shown, minCardWidth: 180),
          ]),
        ),
      ]),
    );
  }
}

// ── shop by category ────────────────────────────────────────────────────────

class _ShopByCategory extends StatelessWidget {
  const _ShopByCategory({required this.roots});
  final List<Category> roots;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _Section(
      icon: Icons.storefront_outlined,
      title: 'Shop by Category',
      subtitle: 'Explore our wide range of products',
      action: ('View all categories', () => context.go('/categories')),
      child: LayoutBuilder(builder: (context, c) {
        const gap = 14.0;
        final cols = c.maxWidth >= 1000 ? 4 : (c.maxWidth >= 680 ? 3 : 2);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [
          for (final r in roots)
            SizedBox(
              width: w,
              height: 140,
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => context.go('/categories?c=${r.slug}'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.brand800)),
                          const SizedBox(height: 4),
                          Text(r.children.take(4).map((c) => c.name).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: text.labelSmall),
                          const Spacer(),
                          Row(children: [
                            Text('Explore', style: text.labelLarge?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.brand700),
                          ]),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      _CategoryArt(category: r, size: 108),
                    ]),
                  ),
                ),
              ),
            ),
        ]);
      }),
    );
  }
}

class _CategoryArt extends StatelessWidget {
  const _CategoryArt({required this.category, required this.size});
  final Category category;
  final double size;
  @override
  Widget build(BuildContext context) {
    final v = categoryVisual(category.name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: v.bg, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: category.imageUrl != null
          ? CachedNetworkImage(imageUrl: category.imageUrl!, fit: BoxFit.cover)
          : (categoryArt(category.name) != null ? Image.asset(categoryArt(category.name)!, fit: BoxFit.contain) : Icon(v.icon, color: v.fg, size: size * 0.48)),
    );
  }
}

// ── why Jeya + find the store ───────────────────────────────────────────────

class _WhyAndStore extends ConsumerWidget {
  const _WhyAndStore();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final info = ref.watch(storeInfoProvider);
    final rules = ref.watch(storeRulesProvider);
    final free = rules.freeAbovePaise;
    final phone = (info['supportPhone'] as String?)?.replaceAll(RegExp(r'\D'), '');
    final why = <(IconData, String, String)>[
      (Icons.local_shipping_outlined, 'Free delivery', free == null ? 'From our store' : (free == 0 ? 'On every order' : 'Above ${formatPaise(free)}')),
      (Icons.storefront_outlined, 'Our own store', 'Packed & delivered by our staff'),
      (Icons.credit_card_rounded, 'Secure payments', 'UPI, cards, COD'),
      (Icons.replay_rounded, 'Easy returns', 'Report within 24 hours'),
      if (phone != null && phone.isNotEmpty) (Icons.support_agent_rounded, 'Customer support', '+$phone'),
    ];
    final whyCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_outlined, color: AppColors.brand700, size: 30),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Why Choose Jeya?', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            Text('Your trusted neighbourhood supermarket', style: text.bodySmall),
          ]),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 28, runSpacing: 14, children: [
          for (final (icon, title, sub) in why)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: AppColors.brand700, size: 30),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(sub, style: text.labelSmall),
              ]),
            ]),
        ]),
      ]),
    );
    final storeCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.location_on_outlined, color: AppColors.brand700, size: 28),
          const SizedBox(width: 8),
          Text('Find Jeya Hyper Store', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        if (info['address'] is String) Text(info['address'] as String, style: text.bodyMedium),
        if (info['openingHours'] is String) ...[
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.circle, size: 10, color: AppColors.brand600),
            const SizedBox(width: 6),
            Text(info['openingHours'] as String, style: text.bodySmall?.copyWith(color: AppColors.brand700, fontWeight: FontWeight.w600)),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=10.8127737,78.6358536')),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('Get directions'),
          ),
          if (phone != null && phone.isNotEmpty)
            OutlinedButton.icon(onPressed: () => launchUrl(Uri.parse('tel:+$phone')), icon: const Icon(Icons.call_outlined), label: const Text('Call store')),
        ]),
      ]),
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 1000) return Column(children: [whyCard, const SizedBox(height: 16), storeCard]);
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 3, child: whyCard),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: storeCard),
        ]),
      );
    });
  }
}
