import 'dart:typed_data';

import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import 'models.dart';

/// Every call the staff app makes (see backend/docs/staff-api.md).
/// A home list for the admin: [pinned] extras (shown first), [automatic] products, [hidden] ones.
typedef HomeList = ({List<AdminProduct> pinned, List<AdminProduct> automatic, List<AdminProduct> hidden});

/// One person in the photo race.
typedef Racer = ({int rank, String name, int photos, bool isMe});

class StaffRepository {
  StaffRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  Future<bool> hasSession() async => await _tokens.read() != null;

  Future<Staff> _saveSession(Map<String, dynamic> body) async {
    await _tokens.save(AuthTokens(accessToken: body['accessToken'] as String, refreshToken: body['refreshToken'] as String));
    return Staff.fromJson(Map<String, dynamic>.from(body['staff'] as Map));
  }

  // ── auth ──
  Future<Staff> login(String username, String password, String deviceInfo) async =>
      _saveSession(await _api.post('/staff/auth/login', body: {'username': username, 'password': password, 'deviceInfo': deviceInfo}, auth: false));

  Future<Staff> me() async => Staff.fromJson(Map<String, dynamic>.from((await _api.get('/staff/me'))['staff'] as Map));

  Future<Staff> changePassword(String current, String next) async =>
      _saveSession(await _api.post('/staff/me/password', body: {'currentPassword': current, 'newPassword': next}));

  Future<void> logout() async {
    final tokens = await _tokens.read();
    await _tokens.clear();
    if (tokens != null) {
      try {
        await _api.post('/staff/auth/logout', body: {'refreshToken': tokens.refreshToken}, auth: false);
      } catch (_) {
        // Signed out locally either way; the server session expires on its own.
      }
    }
  }

  // ── order board ──
  Future<BoardSummary> summary() async => BoardSummary.fromJson(await _api.get('/staff/orders/summary'));

  Future<ResultPage<OrderCard>> orders({required String tab, String? query, String? cursor}) async {
    final body = await _api.get(
      '/staff/orders',
      query: {'tab': tab, if (query != null && query.trim().length >= 2) 'q': query.trim(), 'cursor': ?cursor, 'limit': 30},
    );
    return ResultPage([for (final o in body['orders'] as List) OrderCard.fromJson(Map<String, dynamic>.from(o as Map))], body['nextCursor'] as String?);
  }

  Future<OrderDetail> order(String id) async => OrderDetail.fromJson(Map<String, dynamic>.from((await _api.get('/staff/orders/$id'))['order'] as Map));

  Future<OrderDetail> advance(
    String id, {
    required String from,
    required String to,
    String? note,
    List<Map<String, dynamic>>? packedItems,
    String? codCollectedAmount,
  }) async {
    final body = await _api.post(
      '/staff/orders/$id/advance',
      body: {
        'from': from,
        'to': to,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (packedItems != null && packedItems.isNotEmpty) 'packedItems': packedItems,
        'codCollectedAmount': ?codCollectedAmount,
      },
    );
    return OrderDetail.fromJson(Map<String, dynamic>.from(body['order'] as Map));
  }

  Future<OrderDetail> cancel(String id, {required String from, required String reason}) async =>
      OrderDetail.fromJson(Map<String, dynamic>.from((await _api.post('/staff/orders/$id/cancel', body: {'from': from, 'reason': reason}))['order'] as Map));

  // ── admin: staff accounts ──
  Future<List<Staff>> staffList() async => [
    for (final s in (await _api.get('/admin/staff'))['staff'] as List) Staff.fromJson(Map<String, dynamic>.from(s as Map)),
  ];

  /// Returns (staff, temporaryPassword).
  Future<(Staff, String)> createStaff({required String username, required String name, String? phone, required String role}) async {
    final body = await _api.post(
      '/admin/staff',
      body: {'username': username, 'name': name, 'phone': (phone == null || phone.isEmpty) ? null : phone, 'role': role},
    );
    return (Staff.fromJson(Map<String, dynamic>.from(body['staff'] as Map)), body['temporaryPassword'] as String);
  }

  Future<Staff> updateStaff(String id, Map<String, dynamic> patch) async =>
      Staff.fromJson(Map<String, dynamic>.from((await _api.patch('/admin/staff/$id', body: patch))['staff'] as Map));

  Future<String> resetPassword(String id) async => (await _api.post('/admin/staff/$id/reset-password'))['temporaryPassword'] as String;

  // ── admin: settings ──
  Future<Map<String, dynamic>> settings() async => Map<String, dynamic>.from((await _api.get('/admin/settings'))['settings'] as Map);

  Future<Object?> saveSetting(String key, Object? value) async => (await _api.put('/admin/settings/$key', body: {'value': value}))['value'];

  // ── admin: products ──
  /// [categoryId]: that category and its sub-categories.
  Future<(ResultPage<AdminProduct>, Map<String, int>)> products({String? query, String filter = 'all', int? categoryId, String? cursor}) async {
    final body = await _api.get(
      '/admin/products',
      query: {if (query != null && query.trim().isNotEmpty) 'q': query.trim(), 'filter': filter, 'categoryId': ?categoryId, 'cursor': ?cursor, 'limit': 30},
    );
    final counts = Map<String, dynamic>.from((body['counts'] as Map?) ?? const {});
    return (
      ResultPage([for (final p in body['products'] as List) AdminProduct.fromJson(Map<String, dynamic>.from(p as Map))], body['nextCursor'] as String?),
      {for (final e in counts.entries) e.key: (e.value as num).toInt()},
    );
  }

  Future<void> updateProduct(int id, Map<String, dynamic> patch) => _api.patch('/admin/products/$id', body: patch);

  /// Any staff role: admins for any product, others for products assigned to them.
  /// [clean]: false keeps the picture as it is (no white-background clean-up on the server).
  Future<String> uploadPhoto(int id, Uint8List bytes, String contentType, {bool clean = true}) async =>
      (await _api.putBytes('/staff/photos/$id/image', bytes, contentType, query: clean ? null : {'clean': '0'}))['imageUrl'] as String;

  Future<void> removePhoto(int id) => _api.delete('/admin/products/$id/image');

  /// After a barcode change: the photo still matches the pack on the shelf.
  Future<void> confirmPhoto(int id) => _api.post('/staff/photos/$id/photo-ok');

  /// Photo of one choice (a flavour / pen design); returns its URL for the product's options.
  Future<String> uploadChoicePhoto(int id, Uint8List bytes, String contentType) async =>
      (await _api.putBytes('/admin/products/$id/choice-image', bytes, contentType))['imageUrl'] as String;

  /// [options]: {label, values, images} or null to remove; [allSizes]: same choices for every size.
  Future<int> saveChoices(int id, Map<String, dynamic>? options, {bool allSizes = false}) async =>
      (((await _api.patch('/admin/products/$id', body: {'options': options, 'optionsForAllSizes': allSizes}))['product'] as Map?)?['sizesUpdated'] as num? ?? 1)
          .toInt();

  /// The photo race: photos each person added in [period] ('today' | 'week' | 'all'), best first.
  Future<List<Racer>> photoRace(String period) async => [
    for (final r in (await _api.get('/staff/photos/leaderboard', query: {'period': period}))['racers'] as List)
      (rank: ((r as Map)['rank'] as num).toInt(), name: r['name'] as String, photos: (r['photos'] as num).toInt(), isMe: r['isMe'] == true),
  ];

  // ── new-order alerts while the app is closed ──
  /// Browser / iPhone home-screen app: the server's Web Push key.
  Future<String> webPushKey() async => (await _api.get('/staff/alerts/web-push'))['publicKey'] as String;

  /// [subscription]: the browser's PushSubscription as JSON ({endpoint, keys: {p256dh, auth}}).
  Future<void> saveWebPush(Map<String, dynamic> subscription, String label) => _api.post('/staff/alerts/web-push', body: {
    'endpoint': subscription['endpoint'],
    'keys': {'p256dh': (subscription['keys'] as Map)['p256dh'], 'auth': (subscription['keys'] as Map)['auth']},
    'label': label,
  });

  Future<void> removeWebPush(String endpoint) => _api.post('/staff/alerts/web-push/remove', body: {'endpoint': endpoint});

  /// Android: a device key for the background service (it asks for new orders with it).
  Future<String> registerAlertPhone(String label) async => (await _api.post('/staff/alerts/android', body: {'label': label}))['deviceKey'] as String;

  Future<void> removeAlertPhone(String deviceKey) => _api.post('/staff/alerts/android/remove', body: {'deviceKey': deviceKey}, auth: false);

  /// "Same product, new code?": pairs (old code → new code) waiting for an answer, and how many in all.
  Future<({int total, List<({AdminProduct old, AdminProduct neu})> pairs})> newCodes({int limit = 40}) async {
    final body = await _api.get('/admin/catalog/new-codes', query: {'limit': limit});
    return (
      total: (body['total'] as num).toInt(),
      pairs: [
        for (final p in body['pairs'] as List)
          (old: AdminProduct.fromJson(Map<String, dynamic>.from((p as Map)['old'] as Map)), neu: AdminProduct.fromJson(Map<String, dynamic>.from(p['new'] as Map))),
      ],
    );
  }

  /// [same]: the new code gets the old one's photo and details; the old code leaves the shop when sold out.
  /// Returns whether the photo was copied.
  Future<bool> decideNewCode(int oldId, int newId, {required bool same}) async =>
      (await _api.post('/admin/catalog/new-codes/decide', body: {'oldId': oldId, 'newId': newId, 'same': same}))['copiedPhoto'] == true;

  /// Takes the choices off every other size of the product; returns how many.
  Future<int> clearOtherSizesChoices(int id) async =>
      (((await _api.patch('/admin/products/$id', body: {'clearOtherSizesOptions': true}))['product'] as Map?)?['otherSizesCleared'] as num? ?? 0).toInt();

  // ── admin: daily stock file ──
  /// Last import, the import settings and the website categories.
  Future<Map<String, dynamic>> whatsappStatus() => _api.get('/admin/whatsapp');

  /// Sends the login_code template with a throwaway code; returns {sent, code, messageId}.
  Future<Map<String, dynamic>> whatsappTest(String phone) => _api.post('/admin/whatsapp/test', body: {'phone': phone});

  Future<bool> setWhatsappLogin(bool on) async => (await _api.put('/admin/whatsapp/login', body: {'on': on}))['loginOn'] == true;

  Future<Map<String, dynamic>> stockImportStatus() => _api.get('/admin/catalog/import');

  /// Move a POS group ([type]) or single items to a website category — now and on every import.
  Future<int> moveProducts({required String category, required List<String> itemCodes, String? type}) async =>
      ((await _api.post('/admin/catalog/move', body: {'category': category, 'itemCodes': itemCodes, 'type': ?type}))['moved'] as num? ?? 0).toInt();

  /// Preview (apply: false) or import (apply: true) a GoFrugal "Current Stock Detail" CSV.
  Future<Map<String, dynamic>> importStockFile(Uint8List csv, {required bool apply}) =>
      _api.postBytes('/admin/catalog/import', csv, 'text/csv', query: {'apply': '$apply'});

  /// Photo mode: the product behind a scanned barcode, or null.
  Future<AdminProduct?> productByBarcode(String code) async {
    try {
      final body = await _api.get('/staff/photos/by-barcode/${Uri.encodeComponent(code)}');
      return AdminProduct.fromJson(Map<String, dynamic>.from(body['product'] as Map));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  // ── photo work ──
  /// Totals and each person's progress (admin).
  Future<Map<String, dynamic>> photoWork() => _api.get('/admin/photo-work');

  /// Products without photos, best first (admin). assignee: staff id, 'unassigned' or 'any'.
  Future<ResultPage<AdminProduct>> photoQueue({String assignee = 'any', String? cursor}) async {
    final body = await _api.get('/admin/photo-work/queue', query: {'assignee': assignee, 'cursor': ?cursor});
    return ResultPage([for (final p in body['products'] as List) AdminProduct.fromJson(Map<String, dynamic>.from(p as Map))], body['nextCursor'] as String?);
  }

  Future<int> assignPhotos(String staffId, int count, {int? categoryId}) async =>
      ((await _api.post('/admin/photo-work/assign', body: {'staffId': staffId, 'count': count, 'categoryId': ?categoryId}))['assigned'] as num).toInt();

  Future<int> unassignPhotos(String staffId) async => ((await _api.post('/admin/photo-work/unassign', body: {'staffId': staffId}))['released'] as num).toInt();

  /// Photos added by me ([staffId] null) or by someone (admin review), newest first.
  Future<ResultPage<AdminProduct>> donePhotos({String? staffId, String? cursor}) async {
    final body = staffId == null
        ? await _api.get('/staff/photos/mine/done', query: {'cursor': ?cursor})
        : await _api.get('/admin/photo-work/done', query: {'staffId': staffId, 'cursor': ?cursor});
    return ResultPage([for (final p in body['products'] as List) AdminProduct.fromJson(Map<String, dynamic>.from(p as Map))], body['nextCursor'] as String?);
  }

  /// My products to photograph, and my counts (any staff role).
  Future<(ResultPage<AdminProduct>, Map<String, int>)> myPhotos({String? cursor}) async {
    final body = await _api.get('/staff/photos/mine', query: {'cursor': ?cursor});
    return (
      ResultPage([for (final p in body['products'] as List) AdminProduct.fromJson(Map<String, dynamic>.from(p as Map))], body['nextCursor'] as String?),
      {
        for (final k in ['open', 'done', 'doneToday', 'takeMoreBatch']) k: (body[k] as num? ?? 0).toInt(),
        'canTakeMore': body['canTakeMore'] == true ? 1 : 0,
      },
    );
  }

  /// My list is done: take the next batch myself. Returns how many I got.
  Future<int> takeMorePhotos() async => ((await _api.post('/staff/photos/mine/more'))['assigned'] as num).toInt();

  // ── admin: home banners ──
  /// Uploads a banner picture (cropped to 2:1 by the server); returns its URL for the banner.
  // ── admin: finance (online shop) ──
  /// Sales, costs, margin and profit between two IST days ("2026-10-01").
  Future<Map<String, dynamic>> finance(String from, String to) => _api.get('/admin/finance', query: {'from': from, 'to': to});

  Future<(List<Map<String, dynamic>>, List<String>)> expenses(String from, String to) async {
    final body = await _api.get('/admin/expenses', query: {'from': from, 'to': to});
    return (
      [for (final e in body['expenses'] as List) Map<String, dynamic>.from(e as Map)],
      [for (final c in body['categories'] as List) c.toString()],
    );
  }

  Future<void> addExpense({required String spentOn, required String category, required String amount, String? note}) =>
      _api.post('/admin/expenses', body: {'spentOn': spentOn, 'category': category, 'amount': amount, 'note': ?note});

  Future<void> removeExpense(int id) => _api.delete('/admin/expenses/$id');

  // ── admin: premium customers ──
  Future<List<Map<String, dynamic>>> members() async => [for (final m in (await _api.get('/admin/members'))['members'] as List) Map<String, dynamic>.from(m as Map)];

  Future<void> saveMember({required String phone, String? name, required bool freeDelivery, required double discountPercent, String? note, bool isActive = true}) =>
      _api.put('/admin/members', body: {'phone': phone, 'name': ?name, 'freeDelivery': freeDelivery, 'discountPercent': discountPercent, 'note': ?note, 'isActive': isActive});

  Future<void> removeMember(String phone) => _api.delete('/admin/members/$phone');

  // ── admin: category photos & customer home lists ──
  /// Shop categories with their photo (parents first, then their children).
  Future<List<Map<String, dynamic>>> shopCategories() async =>
      [for (final c in (await _api.get('/admin/categories'))['categories'] as List) Map<String, dynamic>.from(c as Map)];

  Future<String> uploadCategoryPhoto(int id, Uint8List bytes, String contentType) async =>
      (await _api.putBytes('/admin/categories/$id/image', bytes, contentType))['imageUrl'] as String;

  Future<void> removeCategoryPhoto(int id) => _api.delete('/admin/categories/$id/image');

  /// The category's own picture on the shop's tiles (main and sub-categories).
  Future<String> uploadCategoryTile(int id, Uint8List bytes, String contentType, {bool clean = true}) async =>
      (await _api.putBytes('/admin/categories/$id/tile-image', bytes, contentType, query: clean ? null : {'clean': '0'}))['imageUrl'] as String;

  Future<void> removeCategoryTile(int id) => _api.delete('/admin/categories/$id/tile-image');

  /// The products picked for "Today's offers" and "Popular in your store", in order.
  /// Each home list as customers see it: pinned extras, the automatic products, and hidden ones.
  Future<({HomeList offers, HomeList popular})> homeLists() async {
    final body = await _api.get('/admin/home-lists');
    HomeList list(String key) {
      final m = Map<String, dynamic>.from(body[key] as Map);
      List<AdminProduct> of(String k) => [for (final p in (m[k] as List? ?? const [])) AdminProduct.fromJson(Map<String, dynamic>.from(p as Map))];
      return (pinned: of('pinned'), automatic: of('automatic'), hidden: of('hidden'));
    }

    return (offers: list('offers'), popular: list('popular'));
  }

  Future<void> saveHomeLists({required List<int> offers, required List<int> popular, required List<int> hiddenOffers, required List<int> hiddenPopular}) async =>
      saveSetting('home.lists', {'offers': offers, 'popular': popular, 'hiddenOffers': hiddenOffers, 'hiddenPopular': hiddenPopular});

  Future<String> uploadBannerImage(Uint8List bytes, String contentType) async =>
      (await _api.putBytes('/admin/banners/image', bytes, contentType))['imageUrl'] as String;

  /// Category picker for products: every shop category ("Dairy › Ice Creams"), children after their parent.
  Future<List<({int id, String name})>> categoryOptions() async {
    final body = await _api.get('/categories', auth: false);
    final out = <({int id, String name})>[];
    void walk(List<dynamic> list, String prefix) {
      for (final c in list) {
        final m = Map<String, dynamic>.from(c as Map);
        out.add((id: (m['id'] as num).toInt(), name: '$prefix${m['name']}'));
        walk((m['children'] as List?) ?? const [], '$prefix${m['name']} › ');
      }
    }

    walk(body['categories'] as List, '');
    return out;
  }

  /// Category picker for banner links: every category, children after their parent.
  Future<List<({String slug, String name})>> bannerCategories() async {
    final body = await _api.get('/categories', auth: false);
    final out = <({String slug, String name})>[];
    void walk(List<dynamic> list, String prefix) {
      for (final c in list) {
        final m = Map<String, dynamic>.from(c as Map);
        out.add((slug: m['slug'] as String, name: '$prefix${m['name']}'));
        walk((m['children'] as List?) ?? const [], '$prefix${m['name']} › ');
      }
    }

    walk(body['categories'] as List, '');
    return out;
  }

  /// Product picker for banner links (the customer app's search suggestions).
  Future<List<({String slug, String name})>> bannerProducts(String query) async {
    final body = await _api.get('/search/suggest', query: {'q': query}, auth: false);
    return [for (final s in body['suggestions'] as List) (slug: (s as Map)['slug'] as String, name: s['name'] as String)];
  }

  // ── admin: dashboard & usage ──
  Future<Map<String, dynamic>> dashboard(int days) => _api.get('/admin/dashboard', query: {'days': days});

  Future<Map<String, dynamic>> usage() => _api.get('/admin/usage');

  Future<Map<String, dynamic>> refreshUsage() => _api.post('/admin/usage/refresh');

  Future<void> acknowledgeAlert(int id) => _api.post('/admin/alerts/$id/ack');

  /// Runs a database backup now; returns the server's backup status afterwards.
  Future<Map<String, dynamic>> runBackup() async => Map<String, dynamic>.from((await _api.post('/admin/backups/run'))['status'] as Map);
}
