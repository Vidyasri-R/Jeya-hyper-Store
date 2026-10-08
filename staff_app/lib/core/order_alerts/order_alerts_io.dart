import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_foreground_task/flutter_foreground_task.dart' hide NotificationVisibility;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/repository.dart';
import '../config.dart';
import '../order_alerts.dart';

// Shared with the background service (its own isolate) through the plugin's storage.
const _keyData = 'alerts.deviceKey';
const _afterData = 'alerts.after';
const _apiData = 'alerts.api';

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
  return (support: AlertSupport.ready, on: key != null && running, blocked: permission == NotificationPermission.permanently_denied);
}

Future<void> enable(StaffRepository repo) async {
  if (!Platform.isAndroid) throw const AlertException('Order alerts work on Android phones and in the web app.');
  var permission = await FlutterForegroundTask.checkNotificationPermission();
  if (permission != NotificationPermission.granted) permission = await FlutterForegroundTask.requestNotificationPermission();
  if (permission != NotificationPermission.granted) {
    throw const AlertException('Allow notifications for Jeya Staff (phone Settings → Apps → Jeya Staff → Notifications), then try again.');
  }
  // Without this, Android may stop the service to save battery and orders go unheard.
  if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) await FlutterForegroundTask.requestIgnoreBatteryOptimization();
  var key = await FlutterForegroundTask.getData<String>(key: _keyData);
  if (key == null) {
    key = await repo.registerAlertPhone('Android app');
    await FlutterForegroundTask.saveData(key: _keyData, value: key);
    await FlutterForegroundTask.removeData(key: _afterData);
  }
  await FlutterForegroundTask.saveData(key: _apiData, value: AppConfig.apiBaseUrl);
  await _start();
}

Future<void> disable(StaffRepository repo) async {
  await FlutterForegroundTask.stopService();
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
  final result = await (await FlutterForegroundTask.isRunningService
      ? FlutterForegroundTask.restartService()
      : FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: [ForegroundServiceTypes.remoteMessaging],
          notificationTitle: 'Ready for new orders',
          notificationText: 'Jeya Staff rings when an order comes in, even when the app is closed',
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
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async => _http.close(force: true);

  Future<void> _check() async {
    if (_busy) return;
    _busy = true;
    try {
      final key = await FlutterForegroundTask.getData<String>(key: _keyData);
      if (key == null) return;
      final api = await FlutterForegroundTask.getData<String>(key: _apiData) ?? AppConfig.apiBaseUrl;
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
