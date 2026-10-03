import 'package:flutter/painting.dart';

/// Artwork and copy for one festival look. The art is original vector illustration rendered to
/// WebP at 3× (sources: design/festival-art/); Admin → Store settings → Festival theme turns it on.
class FestivalPack {
  const FestivalPack({
    required this.id,
    required this.dir,
    required this.greeting,
    required this.question,
    required this.heroAspect,
    required this.flames,
    required this.banners,
    this.halo,
  });

  final String id;

  /// Asset folder, e.g. assets/themes/diwali.
  final String dir;

  /// "Happy Deepavali" (+ ", Name!") and the line under it on Home.
  final String greeting;
  final String question;

  /// The festival's centrepiece on the header and splash (diyas, a pongal pot…): width ÷ height.
  final double heroAspect;

  /// Where flames flicker on [hero], as fractions of the image: (x, y of the flame's base, size).
  final List<(double, double, double)> flames;

  /// Illustrated banners that lead the Home carousel.
  final List<FestivalBanner> banners;

  /// Optional art rising behind the splash logo card (the Pongal sun).
  final String? halo;

  String _art(String name) => '$dir/$name.webp';

  String get headerBackground => _art('header_bg');
  String get splashBackground => _art('splash_bg');
  String get thoranam => _art('thoranam');
  String get hero => _art('hero');
  String get flame => _art('flame');
  String get sectionIcon => _art('section_icon');
  String? get haloImage => halo == null ? null : _art(halo!);

  /// Seamless gold-sparkle tile laid over festive buttons.
  ImageProvider get buttonTexture => ExactAssetImage(_art('btn_tile'), scale: 3);

  /// Sprites for the once-per-visit petal shower.
  List<String> get petals => [_art('petal_1'), _art('petal_2'), _art('petal_3'), _art('petal_4')];
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
    heroAspect: 480 / 270,
    flames: [(0.2458, 0.5556, 0.2458), (0.5, 0.4667, 0.3125), (0.7542, 0.5556, 0.2458)],
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

  /// Surya Pongal: sunrise, kolam, sugarcane and a pongal pot boiling over on its hearth.
  static const pongal = FestivalPack(
    id: 'pongal',
    dir: 'assets/themes/pongal',
    greeting: 'Happy Pongal',
    question: 'Fresh harvest, delivered',
    heroAspect: 480 / 300,
    flames: [(0.425, 0.8533, 0.0792), (0.5083, 0.86, 0.0958), (0.5833, 0.8533, 0.075)],
    halo: 'sun',
    banners: [
      FestivalBanner(
        image: 'assets/themes/pongal/banner_essentials.webp',
        tag: 'PONGAL SPECIAL',
        title: 'Pongal\nessentials',
        subtitle: 'Rice, jaggery, dal & ghee',
        cta: 'Shop now',
        route: '/search?q=jaggery',
      ),
      FestivalBanner(
        image: 'assets/themes/pongal/banner_harvest.webp',
        tag: 'FRESH HARVEST',
        title: 'Sugarcane &\nveggies',
        subtitle: 'For your Pongal kootu',
        cta: 'Shop fresh',
        route: '/categories',
        dark: true,
      ),
      FestivalBanner(
        image: 'assets/themes/pongal/banner_kolam.webp',
        tag: 'KOLAM & POOJA',
        title: 'Kolam colours\n& pooja',
        subtitle: 'Flowers, camphor & more',
        cta: 'Explore',
        route: '/search?q=camphor',
      ),
    ],
  );

  static FestivalPack? byId(String? id) => switch (id) {
    'diwali' => diwali,
    'pongal' => pongal,
    _ => null,
  };
}

/// The festival art in effect, set together with `AppColors.palette` (null on everyday days).
abstract final class Festive {
  static FestivalPack? pack;
}
