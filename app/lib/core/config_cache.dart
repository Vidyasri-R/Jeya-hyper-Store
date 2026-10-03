import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the store's public settings (delivery charges, minimum order, festival theme…) on the
/// phone, so the next launch — splash included — shows them before the network answers, and tells
/// Android which launch splash to show next time.
abstract final class ConfigCache {
  static const _key = 'jhs.publicConfig';
  static const _storage = FlutterSecureStorage();
  static const _splash = MethodChannel('jeya/splash');

  static Future<Map<String, dynamic>?> read() async {
    try {
      final saved = await _storage.read(key: _key);
      final value = saved == null ? null : jsonDecode(saved);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(Map<String, dynamic> config) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(config));
    } catch (_) {}
  }

  /// Android 13+ only; elsewhere the call is simply ignored. [preset] null = everyday splash.
  static Future<void> launchSplash(String? preset) async {
    try {
      await _splash.invokeMethod<void>('setTheme', {'preset': preset});
    } catch (_) {}
  }
}
