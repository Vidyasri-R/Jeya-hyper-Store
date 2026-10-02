/// Build-time configuration. Override with --dart-define, e.g.
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/v1
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://jeya-api.onrender.com/v1');

  static const storeName = 'Jeya Hyper Store';
  static const tagline = 'Your neighbourhood supermarket';
  static const supportEmail = 'jeyahyperstore@gmail.com';
}
