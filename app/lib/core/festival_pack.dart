import 'package:flutter/painting.dart';

/// Artwork and copy for one festival look. The art is original vector illustration rendered to
/// WebP at 3× (sources: design/festival-art/); Admin → Store settings → Festival theme turns it on.
class FestivalPack {
  const FestivalPack({required this.id, required this.dir, required this.greeting, required this.question, required this.wicks, required this.banners});

  final String id;

  /// Asset folder, e.g. assets/themes/diwali.
  final String dir;

  /// "Happy Deepavali" (+ ", Name!") and the line under it on Home.
  final String greeting;
  final String question;

  /// Flame positions on [diyas] as fractions of the image: (x, y of the wick, lamp size).
  final List<(double, double, double)> wicks;

  /// Illustrated banners that lead the Home carousel.
  final List<FestivalBanner> banners;

  String _art(String name) => '$dir/$name.webp';

  String get headerBackground => _art('header_bg');
  String get thoranam => _art('thoranam');
  String get diyas => _art('diyas_base');
  String get flame => _art('flame');
  String get sectionIcon => _art('diya_icon');

  /// Greeting ribbon, drawn as a nine-slice (corners keep their shape at any width).
  ImageProvider get ribbon => ExactAssetImage(_art('strip'), scale: 3);
  static const ribbonSlice = Rect.fromLTRB(50, 10, 320, 40);

  /// Seamless gold-sparkle tile laid over festive buttons.
  ImageProvider get buttonTexture => ExactAssetImage(_art('btn_tile'), scale: 3);

  /// Strip along the top of the bottom bar (tiles horizontally).
  ImageProvider get navBorder => ExactAssetImage(_art('nav_border'), scale: 3);

  /// Sprites for the once-per-visit petal shower.
  List<String> get petals => [_art('petal_orange'), _art('petal_yellow'), _art('petal_red'), _art('marigold_small')];
}

class FestivalBanner {
  const FestivalBanner({
    required this.image,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.route,
    this.dark = false,
  });

  final String image;
  final String tag, title, subtitle, cta;
  final String route;

  /// Light text on dark art.
  final bool dark;
}

abstract final class FestivalPacks {
  static const diwali = FestivalPack(
    id: 'diwali',
    dir: 'assets/themes/diwali',
    greeting: 'Happy Deepavali',
    question: 'Festive essentials, delivered',
    wicks: [(0.2458, 0.5556, 0.2458), (0.5, 0.4667, 0.3125), (0.7542, 0.5556, 0.2458)],
    banners: [
      FestivalBanner(
        image: 'assets/themes/diwali/banner_sweets.webp',
        tag: 'DEEPAVALI SPECIAL',
        title: 'Sweets &\nsavouries',
        subtitle: 'Laddu, murukku & mixture',
        cta: 'Shop sweets',
        route: '/search?q=sweets',
      ),
      FestivalBanner(
        image: 'assets/themes/diwali/banner_pooja.webp',
        tag: 'LIGHT UP YOUR HOME',
        title: 'Oil, ghee &\npooja needs',
        subtitle: 'Nallennai, camphor & agarbatti',
        cta: 'Shop now',
        route: '/search?q=oil',
        dark: true,
      ),
      FestivalBanner(
        image: 'assets/themes/diwali/banner_hamper.webp',
        tag: 'GIFT THE GOODNESS',
        title: 'Dry fruits &\ngift hampers',
        subtitle: 'Cashews, almonds & raisins',
        cta: 'Explore',
        route: '/categories',
      ),
    ],
  );

  static FestivalPack? byId(String? id) => switch (id) {
    'diwali' => diwali,
    _ => null,
  };
}

/// The festival art in effect, set together with `AppColors.palette` (null on everyday days).
abstract final class Festive {
  static FestivalPack? pack;
}
