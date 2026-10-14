import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/account/more_screen.dart';
import 'features/admin/banners_screen.dart';
import 'features/admin/category_photos_screen.dart';
import 'features/admin/dashboard_screen.dart';
import 'features/admin/finance_screen.dart';
import 'features/admin/members_screen.dart';
import 'features/admin/new_codes_screen.dart';
import 'features/admin/home_lists_screen.dart';
import 'features/admin/my_photos_screen.dart';
import 'features/admin/photo_mode_screen.dart';
import 'features/admin/photo_race_screen.dart';
import 'features/admin/photo_work_screen.dart';
import 'features/admin/products_screen.dart';
import 'features/admin/settings_screen.dart';
import 'features/admin/staff_accounts_screen.dart';
import 'features/admin/stock_import_screen.dart';
import 'features/admin/usage_screen.dart';
import 'features/admin/whatsapp_screen.dart';
import 'features/auth/change_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/orders/board_screen.dart';
import 'features/orders/order_detail_view.dart';
import 'features/shell/app_shell.dart';
import 'state/providers.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Admin-only locations; staff are sent back to the board.
const _adminOnly = ['/sales', '/products', '/more/staff', '/more/settings', '/more/usage', '/more/banners', '/more/stock', '/more/photo-work', '/more/categories', '/more/home-lists', '/more/finance', '/more/members', '/more/new-codes', '/more/whatsapp'];

/// Photo helpers only add product photos: their list, the scanner and their account.
bool _photoHelperMayOpen(String at) => at == '/my-photos' || at == '/scan' || at == '/race' || at == '/more' || at == '/password';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/orders',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final at = state.matchedLocation;
      return switch (session) {
        SessionLoading() => at == '/splash' ? null : '/splash',
        SessionUnreachable() => at == '/offline' ? null : '/offline',
        SignedOut() => at == '/login' ? null : '/login',
        SignedIn(:final staff) when staff.mustChangePassword => at == '/welcome' ? null : '/welcome',
        SignedIn(:final staff) when staff.isPhotoHelper && !_photoHelperMayOpen(at) => '/my-photos',
        SignedIn(:final staff) when !staff.isAdmin && _adminOnly.any(at.startsWith) => '/orders',
        SignedIn() when at == '/splash' || at == '/login' || at == '/welcome' || at == '/offline' => '/orders',
        _ => null,
      };
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/offline', builder: (_, _) => const UnreachableScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const ChangePasswordScreen(forced: true)),
      GoRoute(
        path: '/order/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/password', parentNavigatorKey: _rootKey, builder: (_, _) => const ChangePasswordScreen()),
      GoRoute(path: '/scan', parentNavigatorKey: _rootKey, builder: (_, _) => const PhotoModeScreen()),
      // The photo race: every staff member can see it.
      GoRoute(path: '/race', parentNavigatorKey: _rootKey, builder: (_, _) => const PhotoRaceScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/orders', builder: (_, _) => const BoardScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/sales', builder: (_, _) => const DashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/products', builder: (_, _) => const ProductsScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, _) => const MoreScreen(),
                routes: [
                  GoRoute(path: 'staff', builder: (_, _) => const StaffAccountsScreen()),
                  GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
                  GoRoute(path: 'banners', builder: (_, _) => const BannersScreen()),
                  GoRoute(path: 'usage', builder: (_, _) => const UsageScreen()),
                  GoRoute(path: 'stock', builder: (_, _) => const StockImportScreen()),
                  GoRoute(path: 'photo-work', builder: (_, _) => const PhotoWorkScreen()),
                  GoRoute(path: 'categories', builder: (_, _) => const CategoryPhotosScreen()),
                  GoRoute(path: 'home-lists', builder: (_, _) => const HomeListsScreen()),
                  GoRoute(path: 'finance', builder: (_, _) => const FinanceScreen()),
                  GoRoute(path: 'members', builder: (_, _) => const MembersScreen()),
                  GoRoute(path: 'new-codes', builder: (_, _) => const NewCodesScreen()),
                  GoRoute(path: 'whatsapp', builder: (_, _) => const WhatsAppScreen()),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/my-photos', builder: (_, _) => const MyPhotosScreen())],
          ),
        ],
      ),
    ],
  );
});
