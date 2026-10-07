import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import 'models.dart';

/// Typed access to the Jeya API (see backend/docs/*.md for contracts).
class Repository {
  Repository(this.api, this.tokens);
  final ApiClient api;
  final TokenStore tokens;

  // ── Auth ──
  Future<int> requestOtp(String phone) async {
    final res = await api.post('/auth/otp/request', body: {'phone': phone}, auth: false);
    return (res['resendAfterSec'] as int?) ?? 30;
  }

  Future<({AppUser user, bool isNewUser})> verifyOtp(String phone, String otp) async {
    final res = await api.post('/auth/otp/verify', body: {'phone': phone, 'otp': otp, 'deviceInfo': 'flutter'}, auth: false);
    await tokens.save(AuthTokens(accessToken: res['accessToken'] as String, refreshToken: res['refreshToken'] as String));
    return (user: AppUser.fromJson(res['user'] as Map<String, dynamic>), isNewUser: res['isNewUser'] == true);
  }

  Future<void> logout() async {
    final t = await tokens.read();
    if (t != null) {
      try {
        await api.post('/auth/logout', body: {'refreshToken': t.refreshToken}, auth: false);
      } catch (_) {
        // Server-side revoke is best-effort; local sign-out always happens.
      }
    }
    await tokens.clear();
  }

  Future<AppUser> me() async => AppUser.fromJson((await api.get('/me'))['user'] as Map<String, dynamic>);

  Future<AppUser> updateProfile({String? name, String? email}) async => AppUser.fromJson(
        (await api.patch('/me', body: {'name': ?name, 'email': ?email}))['user'] as Map<String, dynamic>,
      );

  Future<void> deleteAccount() async {
    await api.delete('/me');
    await tokens.clear();
  }

  // ── Catalogue ──
  Future<List<Category>> categories() async =>
      ((await api.get('/categories', auth: false))['categories'] as List).cast<Map<String, dynamic>>().map(Category.fromJson).toList();

  Future<ProductPage> products({String? category, String? q, String? sort, bool inStock = false, String? cursor, int limit = 20}) async =>
      ProductPage.fromJson(await api.get('/products', auth: false, query: {
        'category': ?category,
        if (q != null && q.isNotEmpty) 'q': q,
        'sort': ?sort,
        if (inStock) 'inStock': 'true',
        'cursor': ?cursor,
        'limit': limit,
      }));

  /// Home lists: "Today's offers" and "Popular in your store" (picked by the store, else automatic).
  Future<({List<Product> offers, List<Product> popular})> home() async {
    final j = await api.get('/home', auth: false);
    List<Product> list(String key) => [for (final p in (j[key] as List? ?? const [])) Product.fromJson(Map<String, dynamic>.from(p as Map))];
    return (offers: list('offers'), popular: list('popular'));
  }

  Future<Product> product(String slug) async =>
      Product.fromJson((await api.get('/products/$slug', auth: false))['product'] as Map<String, dynamic>);

  /// Products matching what the customer is typing, with their photo (or category photo).
  Future<List<Suggestion>> suggest(String q) async => [
        for (final s in (await api.get('/search/suggest', auth: false, query: {'q': q}))['suggestions'] as List)
          (
            slug: (s as Map)['slug'] as String,
            name: s['name'] as String,
            imageUrl: s['imageUrl'] as String?,
            placeholderImageUrl: s['placeholderImageUrl'] as String?,
          ),
      ];

  // ── Cart ──
  Future<Cart> cart() async => Cart.fromJson((await api.get('/cart'))['cart'] as Map<String, dynamic>);
  Future<Cart> setQty(int productId, String qty) async =>
      Cart.fromJson((await api.put('/cart/items/$productId', body: {'quantity': qty}))['cart'] as Map<String, dynamic>);
  Future<Cart> fixCart() async => Cart.fromJson((await api.post('/cart/fix'))['cart'] as Map<String, dynamic>);
  Future<void> clearCart() async => api.delete('/cart');

  // ── Addresses & delivery ──
  Future<List<Address>> addresses() async =>
      ((await api.get('/me/addresses'))['addresses'] as List).cast<Map<String, dynamic>>().map(Address.fromJson).toList();
  Future<Address> createAddress(Map<String, dynamic> body) async =>
      Address.fromJson((await api.post('/me/addresses', body: body))['address'] as Map<String, dynamic>);
  Future<Address> updateAddress(String id, Map<String, dynamic> body) async =>
      Address.fromJson((await api.patch('/me/addresses/$id', body: body))['address'] as Map<String, dynamic>);
  Future<void> deleteAddress(String id) async => api.delete('/me/addresses/$id');

  Future<Map<String, dynamic>> deliveryEstimate(double lat, double lng) =>
      api.get('/delivery/estimate', auth: false, query: {'lat': lat, 'lng': lng});

  // ── Checkout, orders, payments ──
  Future<Quote> quote(String addressId) async => Quote.fromJson((await api.post('/checkout/quote', body: {'addressId': addressId}))['quote'] as Map<String, dynamic>);

  Future<Order> placeOrder({required String addressId, required String paymentMethod, required String idempotencyKey, required String expectedTotal, String? note}) async =>
      Order.fromJson((await api.post('/orders', body: {
        'addressId': addressId,
        'paymentMethod': paymentMethod,
        'idempotencyKey': idempotencyKey,
        'expectedTotal': expectedTotal,
        if (note != null && note.isNotEmpty) 'customerNote': note,
      }))['order'] as Map<String, dynamic>);

  Future<({List<Order> orders, String? nextCursor})> orders({String? cursor}) async {
    final res = await api.get('/orders', query: {'cursor': ?cursor, 'limit': 20});
    return (
      orders: (res['orders'] as List).cast<Map<String, dynamic>>().map(Order.fromJson).toList(),
      nextCursor: res['nextCursor'] as String?,
    );
  }

  Future<Order> order(String id) async => Order.fromJson((await api.get('/orders/$id'))['order'] as Map<String, dynamic>);
  Future<Order> cancelOrder(String id, {String? reason}) async =>
      Order.fromJson((await api.post('/orders/$id/cancel', body: {'reason': ?reason}))['order'] as Map<String, dynamic>);

  Future<PaymentInit> startPayment(String orderId) async =>
      PaymentInit.fromJson((await api.post('/orders/$orderId/payment'))['payment'] as Map<String, dynamic>);
  Future<String> confirmPayment(String orderId, {required String razorpayOrderId, required String paymentId, required String signature}) async =>
      (await api.post('/orders/$orderId/payment/confirm', body: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      }))['status'] as String;

  Future<Map<String, dynamic>> publicConfig() async => (await api.get('/config', auth: false))['config'] as Map<String, dynamic>;
}
