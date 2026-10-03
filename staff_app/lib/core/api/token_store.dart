import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

/// Keystore-backed storage on Android; on web, flutter_secure_storage encrypts into localStorage.
/// Keys are distinct from the customer app's so the two can never mix sessions.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _access = 'jeya.staff.accessToken';
  static const _refresh = 'jeya.staff.refreshToken';

  AuthTokens? _cache;

  Future<AuthTokens?> read() async {
    if (_cache != null) return _cache;
    final access = await _storage.read(key: _access);
    final refresh = await _storage.read(key: _refresh);
    if (access == null || refresh == null) return null;
    return _cache = AuthTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> save(AuthTokens tokens) async {
    _cache = tokens;
    await _storage.write(key: _access, value: tokens.accessToken);
    await _storage.write(key: _refresh, value: tokens.refreshToken);
  }

  Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
  }
}
