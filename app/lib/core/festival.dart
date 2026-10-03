import 'theme.dart';

/// Admin → Store settings → App theme (public config `app.theme`):
/// `{ preset: 'standard' | 'diwali', startsAt?, endsAt?, greeting? }`.
/// Active while now is inside [startsAt, endsAt] (either end may be open).
class FestivalTheme {
  const FestivalTheme({required this.preset, this.greeting, this.startsAt, this.endsAt});

  final String preset;
  final String? greeting;
  final DateTime? startsAt;
  final DateTime? endsAt;

  BrandPalette get palette => Palettes.byId(preset);

  bool get isDiwali => preset == 'diwali';

  /// Greeting strip on Home.
  String get headline => (greeting != null && greeting!.trim().isNotEmpty) ? greeting!.trim() : _defaultGreeting;

  String get _defaultGreeting => switch (preset) {
    'diwali' => 'Happy Diwali from Jeya Hyper Store!',
    _ => '',
  };

  String get subline => switch (preset) {
    'diwali' => 'Sweets, dry fruits, gifts & pooja essentials',
    _ => '',
  };

  String get emoji => switch (preset) {
    'diwali' => '🪔',
    _ => '',
  };

  /// The theme in effect at [now], or null for the everyday look.
  static FestivalTheme? activeFrom(Object? raw, DateTime now) {
    if (raw is! Map) return null;
    final preset = raw['preset'];
    if (preset is! String || preset == 'standard' || Palettes.byId(preset).id != preset) return null;
    DateTime? at(Object? value) => value is String ? DateTime.tryParse(value)?.toLocal() : null;
    final theme = FestivalTheme(preset: preset, greeting: raw['greeting'] as String?, startsAt: at(raw['startsAt']), endsAt: at(raw['endsAt']));
    if (theme.startsAt != null && now.isBefore(theme.startsAt!)) return null;
    if (theme.endsAt != null && now.isAfter(theme.endsAt!)) return null;
    return theme;
  }
}
