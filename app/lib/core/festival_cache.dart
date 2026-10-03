import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the store's festival setting on the phone, so the next launch (splash included) dresses
/// up before the network answers, and tells Android which launch splash to show next time.
abstract final class FestivalCache {
  static const _key = 'jhs.festivalTheme';
  static const _storage = FlutterSecureStorage();
  static const _splash = MethodChannel('jeya/splash');

  static Future<Object?> read() async {
    try {
      final saved = await _storage.read(key: _key);
      return saved == null ? null : jsonDecode(saved);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(Object? raw) async {
    try {
      raw == null ? await _storage.delete(key: _key) : await _storage.write(key: _key, value: jsonEncode(raw));
    } catch (_) {}
  }

  /// Android 13+ only; elsewhere the call is simply ignored.
  static Future<void> launchSplash({required bool festive}) async {
    try {
      await _splash.invokeMethod<void>('setFestive', {'festive': festive});
    } catch (_) {}
  }
}
