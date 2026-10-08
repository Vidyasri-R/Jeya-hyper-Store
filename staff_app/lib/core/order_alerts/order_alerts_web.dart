import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../data/repository.dart';
import '../order_alerts.dart';

/// web/alerts.js
@JS('jeyaAlerts')
external _Alerts? get _alerts;

extension type _Alerts._(JSObject _) implements JSObject {
  external JSString support();
  external JSString permission();
  external JSPromise<JSString?> current();
  external JSPromise<JSString> enable(JSString publicKey);
  external JSPromise<JSString?> disable();
}

/// Fetched before the tap: on iPhone, asking for permission must happen in the tap itself.
String? _publicKey;

String get _label {
  final agent = web.window.navigator.userAgent;
  return 'Web: ${agent.length > 150 ? agent.substring(0, 150) : agent}';
}

Future<AlertStatus> status(StaffRepository repo) async {
  final alerts = _alerts;
  if (alerts == null) return (support: AlertSupport.unsupported, on: false, blocked: false);
  final support = switch (alerts.support().toDart) {
    'ready' => AlertSupport.ready,
    'home-screen' => AlertSupport.needsHomeScreen,
    _ => AlertSupport.unsupported,
  };
  if (support != AlertSupport.ready) return (support: support, on: false, blocked: false);
  try {
    _publicKey ??= await repo.webPushKey();
  } catch (_) {
    // Offline: fetched again on the tap.
  }
  final permission = alerts.permission().toDart;
  final current = (await alerts.current().toDart)?.toDart;
  return (support: AlertSupport.ready, on: current != null && permission == 'granted', blocked: permission == 'denied');
}

Future<void> enable(StaffRepository repo) async {
  final alerts = _alerts;
  if (alerts == null) throw const AlertException('This browser cannot show order alerts.');
  final key = _publicKey;
  if (key == null) {
    _publicKey = await repo.webPushKey();
    throw const AlertException('Ready — tap "Turn on" once more.');
  }
  final String subscription;
  try {
    subscription = (await alerts.enable(key.toJS).toDart).toDart;
  } catch (e) {
    if (e.toString().contains('blocked')) {
      throw const AlertException('Notifications are blocked for Jeya Staff. Allow them in the browser settings (iPhone: Settings → Notifications → Jeya Staff), then try again.');
    }
    if (e.toString().contains('dismissed')) throw const AlertException('Tap "Allow" when the phone asks, to get order alerts.');
    throw AlertException('Could not turn on alerts here ($e).');
  }
  await repo.saveWebPush(Map<String, dynamic>.from(jsonDecode(subscription) as Map), _label);
}

Future<void> disable(StaffRepository repo) async {
  final endpoint = (await _alerts?.disable().toDart)?.toDart;
  if (endpoint == null) return;
  try {
    await repo.removeWebPush(endpoint);
  } catch (_) {
    // The browser already dropped it; the server removes it on its next send.
  }
}

/// The browser may renew the subscription, and another person may sign in here: tell the server.
Future<void> resume(StaffRepository repo) async {
  final alerts = _alerts;
  if (alerts == null || alerts.support().toDart != 'ready' || alerts.permission().toDart != 'granted') return;
  final current = (await alerts.current().toDart)?.toDart;
  if (current == null) return;
  try {
    await repo.saveWebPush(Map<String, dynamic>.from(jsonDecode(current) as Map), _label);
  } catch (_) {}
}
