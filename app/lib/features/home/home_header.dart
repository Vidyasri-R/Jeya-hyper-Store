import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';

/// Green hero header from the design: brand, deliver-to, greeting and search.
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

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -40, top: -30, child: _Glow(size: 200)),
          Positioned(right: 60, bottom: -60, child: _Glow(size: 140)),
          Positioned(
            right: -6,
            top: 64,
            child: Opacity(opacity: 0.16, child: Image.asset('assets/brand/logo_mark.png', height: 150, color: Colors.white, colorBlendMode: BlendMode.srcIn)),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Jeya Hyper Store', style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.1)),
                          Text('Your neighbourhood supermarket', style: text.labelSmall?.copyWith(color: Colors.white70)),
                        ],
                      ),
                      const Spacer(),
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
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.5),
                        child: Text(
                          address == null ? 'Add delivery address' : '${address.title} – ${address.line1}',
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text(firstName != null ? '${_greeting().replaceAll('!', '')}, $firstName!' : _greeting(),
                      style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  Text('What are you looking for today?', style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.92))),
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
