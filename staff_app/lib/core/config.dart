/// Build-time configuration. Override with --dart-define, e.g.
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/v1
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://jeya-api.onrender.com/v1');

  static const appName = 'Jeya Staff';
  static const storeName = 'Jeya Hyper Store';

  /// Order board poll while the app is open. The server answers from memory unless an
  /// order changed, so this is cheap on the free-tier bandwidth budget.
  static const boardPoll = Duration(seconds: 20);

  /// Wide screens (the store computer) get side-by-side list + detail and a navigation rail.
  static const wideLayout = 1000.0;
}
