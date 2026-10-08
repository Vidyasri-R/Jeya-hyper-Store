import '../data/repository.dart';
import 'order_alerts/order_alerts_io.dart' if (dart.library.js_interop) 'order_alerts/order_alerts_web.dart' as impl;

/// Can this device ring for new orders while the app is closed?
enum AlertSupport {
  ready,
  /// iPhone browser: alerts work once the site is added to the Home Screen (iOS 16.4+).
  needsHomeScreen,
  unsupported,
}

typedef AlertStatus = ({AlertSupport support, bool on, bool blocked});

/// A message for the person (permission refused, tap again…).
class AlertException implements Exception {
  const AlertException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// New-order alerts while the store app is closed: on Android a background service asks the server
/// about new orders and rings; browsers and the iPhone home-screen app get Web Push.
abstract final class OrderAlerts {
  static Future<AlertStatus> status(StaffRepository repo) => impl.status(repo);

  /// Call straight from a button tap: browsers only ask for permission during a tap.
  static Future<void> enable(StaffRepository repo) => impl.enable(repo);

  static Future<void> disable(StaffRepository repo) => impl.disable(repo);

  /// Signed in at app start: brings the alerts back if they were on (service / subscription).
  static Future<void> resume(StaffRepository repo) => impl.resume(repo);
}
