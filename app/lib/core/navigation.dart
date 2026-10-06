import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The bottom-bar tabs. Going to one switches tab; anything else is pushed on top, so the
/// system back button returns to the screen the customer came from.
const _tabs = ['/home', '/categories', '/cart', '/orders', '/profile'];

bool isTabRoute(String route) => _tabs.any((t) => route == t || route.startsWith('$t?') || route.startsWith('$t/'));

/// Open an in-app link (banners, "see all", deep links) with the right back behaviour.
void openRoute(BuildContext context, String route) {
  if (isTabRoute(route)) {
    context.go(route);
  } else {
    context.push(route);
  }
}

/// The cart opened from anywhere but its own tab: pushed, so back returns to that screen.
void openCart(BuildContext context) => context.push('/bag');
