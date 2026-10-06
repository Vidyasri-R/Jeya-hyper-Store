import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/otp_screen.dart';
import 'features/auth/profile_setup_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/catalog/categories_screen.dart';
import 'features/catalog/product_detail_screen.dart';
import 'features/catalog/search_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/checkout/order_success_screen.dart';
import 'features/home/home_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/profile/address_form_screen.dart';
import 'features/profile/addresses_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/profile/info_screens.dart';
import 'features/profile/profile_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/shell/splash_screen.dart';
import 'state/providers.dart';

/// Screens that need a signed-in user. Browsing works without login (App Store guideline 5.1.1).
const _protected = ['/cart', '/bag', '/checkout', '/orders', '/order/', '/addresses', '/address', '/profile/edit', '/order-success'];

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authProvider.notifier);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: Listenable.merge([auth.refresh, splashIntroDone]),
    redirect: (context, state) {
      final s = ref.read(authProvider);
      final loc = state.matchedLocation;
      if (s is AuthUnknown || s is AuthOffline) return loc == '/splash' ? null : '/splash';
      if (loc == '/splash') return splashIntroDone.value ? '/home' : null; // let the logo intro finish
      final signedIn = s is SignedIn;
      if (!signedIn && _protected.any(loc.startsWith)) return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      if (signedIn && (loc == '/login' || loc == '/otp')) return state.uri.queryParameters['from'] ?? '/home';
      if (signedIn && !s.user.profileComplete && loc != '/profile-setup') return '/profile-setup';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, s) => LoginScreen(from: s.uri.queryParameters['from'])),
      GoRoute(path: '/otp', builder: (_, s) => OtpScreen(phone: s.uri.queryParameters['phone'] ?? '', from: s.uri.queryParameters['from'])),
      GoRoute(path: '/profile-setup', builder: (_, _) => const ProfileSetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/categories', builder: (_, s) => CategoriesScreen(initialSlug: s.uri.queryParameters['c'])),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: '/cart', builder: (_, _) => const CartScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/search', builder: (_, s) => SearchScreen(initialQuery: s.uri.queryParameters['q'])),
      GoRoute(path: '/product/:slug', builder: (_, s) => ProductDetailScreen(slug: s.pathParameters['slug']!)),
      GoRoute(path: '/bag', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(path: '/order-success/:id', builder: (_, s) => OrderSuccessScreen(orderId: s.pathParameters['id']!)),
      GoRoute(path: '/order/:id', builder: (_, s) => OrderDetailScreen(orderId: s.pathParameters['id']!)),
      GoRoute(path: '/addresses', builder: (_, s) => AddressesScreen(selectMode: s.uri.queryParameters['select'] == '1')),
      GoRoute(path: '/address', builder: (_, s) => AddressFormScreen(addressId: s.uri.queryParameters['id'])),
      GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: '/help', builder: (_, _) => const HelpScreen()),
      GoRoute(path: '/about', builder: (_, _) => const AboutScreen()),
    ],
    errorBuilder: (_, _) => const Scaffold(body: Center(child: Text('Page not found'))),
  );
});
