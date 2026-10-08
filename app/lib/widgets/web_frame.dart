import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/layout.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../router.dart';
import '../state/providers.dart';
import '../state/recent_searches.dart';
import 'product_image.dart';

/// Web shop on laptops and tablets: the two-row header above every page, the page centred at up
/// to [kMaxContentWidth]. Inside, screens see the frame's width (MediaQuery), so width-based
/// layouts adapt by themselves. Phones and the native apps get the app layout untouched.
class WebFrame extends ConsumerStatefulWidget {
  const WebFrame({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends ConsumerState<WebFrame> {
  String _path = '/';
  Listenable? _listening;

  /// The router reports navigation (including back) while it builds, so the page width is updated
  /// right after that frame instead of during it.
  void _onRoute() {
    final path = ref.read(routerProvider).routerDelegate.currentConfiguration.uri.path;
    if (path == _path) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && path != _path) setState(() => _path = path);
    });
  }

  @override
  void dispose() {
    _listening?.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!kIsWeb || media.size.width < kWideBreakpoint) return widget.child;
    final router = ref.watch(routerProvider);
    if (!identical(_listening, router.routerDelegate)) {
      _listening?.removeListener(_onRoute);
      _listening = router.routerDelegate..addListener(_onRoute);
      _path = router.routeInformationProvider.value.uri.path;
    }
    final max = _readingPages.any(_path.startsWith) ? kReadingWidth : kMaxContentWidth;
    final contentWidth = media.size.width < max ? media.size.width : max;
    // The header sits above the router's Navigator, so it needs its own Overlay for tooltips and
    // menus (without one, hovering "All Categories" crashed the bar into a grey box).
    return Overlay.wrap(
      clipBehavior: Clip.none,
      child: ColoredBox(
      color: AppColors.bg,
      child: Column(children: [
        const WebHeader(),
        Expanded(
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: MediaQuery(
                data: media.copyWith(size: Size(contentWidth, media.size.height - WebHeader.height), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                child: WideLayoutScope(child: ClipRect(child: widget.child)),
              ),
            ),
          ),
        ),
      ]),
      ),
    );
  }
}

/// Account-type pages read better narrow; shop pages (home, categories, product, cart, checkout) use the full width.
const _readingPages = ['/orders', '/order/', '/profile', '/addresses', '/address', '/login', '/otp', '/help', '/about', '/profile-setup'];

/// Header row 1: logo · deliver to · search · orders · account · cart. Row 2: categories.
class WebHeader extends ConsumerStatefulWidget {
  const WebHeader({super.key});
  static const height = 124.0;

  @override
  ConsumerState<WebHeader> createState() => _WebHeaderState();
}

class _WebHeaderState extends ConsumerState<WebHeader> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _search.text.trim();
    ref.read(routerProvider).push(q.isEmpty ? '/search' : '/search?q=${Uri.encodeQueryComponent(q)}');
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final text = Theme.of(context).textTheme;
    final auth = ref.watch(authProvider);
    final signedIn = auth is SignedIn;
    final cart = ref.watch(cartProvider).valueOrNull;
    final count = cart?.lines.length ?? 0;
    final address = ref.watch(selectedAddressProvider);
    final roots = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    Widget iconLink(IconData icon, String label, VoidCallback onTap) => Semantics(
          button: true,
          label: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ExcludeSemantics(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: AppColors.ink, size: 24),
                  const SizedBox(height: 2),
                  Text(label, style: text.labelSmall?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );

    return Material(
      color: AppColors.surface,
      child: SizedBox(
        height: WebHeader.height,
        child: Column(children: [
          // ── row 1 ──
          SizedBox(
            height: 76,
            child: _Centered(
              child: Row(children: [
                Semantics(
                  link: true,
                  label: 'Jeya Hyper Store home',
                  child: InkWell(
                    onTap: () => router.go('/home'),
                    child: ExcludeSemantics(child: Image.asset('assets/brand/logo_full.png', height: 56)),
                  ),
                ),
                const SizedBox(width: 18),
                if (wide)
                  InkWell(
                    onTap: () => signedIn ? router.push('/addresses?select=1') : router.push('/login'),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.location_on_outlined, color: AppColors.offerRed),
                        const SizedBox(width: 6),
                        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Deliver to', style: text.labelSmall),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 170),
                            child: Text(
                              address == null ? 'Tiruchirappalli' : '${address.title}, ${address.city} ${address.pincode}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                      ]),
                    ),
                  ),
                const SizedBox(width: 18),
                Expanded(child: _SearchBox(controller: _search, onSubmit: _submit)),
                const SizedBox(width: 18),
                if (signedIn) iconLink(Icons.receipt_long_outlined, 'Orders', () => router.go('/orders')),
                iconLink(Icons.person_outline_rounded, signedIn ? 'Account' : 'Sign in', () => signedIn ? router.go('/profile') : router.push('/login')),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Cart, $count items',
                  child: InkWell(
                    onTap: () => signedIn ? router.push('/bag') : router.push('/login?from=%2Fbag'),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: ExcludeSemantics(
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Badge(
                            isLabelVisible: count > 0,
                            label: Text('$count'),
                            backgroundColor: AppColors.offerRed,
                            child: const Icon(Icons.shopping_cart_outlined, size: 28, color: AppColors.ink),
                          ),
                          const SizedBox(width: 8),
                          Text('Cart', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          if (count > 0) ...[
                            const SizedBox(width: 8),
                            Text(formatRupees(cart!.subtotal), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          // ── row 2: categories ──
          Container(
            height: 48,
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line), bottom: BorderSide(color: AppColors.line))),
            child: _Centered(
              child: _CategoryBar(roots: roots, onOpen: (c) => router.go('/categories?c=${c.slug}'), onAll: () => router.go('/categories')),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child),
        ),
      );
}

/// Header search with suggestions as you type (like Amazon): products with their pictures, arrow
/// keys to move, Enter to open the highlighted one (or search), Esc to close.
class _SearchBox extends ConsumerStatefulWidget {
  const _SearchBox({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  ConsumerState<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends ConsumerState<_SearchBox> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Suggestion> _items = const [];
  String _for = '';
  int _highlight = -1;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // Let a click on a suggestion land before the list closes.
      if (!_focus.hasFocus) Future.delayed(const Duration(milliseconds: 150), () => mounted && !_focus.hasFocus ? _portal.hide() : null);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  /// Earlier searches shown above the products (all of them while the box is empty).
  List<String> get _recent => ref.read(recentSearchesProvider.notifier).matching(widget.controller.text);

  /// Box empty: show the search history, if there is any.
  void _showHistory() {
    if (widget.controller.text.trim().isEmpty && _recent.isNotEmpty) {
      setState(() {
        _items = const [];
        _for = '';
        _highlight = -1;
      });
      _portal.show();
    }
  }

  void _changed(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _items = const [];
        _for = q;
        _highlight = -1;
      });
      if (q.isEmpty && _recent.isNotEmpty) {
        _portal.show();
      } else {
        _portal.hide();
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      try {
        final found = await ref.read(repositoryProvider).suggest(q);
        if (!mounted || widget.controller.text.trim() != q) return;
        setState(() {
          _items = found;
          _for = q;
          _highlight = -1;
        });
        if (_focus.hasFocus && (found.isNotEmpty || _recent.isNotEmpty)) {
          _portal.show();
        } else {
          _portal.hide();
        }
      } catch (_) {
        // Suggestions are a nicety; the search itself still works.
      }
    });
  }

  void _open(Suggestion s) {
    _portal.hide();
    _focus.unfocus();
    ref.read(recentSearchesProvider.notifier).add(widget.controller.text);
    ref.read(routerProvider).push('/product/${s.slug}');
  }

  void _searchFor(String q) {
    widget.controller.text = q;
    _highlight = -1;
    _search();
  }

  void _search() {
    _portal.hide();
    final recent = _recent;
    if (_highlight >= 0 && _highlight < recent.length) return _searchFor(recent[_highlight]);
    final at = _highlight - recent.length;
    if (at >= 0 && at < _items.length) return _open(_items[at]);
    ref.read(recentSearchesProvider.notifier).add(widget.controller.text);
    widget.onSubmit();
  }

  /// Rows in the list: history, products, then "See all results" (when something is typed).
  int get _rows => _recent.length + _items.length + (_for.isEmpty ? 0 : 1);

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent || !_portal.isShowing) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlight = (_highlight + 1).clamp(0, _rows - 1));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlight = (_highlight - 1).clamp(-1, _rows - 1));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      _portal.hide();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    ref.watch(recentSearchesProvider);
    final recent = _recent;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomLeft,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: LayoutBuilder(builder: (context, _) {
              final width = (_link.leaderSize?.width ?? 600);
              return TapRegion(
                groupId: _link,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surface,
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width, minWidth: width, maxHeight: 460),
                    child: ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 6), children: [
                      if (recent.isNotEmpty && _for.isEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 4, 6, 0),
                          child: Row(children: [
                            Expanded(child: Text('Recent searches', style: text.labelLarge?.copyWith(color: AppColors.inkMuted, fontWeight: FontWeight.w700))),
                            TextButton(
                              onPressed: () {
                                ref.read(recentSearchesProvider.notifier).clear();
                                _portal.hide();
                              },
                              child: const Text('Clear'),
                            ),
                          ]),
                        ),
                      for (final (i, r) in recent.indexed)
                        InkWell(
                          onTap: () => _searchFor(r),
                          child: Container(
                            color: i == _highlight ? AppColors.brand50 : null,
                            padding: const EdgeInsets.only(left: 14, right: 4),
                            child: Row(children: [
                              const SizedBox(width: 40, child: Icon(Icons.history_rounded, color: AppColors.inkMuted, size: 22)),
                              const SizedBox(width: 12),
                              Expanded(child: _Highlighted(text: r, query: _for, style: text.bodyMedium?.copyWith(color: AppColors.brandBlue))),
                              IconButton(
                                tooltip: 'Remove from history',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.inkFaint),
                                onPressed: () {
                                  ref.read(recentSearchesProvider.notifier).remove(r);
                                  if (_recent.isEmpty && _items.isEmpty) _portal.hide();
                                },
                              ),
                            ]),
                          ),
                        ),
                      for (final (i, s) in _items.indexed)
                        InkWell(
                          onTap: () => _open(s),
                          child: Container(
                            color: recent.length + i == _highlight ? AppColors.brand50 : null,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: Row(children: [
                              ProductImage(url: s.imageUrl, placeholderUrl: s.placeholderImageUrl, name: s.name, size: 40, radius: 8),
                              const SizedBox(width: 12),
                              Expanded(child: _Highlighted(text: s.name, query: _for, style: text.bodyMedium)),
                              const Icon(Icons.north_east_rounded, size: 16, color: AppColors.inkFaint),
                            ]),
                          ),
                        ),
                      if (_for.isNotEmpty)
                      InkWell(
                        onTap: () {
                          _highlight = -1;
                          _search();
                        },
                        child: Container(
                          color: _highlight == recent.length + _items.length ? AppColors.brand50 : null,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(children: [
                            Icon(Icons.search_rounded, color: AppColors.brand700),
                            const SizedBox(width: 12),
                            Expanded(child: Text('See all results for "$_for"', style: text.bodyMedium?.copyWith(color: AppColors.brand800, fontWeight: FontWeight.w700))),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
        child: TapRegion(
          groupId: _link,
          onTapOutside: (_) => _portal.hide(),
          child: SizedBox(
            height: 46,
            child: Focus(
              onKeyEvent: _key,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onChanged: _changed,
                onTap: () {
                  if (_items.isNotEmpty && widget.controller.text.trim().length >= 2) {
                    _portal.show();
                  } else {
                    _showHistory();
                  }
                },
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Search for products, brands or categories…',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bg,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.inkMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.line)),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.all(3),
                    child: IconButton.filled(
                      onPressed: _search,
                      tooltip: 'Search',
                      style: IconButton.styleFrom(backgroundColor: AppColors.brand700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      icon: const Icon(Icons.search_rounded, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The suggestion with the typed words in bold.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query, this.style});
  final String text;
  final String query;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final lower = text.toLowerCase();
    final bold = List.filled(text.length, false);
    for (final w in words) {
      for (var i = lower.indexOf(w); i >= 0; i = lower.indexOf(w, i + 1)) {
        for (var k = i; k < i + w.length && k < bold.length; k++) {
          bold[k] = true;
        }
      }
    }
    final spans = <TextSpan>[];
    for (var i = 0; i < text.length;) {
      var j = i;
      while (j < text.length && bold[j] == bold[i]) {
        j++;
      }
      spans.add(TextSpan(text: text.substring(i, j), style: bold[i] ? const TextStyle(fontWeight: FontWeight.w800) : null));
      i = j;
    }
    return Text.rich(TextSpan(children: spans), style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// "All categories" menu, then as many top categories as fit; the rest under "More".
class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.roots, required this.onOpen, required this.onAll});
  final List<Category> roots;
  final void Function(Category) onOpen;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, constraints) {
      final fits = ((constraints.maxWidth - 260) / 150).floor().clamp(0, roots.length);
      final shown = roots.take(fits).toList();
      final more = roots.skip(fits).toList();
      return Row(children: [
        // MenuAnchor (not PopupMenuButton): the header has no Navigator above it, only an Overlay.
        _CategoryMenu(
          categories: roots,
          onOpen: onOpen,
          builder: (open) => InkWell(
            onTap: roots.isEmpty ? null : open, // categories still loading / offline
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.brand700, borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('All Categories', style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        for (final c in shown)
          Flexible(
            child: TextButton(
              onPressed: () => onOpen(c),
              style: TextButton.styleFrom(foregroundColor: AppColors.ink, padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
        if (more.isNotEmpty)
          _CategoryMenu(
            categories: more,
            onOpen: onOpen,
            builder: (open) => InkWell(
              onTap: open,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('More', style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                ]),
              ),
            ),
          ),
        const Spacer(),
      ]);
    });
  }
}

/// Drop-down list of categories under a header button.
class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({required this.categories, required this.onOpen, required this.builder});
  final List<Category> categories;
  final void Function(Category) onOpen;
  final Widget Function(VoidCallback open) builder;

  @override
  Widget build(BuildContext context) => MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        style: const MenuStyle(maximumSize: WidgetStatePropertyAll(Size(320, 520))),
        menuChildren: [for (final c in categories) MenuItemButton(onPressed: () => onOpen(c), child: Text(c.name))],
        builder: (context, controller, _) => builder(() => controller.isOpen ? controller.close() : controller.open()),
      );
}

/// Dark-green site footer: brand, links, store details. Used at the end of web shop pages.
class WebFooter extends ConsumerWidget {
  const WebFooter({super.key});

  /// The policy pages are plain pages on the same site.
  static void openPage(String path) => launchUrl(Uri.parse(path), webOnlyWindowName: '_self');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final info = ref.watch(storeInfoProvider);
    final router = ref.watch(routerProvider);
    final phone = (info['supportPhone'] as String?)?.replaceAll(RegExp(r'\D'), '');
    final address = info['address'] as String?;
    final hours = info['openingHours'] as String?;
    final white = text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85), height: 1.6);
    Widget heading(String s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(s, style: text.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)));
    Widget link(String label, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(label, style: white)),
        );

    return Container(
      margin: const EdgeInsets.only(top: 32),
      color: AppColors.brand900,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 48, runSpacing: 24, children: [
          SizedBox(
            width: 260,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Image.asset('assets/brand/logo_full.png', height: 54),
              ),
              const SizedBox(height: 12),
              Text('Your neighbourhood supermarket in Tiruchirappalli — groceries and daily needs, delivered to your door.', style: white),
            ]),
          ),
          SizedBox(
            width: 160,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              heading('Shop'),
              link('Home', () => router.go('/home')),
              link('All categories', () => router.go('/categories')),
              link('Search', () => router.push('/search')),
              link('My orders', () => router.go('/orders')),
            ]),
          ),
          SizedBox(
            width: 180,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              heading('Customer service'),
              link('Delivery', () => openPage('/delivery/')),
              link('Cancellations & refunds', () => openPage('/refunds/')),
              link('Contact us', () => openPage('/contact/')),
              link('Delete account', () => openPage('/delete-account/')),
            ]),
          ),
          SizedBox(
            width: 260,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              heading('Our store'),
              if (address != null) Text(address, style: white),
              if (hours != null) Text(hours, style: white),
              if (phone != null && phone.isNotEmpty) link('Call +$phone', () => launchUrl(Uri.parse('tel:+$phone'))),
              link('Get directions', () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=10.8127737,78.6358536'))),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        Divider(color: Colors.white.withValues(alpha: 0.15)),
        const SizedBox(height: 8),
        Wrap(spacing: 18, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('© ${DateTime.now().year} Jeya Hyper Store, Tiruchirappalli', style: white),
          link('Privacy', () => openPage('/privacy/')),
          link('Terms', () => openPage('/terms/')),
          link('Refund policy', () => openPage('/refunds/')),
        ]),
      ]),
    );
  }
}
