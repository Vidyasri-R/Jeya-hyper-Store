import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_foreground_task/flutter_foreground_task.dart' hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/repository.dart';
import '../config.dart';
import '../order_alerts.dart';
import 'shop_audio_engine.dart';

// Shared with the background service (its own isolate) through the plugin's storage.
const _keyData = 'alerts.deviceKey';
const _afterData = 'alerts.after';
const _apiData = 'alerts.api';
/// false = the service runs only for Shop audio (this phone doesn't ring for orders).
const _ringData = 'alerts.ring';
const _shopData = 'shopAudio.on';

const _serviceId = 7001;
const _channelId = 'new_orders';
const _channelName = 'New orders';
/// The service asks the server this often (ms).
const _every = 20000;
/// Android's FLAG_INSISTENT: the sound repeats until the notification is opened or swiped away.
const _insistent = 4;

Future<AlertStatus> status(StaffRepository repo) async {
  if (!Platform.isAndroid) return (support: AlertSupport.unsupported, on: false, blocked: false);
  final key = await FlutterForegroundTask.getData<String>(key: _keyData);
  final running = await FlutterForegroundTask.isRunningService;
  final permission = await FlutterForegroundTask.checkNotificationPermission();
  final ring = await FlutterForegroundTask.getData<bool>(key: _ringData) ?? true;
  return (support: AlertSupport.ready, on: key != null && running && ring, blocked: permission == NotificationPermission.permanently_denied);
}

Future<void> enable(StaffRepository repo) async {
  if (!Platform.isAndroid) throw const AlertException('Order alerts work on Android phones and in the web app.');
  await _register(repo, 'Android app');
  await FlutterForegroundTask.saveData(key: _ringData, value: true);
  await _start();
}

/// Permissions, battery exemption and the device key (shared by order alerts and Shop audio).
Future<void> _register(StaffRepository repo, String label) async {
  var permission = await FlutterForegroundTask.checkNotificationPermission();
  if (permission != NotificationPermission.granted) permission = await FlutterForegroundTask.requestNotificationPermission();
  if (permission != NotificationPermission.granted) {
    throw const AlertException('Allow notifications for Jeya Staff (phone Settings → Apps → Jeya Staff → Notifications), then try again.');
  }
  // Without this, Android may stop the service to save battery and orders go unheard.
  if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  var key = await FlutterForegroundTask.getData<String>(key: _keyData);
  if (key == null) {
    key = await repo.registerAlertPhone(label);
    await FlutterForegroundTask.saveData(key: _keyData, value: key);
    await FlutterForegroundTask.removeData(key: _afterData);
  }
  await FlutterForegroundTask.saveData(key: _apiData, value: AppConfig.apiBaseUrl);
}

Future<void> disable(StaffRepository repo) async {
  // Shop audio still needs the service: only stop ringing.
  if (await FlutterForegroundTask.getData<bool>(key: _shopData) ?? false) {
    await FlutterForegroundTask.saveData(key: _ringData, value: false);
    await _start();
    return;
  }
  await _stopAll(repo);
}

Future<void> _stopAll(StaffRepository repo) async {
  await FlutterForegroundTask.stopService();
  await FlutterForegroundTask.removeData(key: _ringData);
  await FlutterForegroundTask.removeData(key: _shopData);
  final key = await FlutterForegroundTask.getData<String>(key: _keyData);
  await FlutterForegroundTask.removeData(key: _keyData);
  await FlutterForegroundTask.removeData(key: _afterData);
  if (key != null) {
    try {
      await repo.removeAlertPhone(key);
    } catch (_) {
      // Offline: the server forgets the phone once its key stops being used… or an admin
      // deactivates the account; either way this phone no longer rings.
    }
  }
}

Future<void> resume(StaffRepository repo) async {
  if (!Platform.isAndroid) return;
  final key = await FlutterForegroundTask.getData<String>(key: _keyData);
  if (key != null && !await FlutterForegroundTask.isRunningService) await _start();
}

/* ── Shop audio (same service) ── */

typedef ShopAudioInfo = ({bool supported, bool on, Map<String, dynamic>? status});

Future<ShopAudioInfo> shopAudioStatus() async {
  if (!Platform.isAndroid) return (supported: false, on: false, status: null);
  final on = (await FlutterForegroundTask.getData<bool>(key: _shopData) ?? false) && await FlutterForegroundTask.isRunningService;
  final raw = await FlutterForegroundTask.getData<String>(key: shopAudioStatusData);
  return (supported: true, on: on, status: raw == null ? null : jsonDecode(raw) as Map<String, dynamic>);
}

Future<void> enableShopAudio(StaffRepository repo) async {
  if (!Platform.isAndroid) throw const AlertException('Shop audio works on Android phones.');
  final hadKey = await FlutterForegroundTask.getData<String>(key: _keyData) != null;
  final ringing = hadKey && (await FlutterForegroundTask.getData<bool>(key: _ringData) ?? true) && await FlutterForegroundTask.isRunningService;
  await _register(repo, 'Shop audio phone');
  // Turning Shop audio on doesn't make this phone ring for orders unless it already did.
  await FlutterForegroundTask.saveData(key: _ringData, value: ringing);
  await FlutterForegroundTask.saveData(key: _shopData, value: true);
  await _start();
}

Future<void> disableShopAudio(StaffRepository repo) async {
  await FlutterForegroundTask.saveData(key: _shopData, value: false);
  await FlutterForegroundTask.removeData(key: shopAudioStatusData);
  if (await FlutterForegroundTask.getData<bool>(key: _ringData) ?? true) {
    await _start();
  } else {
    await _stopAll(repo);
  }
}

/// Plays the first ad's sound now (pausing the music), to check the speakers.
void testShopAudio() => FlutterForegroundTask.sendDataToTask('shopAudio.test');

void _init() => FlutterForegroundTask.init(
  androidNotificationOptions: AndroidNotificationOptions(
    channelId: 'order_watch',
    channelName: 'Ready for orders',
    channelDescription: 'Keeps Jeya Staff ready to ring when an order comes in',
    channelImportance: NotificationChannelImportance.LOW,
    priority: NotificationPriority.LOW,
    onlyAlertOnce: true,
  ),
  iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
  foregroundTaskOptions: ForegroundTaskOptions(
    eventAction: ForegroundTaskEventAction.repeat(_every),
    autoRunOnBoot: true,
    autoRunOnMyPackageReplaced: true,
    allowWakeLock: true,
    allowWifiLock: true,
  ),
);

Future<void> _start() async {
  _init();
  final ring = await FlutterForegroundTask.getData<bool>(key: _ringData) ?? true;
  final shop = await FlutterForegroundTask.getData<bool>(key: _shopData) ?? false;
  final title = shop ? (ring ? 'Shop audio on · ready for orders' : 'Shop audio on') : 'Ready for new orders';
  final text = shop ? 'Pauses the music for the shop TV\u2019s ad breaks and plays the ad sound' : 'Jeya Staff rings when an order comes in, even when the app is closed';
  final result = await (await FlutterForegroundTask.isRunningService
      ? FlutterForegroundTask.restartService()
      : FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: [ForegroundServiceTypes.remoteMessaging, if (shop) ForegroundServiceTypes.mediaPlayback],
          notificationTitle: title,
          notificationText: text,
          callback: orderAlertTask,
        ));
  if (result is ServiceRequestFailure) throw AlertException('Could not start order alerts: ${result.error}');
}

/// Runs in the background service's own isolate.
@pragma('vm:entry-point')
void orderAlertTask() => FlutterForegroundTask.setTaskHandler(_AlertTask());

class _AlertTask extends TaskHandler {
  final _notes = FlutterLocalNotificationsPlugin();
  final _http = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  late final _shop = ShopAudioEngine(http: _http, saveStatus: saveShopAudioStatus);
  bool _busy = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _notes.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    await _notes
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Rings when a customer places an order',
            importance: Importance.max,
            sound: RawResourceAndroidNotificationSound('new_order'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
          ),
        );
    await _check();
  }

  @override
  void onRepeatEvent(DateTime timestamp) => unawaited(_check());

  @override
  void onReceiveData(Object data) {
    if (data == 'shopAudio.test') unawaited(_shop.test());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _shop.dispose();
    _http.close(force: true);
  }

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final key = await FlutterForegroundTask.getData<String>(key: _keyData);
      if (key == null) return;
      final api = await FlutterForegroundTask.getData<String>(key: _apiData) ?? AppConfig.apiBaseUrl;
      if (await FlutterForegroundTask.getData<bool>(key: _shopData) ?? false) {
        await _shop.tick(api: api, key: key);
      } else {
        await _shop.stop();
      }
      if (!(await FlutterForegroundTask.getData<bool>(key: _ringData) ?? true)) return;
      final after = await FlutterForegroundTask.getData<String>(key: _afterData);
      final uri = Uri.parse('$api/staff/alerts/new-orders').replace(queryParameters: {'after': ?after});
      final request = await _http.getUrl(uri);
      request.headers.set('x-device-key', key);
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 401) {
        // Account switched off or the phone removed: stop asking.
        await FlutterForegroundTask.removeData(key: _keyData);
        await FlutterForegroundTask.stopService();
        return;
      }
      if (response.statusCode != 200) return;
      final json = jsonDecode(body) as Map<String, dynamic>;
      for (final order in (json['orders'] as List).cast<Map<String, dynamic>>()) {
        await _ring(order);
      }
      await FlutterForegroundTask.saveData(key: _afterData, value: json['now'] as String);
    } catch (_) {
      // Offline / server restarting: the next round asks again (nothing is lost — "after" stays).
    } finally {
      _busy = false;
    }
  }

  Future<void> _ring(Map<String, dynamic> order) => _notes.show(
    (order['id'] as String).hashCode & 0x7fffffff,
    order['title'] as String?,
    order['body'] as String?,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Rings when a customer places an order',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        sound: const RawResourceAndroidNotificationSound('new_order'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        visibility: NotificationVisibility.public,
        ticker: 'New order',
        additionalFlags: Int32List.fromList(const [_insistent]),
      ),
    ),
  );
}
