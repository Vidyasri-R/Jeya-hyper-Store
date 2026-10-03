import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import '../core/money.dart';
import '../data/models.dart';
import '../data/repository.dart';

final tokenStoreProvider = Provider((_) => TokenStore());

final repositoryProvider = Provider<Repository>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  final api = ApiClient(tokens, onSessionExpired: () async => ref.read(authProvider.notifier).sessionExpired());
  return Repository(api, tokens);
});

// ───────────────────────────── Auth ─────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthUnknown extends AuthState {
  const AuthUnknown();
}

class SignedOut extends AuthState {
  const SignedOut();
}

/// Saved session exists but the server couldn't be reached at launch.
class AuthOffline extends AuthState {
  const AuthOffline();
}

class SignedIn extends AuthState {
  const SignedIn(this.user);
  final AppUser user;
}

class AuthController extends Notifier<AuthState> {
  /// Lets go_router re-run redirects when auth changes.
  final refresh = ValueNotifier<int>(0);

  @override
  AuthState build() {
    _restore();
    return const AuthUnknown();
  }

  void _set(AuthState next) {
    state = next;
    refresh.value++;
  }

  Future<void> _restore() async {
    final repo = ref.read(repositoryProvider);
    if (await repo.tokens.read() == null) return _set(const SignedOut());
    try {
      _set(SignedIn(await repo.me()));
    } on ApiException catch (e) {
      if (e.isNetwork || e.status >= 500) {
        // Offline / server hiccup at launch: keep the session, let the user retry.
        _set(const AuthOffline());
      } else {
        await repo.tokens.clear();
        _set(const SignedOut());
      }
    }
  }

  Future<void> retry() async {
    _set(const AuthUnknown());
    await _restore();
  }

  // Cart and addresses watch isSignedInProvider, so they refetch on their own when the
  // session changes — invalidating them from here would be a circular dependency.
  void signedIn(AppUser user) => _set(SignedIn(user));

  void userUpdated(AppUser user) => _set(SignedIn(user));

  Future<void> logout() async {
    await ref.read(repositoryProvider).logout();
    _set(const SignedOut());
  }

  Future<void> deleteAccount() async {
    await ref.read(repositoryProvider).deleteAccount();
    _set(const SignedOut());
  }

  Future<void> sessionExpired() async => _set(const SignedOut());
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

final isSignedInProvider = Provider((ref) => ref.watch(authProvider) is SignedIn);

// ───────────────────────────── Catalogue ─────────────────────────────

final categoriesProvider = FutureProvider<List<Category>>((ref) => ref.watch(repositoryProvider).categories());

/// Admin → Store settings → Pause orders. Null when orders are open.
final storePausedMessageProvider = FutureProvider<String?>((ref) async {
  final config = await ref.watch(repositoryProvider).publicConfig();
  final pause = config['app.maintenance'];
  if (pause is Map && pause['enabled'] == true) {
    final message = (pause['message'] as String?)?.trim() ?? '';
    return message.isEmpty ? "We're not taking orders right now. Please check back soon." : message;
  }
  return null;
});

final productProvider = FutureProvider.family<Product, String>((ref, slug) => ref.watch(repositoryProvider).product(slug));

typedef ProductQuery = ({String? category, String? q, String? sort, bool inStock});

class ProductListState {
  const ProductListState({this.items = const [], this.cursor, this.loading = false, this.done = false, this.error});
  final List<Product> items;
  final String? cursor;
  final bool loading;
  final bool done;
  final ApiException? error;

  ProductListState copyWith({List<Product>? items, String? cursor, bool? loading, bool? done, ApiException? error, bool clearError = false}) =>
      ProductListState(
        items: items ?? this.items,
        cursor: cursor ?? this.cursor,
        loading: loading ?? this.loading,
        done: done ?? this.done,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Cursor-paged product list for a (category, search, sort) combination — infinite scroll.
class ProductListController extends FamilyNotifier<ProductListState, ProductQuery> {
  @override
  ProductListState build(ProductQuery arg) {
    Future.microtask(loadMore);
    return const ProductListState(loading: true);
  }

  Future<void> loadMore() async {
    if (state.done || (state.loading && state.items.isNotEmpty)) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await ref.read(repositoryProvider).products(
            category: arg.category,
            q: arg.q,
            sort: arg.sort,
            inStock: arg.inStock,
            cursor: state.cursor,
          );
      state = ProductListState(
        items: [...state.items, ...page.items],
        cursor: page.nextCursor,
        done: page.nextCursor == null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }
}

final productListProvider =
    NotifierProvider.family<ProductListController, ProductListState, ProductQuery>(ProductListController.new);

// ───────────────────────────── Cart ─────────────────────────────

/// Server cart with optimistic quantities so steppers feel instant.
class CartController extends AsyncNotifier<Cart> {
  final Map<int, int> _pending = {};

  @override
  Future<Cart> build() async {
    if (!ref.watch(isSignedInProvider)) return Cart.empty;
    return ref.read(repositoryProvider).cart();
  }

  int qtyFor(int productId) => _pending[productId] ?? state.valueOrNull?.qtyFor(productId) ?? 0;

  Future<void> setQty(Product product, int milli) async {
    _pending[product.id] = milli;
    ref.notifyListeners();
    try {
      final cart = await ref.read(repositoryProvider).setQty(product.id, milliToString(milli));
      _pending.remove(product.id);
      state = AsyncData(cart);
    } on ApiException {
      _pending.remove(product.id);
      ref.notifyListeners();
      rethrow;
    }
  }

  Future<void> refresh() async => state = AsyncData(await ref.read(repositoryProvider).cart());

  Future<void> fix() async => state = AsyncData(await ref.read(repositoryProvider).fixCart());

  void replace(Cart cart) => state = AsyncData(cart);
}

final cartProvider = AsyncNotifierProvider<CartController, Cart>(CartController.new);

/// Badge count on the Cart tab.
final cartCountProvider = Provider<int>((ref) => ref.watch(cartProvider).valueOrNull?.lines.length ?? 0);

// ───────────────────────────── Addresses ─────────────────────────────

final addressesProvider = FutureProvider<List<Address>>((ref) async {
  if (!ref.watch(isSignedInProvider)) return const [];
  return ref.watch(repositoryProvider).addresses();
});

/// Address chosen for delivery (defaults to the user's default address).
final selectedAddressIdProvider = StateProvider<String?>((ref) => null);

final selectedAddressProvider = Provider<Address?>((ref) {
  final list = ref.watch(addressesProvider).valueOrNull ?? const [];
  if (list.isEmpty) return null;
  final id = ref.watch(selectedAddressIdProvider);
  return list.firstWhere((a) => a.id == id, orElse: () => list.firstWhere((a) => a.isDefault, orElse: () => list.first));
});
