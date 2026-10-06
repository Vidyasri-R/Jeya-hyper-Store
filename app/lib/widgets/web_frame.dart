import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/layout.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../router.dart';
import '../state/providers.dart';

/// Wide screens (laptops, landscape tablets, desktop browsers): one top bar for every page and
/// the page centred at up to [kMaxContentWidth]. Inside, screens see a [kMaxContentWidth]-wide
/// "screen" (MediaQuery), so every width-based layout — grids, rails, cards — adapts by itself.
class WebFrame extends ConsumerWidget {
  const WebFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    if (media.size.width < kWideBreakpoint) return child;
    final router = ref.watch(routerProvider);
    return ColoredBox(
      color: AppColors.bg,
      child: Column(children: [
        const WebTopBar(),
        Expanded(
          child: ValueListenableBuilder<RouteInformation>(
            valueListenable: router.routeInformationProvider,
            builder: (context, info, _) {
              // Reading pages (cart, checkout, orders, account, sign-in) stay at a comfortable width.
              final path = info.uri.path;
              final max = _readingPages.any(path.startsWith) ? kReadingWidth : kMaxContentWidth;
              final contentWidth = media.size.width < max ? media.size.width : max;
              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: MediaQuery(
                    data: media.copyWith(size: Size(contentWidth, media.size.height - WebTopBar.height), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                    child: WideLayoutScope(child: ClipRect(child: child)),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

const _readingPages = ['/cart', '/bag', '/checkout', '/orders', '/order', '/profile', '/addresses', '/address', '/login', '/otp', '/help', '/about'];

/// The web shop's header: brand, search, main sections, account and cart.
class WebTopBar extends ConsumerWidget {
  const WebTopBar({super.key});
  static const height = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final text = Theme.of(context).textTheme;
    final auth = ref.watch(authProvider);
    final cart = ref.watch(cartProvider).valueOrNull;
    final count = cart?.lines.length ?? 0;
    final signedIn = auth is SignedIn;

    Widget link(String label, String route) => TextButton(
          onPressed: () => router.go(route),
          style: TextButton.styleFrom(foregroundColor: AppColors.ink, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16)),
          child: Text(label, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        );

    return Material(
      color: AppColors.surface,
      elevation: 0,
      child: Container(
        height: height,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                Semantics(
                  link: true,
                  label: 'Jeya Hyper Store home',
                  child: InkWell(
                    onTap: () => router.go('/home'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Image.asset('assets/brand/logo_mark.png', height: 40),
                        const SizedBox(width: 10),
                        ExcludeSemantics(child: Text('Jeya Hyper Store', style: text.titleMedium?.copyWith(color: AppColors.brandBlue, fontWeight: FontWeight.w800))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Search products',
                    child: InkWell(
                      onTap: () => router.push('/search'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
                        child: Row(children: [
                          const Icon(Icons.search_rounded, color: AppColors.inkMuted),
                          const SizedBox(width: 10),
                          Expanded(child: ExcludeSemantics(child: Text('Search rice, dal, oil, soap…', style: text.bodyMedium?.copyWith(color: AppColors.inkMuted), overflow: TextOverflow.ellipsis))),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                link('Home', '/home'),
                link('Categories', '/categories'),
                if (signedIn) link('Orders', '/orders'),
                TextButton.icon(
                  onPressed: () => signedIn ? router.go('/profile') : router.push('/login'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.ink, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16)),
                  icon: const Icon(Icons.person_outline_rounded),
                  label: Text(signedIn ? (auth.user.name?.split(' ').first ?? 'Account') : 'Sign in', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => signedIn ? router.push('/bag') : router.push('/login?from=%2Fbag'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 18)),
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(count == 0 ? 'Cart' : '$count item${count == 1 ? '' : 's'} · ${formatRupees(cart!.subtotal)}'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
