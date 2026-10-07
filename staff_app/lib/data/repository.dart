import 'dart:typed_data';

import '../core/api/api_client.dart';
import '../core/api/token_store.dart';
import 'models.dart';

/// Every call the staff app makes (see backend/docs/staff-api.md).
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
  Future<(ResultPage<AdminProduct>, Map<String, int>)> products({String? query, String filter = 'all', String? cursor}) async {
    final body = await _api.get(
      '/admin/products',
      query: {if (query != null && query.trim().isNotEmpty) 'q': query.trim(), 'filter': filter, 'cursor': ?cursor, 'limit': 30},
    );
    final counts = Map<String, dynamic>.from((body['counts'] as Map?) ?? const {});
    return (
      ResultPage([for (final p in body['products'] as List) AdminProduct.fromJson(Map<String, dynamic>.from(p as Map))], body['nextCursor'] as String?),
      {for (final e in counts.entries) e.key: (e.value as num).toInt()},
    );
  }

  Future<void> updateProduct(int id, Map<String, dynamic> patch) => _api.patch('/admin/products/$id', body: patch);

  /// Any staff role: admins for any product, others for products assigned to them.
  Future<String> uploadPhoto(int id, Uint8List bytes, String contentType) async =>
      (await _api.putBytes('/staff/photos/$id/image', bytes, contentType))['imageUrl'] as String;

  Future<void> removePhoto(int id) => _api.delete('/admin/products/$id/image');

  // ── admin: daily stock file ──
  /// Last import, the import settings and the website categories.
  Future<Map<String, dynamic>> stockImportStatus() => _api.get('/admin/catalog/import');

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

  /// My products to photograph, and my counts (any staff role).
  Future<(ResultPage<AdminProduct>, Map<String, int>)> myPhotos({String? cursor}) async {
    final body = await _api.get('/staff/photos/mine', query: {'cursor': ?cursor});
    return (
      ResultPage([for (final p in body['products'] as List) AdminProduct.fromJson(Map<String, dynamic>.from(p as Map))], body['nextCursor'] as String?),
      {for (final k in ['open', 'done', 'doneToday']) k: (body[k] as num? ?? 0).toInt()},
    );
  }

  // ── admin: home banners ──
  /// Uploads a banner picture (cropped to 2:1 by the server); returns its URL for the banner.
  Future<String> uploadBannerImage(Uint8List bytes, String contentType) async =>
      (await _api.putBytes('/admin/banners/image', bytes, contentType))['imageUrl'] as String;

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
