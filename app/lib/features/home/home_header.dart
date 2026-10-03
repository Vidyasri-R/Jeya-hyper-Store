import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../../widgets/festive_decor.dart';

/// Hero header: brand, deliver-to, greeting and search; dressed in festival art when a theme is on.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning!';
    if (h < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final auth = ref.watch(authProvider);
    final address = ref.watch(selectedAddressProvider);
    final firstName = auth is SignedIn ? auth.user.name?.split(' ').first : null;
    final festival = ref.watch(festivalProvider);
    final pack = festival?.pack;
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: BoxDecoration(
        gradient: pack == null ? AppColors.headerGradient : null,
        color: pack == null ? null : AppColors.brand900,
        image: pack == null ? null : DecorationImage(image: AssetImage(pack.headerBackground), fit: BoxFit.cover, alignment: Alignment.topCenter),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (pack == null) ...[
            Positioned(right: -40, top: -30, child: _Glow(size: 200)),
            Positioned(right: 60, bottom: -60, child: _Glow(size: 140)),
            Positioned(
              right: -6,
              top: 64,
              child: Opacity(opacity: 0.16, child: Image.asset('assets/brand/logo_mark.png', height: 150, color: Colors.white, colorBlendMode: BlendMode.srcIn)),
            ),
          ] else ...[
            const Positioned.fill(child: Twinkles()),
            Positioned(left: 0, right: 0, top: topInset, height: 44, child: Thoranam(pack: pack)),
            // Sits just above the search bar, which tucks over the rangoli's front edge.
            Positioned(right: 4, bottom: 60, child: FestiveHero(pack: pack, width: 132)),
          ],
          SafeArea(
            bottom: false,
            child: Padding(
              // Festive: room under the thoranam so it never crosses the store name.
              padding: EdgeInsets.fromLTRB(16, pack == null ? 10 : 44, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Image.asset('assets/brand/logo_mark.png', height: 30),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jeya Hyper Store',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.1),
                            ),
                            Text(
                              'Your neighbourhood supermarket',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => context.go('/profile'),
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: firstName != null
                              ? Text(firstName[0].toUpperCase(), style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))
                              : const Icon(Icons.person_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => auth is SignedIn ? context.push('/addresses?select=1') : context.push('/login'),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 4),
                      Text('Deliver to ', style: text.labelMedium?.copyWith(color: Colors.white70)),
                      Flexible(
                        child: Text(
                          address == null ? 'Add delivery address' : '${address.title} – ${address.line1}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    // Festive: keep the greeting clear of the diyas on the right.
                    padding: EdgeInsets.only(right: pack == null ? 0 : 124),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            pack != null
                                ? (firstName != null ? '${pack.greetingOn(DateTime.now())}, $firstName!' : '${pack.greetingOn(DateTime.now())}!')
                                : (firstName != null ? '${_greeting().replaceAll('!', '')}, $firstName!' : _greeting()),
                            maxLines: 1,
                            style: text.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              shadows: pack == null ? null : const [Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 1))],
                            ),
                          ),
                        ),
                        Text(
                          // The store's own festival message (Admin → Festival theme) when it set one.
                          pack == null ? 'What are you looking for today?' : (festival!.message ?? pack.question),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: pack != null ? AppColors.festiveAccent : Colors.white.withValues(alpha: 0.92),
                            fontWeight: pack != null ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      onTap: () => context.push('/search'),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(children: [
                          const Icon(Icons.search_rounded, color: AppColors.inkMuted),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Search for products, brands or categories…', style: text.bodyMedium?.copyWith(color: AppColors.inkFaint))),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
      );
}
