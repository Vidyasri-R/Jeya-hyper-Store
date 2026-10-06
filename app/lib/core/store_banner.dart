import 'package:flutter/painting.dart';

import 'theme.dart';

/// A home banner the store manages in the admin app (public config `home.banners`):
/// an image, a text card, or both; tapping opens a search, category or product.
class StoreBanner {
  const StoreBanner({required this.id, this.image, this.tag, this.title, this.subtitle, this.cta, this.background, this.route});

  final String id;
  final String? image, tag, title, subtitle, cta;

  /// Card colour behind the text (null = the brand's soft colour).
  final Color? background;

  /// Where a tap goes (null = the banner is just a picture).
  final String? route;

  /// Image with no text: the picture is the whole banner.
  bool get imageOnly => image != null && title == null;

  /// The banners to show at [now] (active and inside their dates), in the store's order.
  /// Anything malformed is skipped rather than breaking Home.
  static List<StoreBanner> activeFrom(Object? raw, DateTime now) {
    if (raw is! List) return const [];
    final out = <StoreBanner>[];
    for (final item in raw) {
      if (item is! Map || item['active'] != true) continue;
      DateTime? at(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
      final starts = at(item['startsAt']), ends = at(item['endsAt']);
      if (starts != null && now.isBefore(starts)) continue;
      if (ends != null && now.isAfter(ends)) continue;
      String? str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
      final url = str(item['image']);
      final image = url != null && url.startsWith('https://') ? url : null;
      final title = str(item['title']);
      if (image == null && title == null) continue;
      out.add(StoreBanner(
        id: str(item['id']) ?? '${out.length}',
        image: image,
        tag: str(item['tag']),
        title: title,
        subtitle: str(item['subtitle']),
        cta: str(item['cta']),
        background: Palettes.parseHex(item['background']),
        route: routeOf(item['link']),
      ));
    }
    return out;
  }

  static String? routeOf(Object? link) {
    if (link is! Map) return null;
    final value = link['value'];
    if (value is! String || value.trim().isEmpty) return null;
    final v = value.trim();
    return switch (link['type']) {
      'search' => '/search?q=${Uri.encodeQueryComponent(v)}',
      'category' => '/categories?c=${Uri.encodeQueryComponent(v)}',
      'product' => '/product/${Uri.encodeComponent(v)}',
      _ => null,
    };
  }
}
