import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/festival.dart';

import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import '../core/money.dart';
import '../core/theme.dart';
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

/// Public remote config (store info, delivery rules, pause message…); the API caches it for a minute.
final publicConfigProvider = FutureProvider<Map<String, dynamic>>((ref) => ref.watch(repositoryProvider).publicConfig());

/// Re-checks festival start/end times during long sessions.
final _themeClockProvider = StreamProvider<DateTime>((ref) => Stream.periodic(const Duration(minutes: 10), (_) => DateTime.now()));

/// Build-time preview of a festival look (screenshots, trying a new preset): `--dart-define=PREVIEW_THEME=diwali`.
const _previewTheme = String.fromEnvironment('PREVIEW_THEME');

/// Same for the brand colour: `--dart-define=PREVIEW_BRAND=#1E4FA8`.
const _previewBrand = String.fromEnvironment('PREVIEW_BRAND');

/// The store's public settings remembered from the last run (read in main, see ConfigCache), used
/// until the server answers — so the splash is already festive and prices/rules survive offline.
final savedConfigProvider = Provider<Map<String, dynamic>?>((ref) => null);

/// Live settings when loaded, else the remembered ones.
Map<String, dynamic>? _settings(Ref ref) => ref.watch(publicConfigProvider).valueOrNull ?? ref.watch(savedConfigProvider);

/// The festival theme in effect now (Admin → Store settings → App theme), or null for the everyday look.
final festivalProvider = Provider<FestivalTheme?>((ref) {
  if (_previewTheme.isNotEmpty) return FestivalTheme(preset: _previewTheme);
  ref.watch(_themeClockProvider);
  return FestivalTheme.activeFrom(_settings(ref)?['app.theme'], DateTime.now());
});

/// The everyday colours (Admin → Store settings → Brand colour, public config `app.brand`).
/// Festival themes take over on their dates; see [festivalProvider].
final brandPaletteProvider = Provider<BrandPalette>((ref) {
  final preview = Palettes.parseHex(_previewBrand);
  if (preview != null) return Palettes.fromColor(preview);
  final raw = _settings(ref)?['app.brand'];
  final color = Palettes.parseHex(raw is Map ? raw['color'] : null);
  return color == null ? Palettes.standard : Palettes.fromColor(color);
});

/// How fast the store delivers — Admin → Store settings → Deliver within (delivery.rules.deliveryDays).
class DeliverySpeed {
  const DeliverySpeed(this.days);
  final int days;

  /// "Next-day" (badge, paired with "delivery")
  String get short => switch (days) { 0 => 'Same-day', 1 => 'Next-day', _ => '$days-day' };

  /// "Next-day delivery"
  String get headline => switch (days) { 0 => 'Same-day delivery', 1 => 'Next-day delivery', _ => 'Delivery in $days days' };

  /// "by the next day"
  String get phrase => switch (days) { 0 => 'the same day', 1 => 'by the next day', _ => 'within $days days' };
}

final deliverySpeedProvider = Provider<DeliverySpeed>((ref) {
  final rules = _settings(ref)?['delivery.rules'];
  return DeliverySpeed(rules is Map && rules['deliveryDays'] is num ? (rules['deliveryDays'] as num).toInt() : 1);
});

/// Delivery and payment rules from Admin → Store settings. The server applies them to every cart
/// quote and order; the app uses them for banners, cart tips and help text.
class StoreRules {
  const StoreRules({this.freeAbovePaise = 99900, this.minOrderPaise = 0, this.lowestFeePaise, this.cod = true, this.online = true});

  /// Orders at or above this are delivered free (0 = always free); null when delivery is never free.
  final int? freeAbovePaise;
  final int minOrderPaise;

  /// Cheapest distance band.
  final int? lowestFeePaise;
  final bool cod;
  final bool online;

  factory StoreRules.from(Map<String, dynamic>? settings) {
    if (settings == null) return const StoreRules();
    final rules = settings['delivery.rules'];
    final pay = settings['checkout.payment_methods'];
    int? paise(Object? v) => v is String ? toPaise(v) : null;
    final tiers = rules is Map && rules['tiers'] is List ? rules['tiers'] as List : const [];
    final fees = [for (final t in tiers) if (t is Map && paise(t['fee']) != null) paise(t['fee'])!]..sort();
    return StoreRules(
      freeAbovePaise: rules is Map ? paise(rules['freeDeliveryAbove']) : 99900,
      minOrderPaise: rules is Map ? paise(rules['minOrderAmount']) ?? 0 : 0,
      lowestFeePaise: fees.isEmpty ? null : fees.first,
      cod: pay is Map ? pay['cod'] != false : true,
      online: pay is Map ? pay['online'] == true : true,
    );
  }
}

final storeRulesProvider = Provider<StoreRules>((ref) => StoreRules.from(_settings(ref)));

/// The address map: our own Trichy-area tiles on R2 (design/maps — no map API, no key, no fee),
/// read from `map.tiles` so the tiles can move to the custom domain without an app update.
class MapTiles {
  const MapTiles({required this.url, this.minZoom = 11, this.maxNativeZoom = 16, this.bounds});

  final String url;
  final double minZoom;
  final int maxNativeZoom;

  /// West, south, east, north — the map can't be panned away from the area the tiles cover.
  final List<double>? bounds;

  static const fallback = MapTiles(
    url: 'https://cdn.jeyahyperstore.in/maps/trichy/v1/{z}/{x}/{y}.webp',
    bounds: [78.5, 10.68, 78.8, 10.95],
  );

  static MapTiles from(Object? raw) {
    if (raw is! Map || raw['url'] is! String) return fallback;
    final b = raw['bounds'];
    return MapTiles(
      url: raw['url'] as String,
      minZoom: (raw['minZoom'] as num?)?.toDouble() ?? fallback.minZoom,
      maxNativeZoom: (raw['maxNativeZoom'] as num?)?.toInt() ?? fallback.maxNativeZoom,
      bounds: b is List && b.length == 4 && b.every((v) => v is num) ? [for (final v in b) (v as num).toDouble()] : fallback.bounds,
    );
  }
}

final mapTilesProvider = Provider<MapTiles>((ref) => MapTiles.from(_settings(ref)?['map.tiles']));

/// Admin → Store settings → Pause orders. Null when orders are open.
final storePausedMessageProvider = FutureProvider<String?>((ref) async {
  final config = await ref.watch(publicConfigProvider.future);
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
