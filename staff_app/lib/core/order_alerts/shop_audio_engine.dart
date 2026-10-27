import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Shop audio, inside the phone's background service: at every ad break of the shop TV's plan it
/// takes Android's audio focus (the owner's music app pauses, as for a phone call), plays the ad's
/// sound through the phone's speaker / Bluetooth, and gives the focus back (the music carries on).
/// The plan comes from the server, so the sound lines up with the TV's picture.
class ShopAudioEngine {
  ShopAudioEngine({required this.http, required this.saveStatus});

  final HttpClient http;
  final Future<void> Function(Map<String, Object?> status) saveStatus;

  /// Ask for the plan this often (the plan covers the next 90 minutes).
  static const _refreshEvery = Duration(seconds: 60);

  Map<String, dynamic>? _state;
  int _offsetMs = 0; // server clock − phone clock
  DateTime _fetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _timer;
  String? _scheduledId;
  String? _playingId;
  String? _error;
  Map<String, Object?>? _last;
  AudioPlayer? _player;
  AudioSession? _session;
  Directory? _dir;

  int get _now => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  /// Called every 20 s by the service; refreshes the plan when due and keeps the next break armed.
  Future<void> tick({required String api, required String key}) async {
    if (DateTime.now().difference(_fetchedAt) >= _refreshEvery || _state == null) await _refresh(api, key);
    _arm();
    await _report();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _player?.stop();
    await _session?.setActive(false);
  }

  Future<void> dispose() async {
    await stop();
    await _player?.dispose();
    _player = null;
  }

  /// The "Test" button: plays the first ad with sound right now.
  Future<void> test() async {
    final media = (_state?['media'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final first = media.where(_hasSound).firstOrNull;
    if (first == null) {
      _error = 'No video or announcement to test with yet';
      return _report();
    }
    await _playBreak({
      'id': 'test-${DateTime.now().millisecondsSinceEpoch}',
      'at': _now,
      'durationMs': (first['durationMs'] as int?) ?? 30000,
      'items': [
        {'id': first['id'], 'offsetMs': 0, 'durationMs': (first['durationMs'] as int?) ?? 30000},
      ],
    });
  }

  Future<void> _refresh(String api, String key) async {
    try {
      final sentAt = DateTime.now().millisecondsSinceEpoch;
      final request = await http.getUrl(Uri.parse('$api/staff/alerts/shop-audio'));
      request.headers.set('x-device-key', key);
      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        _error = response.statusCode == 401 ? 'This phone is not set up — turn Shop audio off and on again' : 'Server busy (${response.statusCode})';
        return;
      }
      final receivedAt = DateTime.now().millisecondsSinceEpoch;
      final json = jsonDecode(body) as Map<String, dynamic>;
      _offsetMs = (json['serverNow'] as int) - (sentAt + receivedAt) ~/ 2;
      _state = json;
      _fetchedAt = DateTime.now();
      _error = null;
      await _cache((json['media'] as List).cast<Map<String, dynamic>>());
    } catch (e) {
      _error = 'Offline — using the last plan';
    }
  }

  static bool _hasSound(Map<String, dynamic> m) => m['mediaType'] == 'video' || m['mediaType'] == 'audio';

  Future<File> _fileFor(Map<String, dynamic> m) async {
    _dir ??= Directory('${(await getApplicationSupportDirectory()).path}/shop_audio')..createSync(recursive: true);
    final url = m['url'] as String;
    final ext = url.contains('.') ? url.split('.').last.split('?').first : 'bin';
    return File('${_dir!.path}/${m['id']}.$ext');
  }

  /// Keeps a copy of every ad with sound (plays without internet; nothing downloads during a break).
  Future<void> _cache(List<Map<String, dynamic>> media) async {
    final wanted = <String>{};
    for (final m in media.where(_hasSound)) {
      final file = await _fileFor(m);
      wanted.add(file.path);
      if (file.existsSync() && file.lengthSync() == m['bytes']) continue;
      try {
        final request = await http.getUrl(Uri.parse(m['url'] as String));
        final response = await request.close();
        if (response.statusCode != 200) continue;
        final part = File('${file.path}.part');
        await response.pipe(part.openWrite());
        await part.rename(file.path);
      } catch (_) {
        // Next refresh tries again.
      }
    }
    for (final f in _dir?.listSync() ?? const <FileSystemEntity>[]) {
      if (f is File && !wanted.contains(f.path) && !f.path.endsWith('.part')) f.deleteSync();
    }
  }

  void _arm() {
    final breaks = (_state?['breaks'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final next = breaks.where((b) => (b['at'] as int) > _now + 500).firstOrNull;
    if (next == null || next['id'] == _scheduledId) return;
    _timer?.cancel();
    _scheduledId = next['id'] as String;
    _timer = Timer(Duration(milliseconds: (next['at'] as int) - _now), () => unawaited(_playBreak(next)));
  }

  Future<void> _playBreak(Map<String, dynamic> b) async {
    if (_playingId != null) return;
    _playingId = b['id'] as String;
    final settings = (_state?['settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final withSound = settings['adSound'] != 'tv';
    final volume = ((settings['phoneVolume'] as int?) ?? 100) / 100;
    final media = {for (final m in (_state?['media'] as List? ?? const []).cast<Map<String, dynamic>>()) m['id'] as String: m};
    final start = b['at'] as int;
    try {
      _session ??= await AudioSession.instance;
      await _session!.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(contentType: AndroidAudioContentType.music, usage: AndroidAudioUsage.media),
        // Transient: the music app pauses and resumes by itself afterwards.
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        androidWillPauseWhenDucked: true,
      ));
      // Hold the focus for the whole break, so the music stays paused between two ads.
      await _session!.setActive(true);
      _player ??= AudioPlayer(handleAudioSessionActivation: false, handleInterruptions: false);
      for (final item in (b['items'] as List).cast<Map<String, dynamic>>()) {
        final m = media[item['id']];
        final startsAt = start + (item['offsetMs'] as int);
        final wait = startsAt - _now;
        if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
        final length = item['durationMs'] as int;
        if (m != null && withSound && _hasSound(m)) {
          final file = await _fileFor(m);
          if (file.existsSync()) {
            await _player!.setFilePath(file.path);
            await _player!.setVolume(volume);
            unawaited(_player!.play());
            _last = {'title': m['title'], 'at': DateTime.now().toIso8601String()};
            await _report(playing: m['title'] as String?);
          }
        }
        final left = startsAt + length - _now;
        if (left > 0) await Future<void>.delayed(Duration(milliseconds: left));
        await _player?.stop();
      }
    } catch (e) {
      _error = 'Could not play the ad sound: $e';
    } finally {
      await _player?.stop();
      await _session?.setActive(false);
      _playingId = null;
      _arm();
      await _report();
    }
  }

  Future<void> _report({String? playing}) {
    final breaks = (_state?['breaks'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final next = breaks.where((b) => (b['at'] as int) > _now).firstOrNull;
    final media = (_state?['media'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return saveStatus({
      'nextAt': next == null ? null : (next['at'] as int) - _offsetMs,
      'playing': playing,
      'last': _last,
      'error': _error,
      'ads': media.where(_hasSound).length,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }
}

/// Saved by the service, read by the Shop audio screen.
const shopAudioStatusData = 'shopAudio.status';

Future<void> saveShopAudioStatus(Map<String, Object?> status) => FlutterForegroundTask.saveData(key: shopAudioStatusData, value: jsonEncode(status));
