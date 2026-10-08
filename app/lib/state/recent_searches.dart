import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// What the customer searched for lately (newest first), kept on this phone / browser only.
class RecentSearches extends Notifier<List<String>> {
  RecentSearches([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'jhs.recentSearches';
  static const max = 8;

  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null) return;
      final list = [for (final v in jsonDecode(raw) as List) v.toString()];
      if (state.isEmpty) state = list.take(max).toList();
    } catch (_) {
      // Unreadable history: start again.
    }
  }

  Future<void> _save() async {
    try {
      await _storage.write(key: _key, value: jsonEncode(state));
    } catch (_) {
      // Private browsing / storage off: history stays for this visit only.
    }
  }

  /// [query] goes to the top (an earlier copy, any case, is dropped).
  void add(String query) {
    final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.length < 2 || q.length > 100) return;
    state = [q, for (final s in state) if (s.toLowerCase() != q.toLowerCase()) s].take(max).toList();
    _save();
  }

  void remove(String query) {
    state = [for (final s in state) if (s != query) s];
    _save();
  }

  void clear() {
    state = const [];
    _save();
  }

  /// Earlier searches that contain what is being typed (all of them while the box is empty).
  List<String> matching(String typed, {int limit = 3}) {
    final q = typed.trim().toLowerCase();
    if (q.isEmpty) return state;
    return state.where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q).take(limit).toList();
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);
