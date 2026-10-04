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
    this.greetingsFrom = const [],
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

  /// Optional art rising behind the splash logo card (the Pongal sun, the Christmas star).
  final String? halo;

  /// The greeting changing through the season: (month, day it starts, text) in date order. Dates
  /// before the first rule take the last one (a season that crosses New Year).
  final List<(int, int, String)> greetingsFrom;

  /// "Merry Christmas" until 25 Dec, "Happy New Year" after; [greeting] for single-day festivals.
  String greetingOn(DateTime day) {
    if (greetingsFrom.isEmpty) return greeting;
    final today = day.month * 100 + day.day;
    String? pick;
    for (final (month, from, text) in greetingsFrom) {
      if (month * 100 + from <= today) pick = text;
    }
    return pick ?? greetingsFrom.last.$3;
  }

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

  /// Christmas & New Year: starry night, New Year fireworks, a pine garland and a decorated tree.
  static const christmas = FestivalPack(
    id: 'christmas',
    dir: 'assets/themes/christmas',
    greeting: 'Merry Christmas',
    greetingsFrom: [(7, 1, 'Merry Christmas'), (12, 26, 'Happy New Year')],
    question: 'Treats for the season, delivered',
    heroAspect: 480 / 300,
    flames: [(0.1667, 0.62, 0.0833), (0.2708, 0.6933, 0.0708)],
    halo: 'star',
    banners: [
      FestivalBanner(
        image: 'assets/themes/christmas/banner_treats.webp',
        tag: 'CHRISTMAS TREATS',
        title: 'Cakes, cookies\n& sweets',
        subtitle: 'For the season of sharing',
        cta: 'Shop treats',
        route: '/search?q=cookies',
      ),
      FestivalBanner(
        image: 'assets/themes/christmas/banner_party.webp',
        tag: 'NEW YEAR PARTY',
        title: 'Snacks &\ncold drinks',
        subtitle: 'Chips, juices & more',
        cta: 'Party time',
        route: '/search?q=chips',
        dark: true,
      ),
      FestivalBanner(
        image: 'assets/themes/christmas/banner_baking.webp',
        tag: 'BAKE AT HOME',
        title: 'Baking\nessentials',
        subtitle: 'Maida, butter, sugar & eggs',
        cta: 'Shop now',
        route: '/search?q=maida',
      ),
    ],
  );

  /// Valentine's Day: roses, hearts and lace on a deep rose night, chocolates by candlelight.
  static const valentine = FestivalPack(
    id: 'valentine',
    dir: 'assets/themes/valentine',
    greeting: 'Happy Valentine’s Day',
    question: 'Treats for your loved ones',
    heroAspect: 480 / 300,
    flames: [(0.1, 0.6533, 0.0708), (0.9167, 0.7, 0.0667)],
    halo: 'heart',
    banners: [
      FestivalBanner(
        image: 'assets/themes/valentine/banner_chocolates.webp',
        tag: 'SAY IT SWEETLY',
        title: 'Chocolates\n& treats',
        subtitle: 'For someone special',
        cta: 'Shop treats',
        route: '/search?q=chocolate',
      ),
      FestivalBanner(
        image: 'assets/themes/valentine/banner_flowers.webp',
        tag: 'VALENTINE’S DAY',
        title: 'Flowers\n& gifts',
        subtitle: 'Little things that say a lot',
        cta: 'Explore',
        route: '/categories',
        dark: true,
      ),
      FestivalBanner(
        image: 'assets/themes/valentine/banner_sweets.webp',
        tag: 'SWEETHEART SPECIAL',
        title: 'Sweets for\nyour sweetheart',
        subtitle: 'Cakes, sweets & more',
        cta: 'Shop sweets',
        route: '/search?q=sweets',
      ),
    ],
  );

  /// Tamil New Year (Puthandu): peacock-teal silk, a mango-leaf thoranam with konrai bunches, the
  /// kuthuvilakku beside the kani tray, a lotus rising behind the splash logo.
  static const puthandu = FestivalPack(
    id: 'puthandu',
    dir: 'assets/themes/puthandu',
    greeting: 'Happy Tamil New Year',
    question: 'Puthandu essentials, delivered',
    heroAspect: 480 / 300,
    flames: [
      (0.0313, 0.4133, 0.1143),
      (0.1002, 0.4369, 0.1143),
      (0.3165, 0.4369, 0.1143),
      (0.3853, 0.4133, 0.1143),
      (0.2083, 0.4487, 0.1143),
    ],
    halo: 'lotus',
    banners: [
      FestivalBanner(
        image: 'assets/themes/puthandu/banner_fruits.webp',
        tag: 'PUTHANDU SPECIAL',
        title: 'Mangoes &\nmukkani',
        subtitle: 'Mango, jackfruit & banana',
        cta: 'Shop fruits',
        route: '/search?q=mango',
      ),
      FestivalBanner(
        image: 'assets/themes/puthandu/banner_feast.webp',
        tag: 'NEW YEAR FEAST',
        title: 'Feast\nessentials',
        subtitle: 'For payasam, vadai & sambar',
        cta: 'Shop now',
        route: '/search?q=dal',
        dark: true,
      ),
      FestivalBanner(
        image: 'assets/themes/puthandu/banner_pooja.webp',
        tag: 'KANI & POOJA',
        title: 'Pooja &\nkani needs',
        subtitle: 'Camphor, agarbatti & more',
        cta: 'Explore',
        route: '/search?q=agarbatti',
      ),
    ],
  );

  /// Eid (Ramzan & Bakrid): a violet night with gold star patterns, lanterns, a crescent, dates and the feast.
  static const eid = FestivalPack(
    id: 'eid',
    dir: 'assets/themes/eid',
    greeting: 'Eid Mubarak',
    question: 'Feast essentials, delivered',
    heroAspect: 480 / 300,
    flames: [(0.3667, 0.6499, 0.1754), (0.875, 0.7585, 0.1127)],
    halo: 'crescent',
    banners: [
      FestivalBanner(
        image: 'assets/themes/eid/banner_sweets.webp',
        tag: 'EID SPECIAL',
        title: 'Sheer khurma\n& sweets',
        subtitle: 'Semiya, dates & dry fruits',
        cta: 'Shop sweets',
        route: '/search?q=sweets',
      ),
      FestivalBanner(
        image: 'assets/themes/eid/banner_biryani.webp',
        tag: 'EID FEAST',
        title: 'Biryani\nessentials',
        subtitle: 'Basmati, spices & ghee',
        cta: 'Shop now',
        route: '/search?q=rice',
        dark: true,
      ),
      FestivalBanner(
        image: 'assets/themes/eid/banner_iftar.webp',
        tag: 'IFTAR TREATS',
        title: 'Dates, fruits\n& drinks',
        subtitle: 'For Ramzan evenings',
        cta: 'Explore',
        route: '/categories',
      ),
    ],
  );

  /// Independence & Republic Day: tricolour bunting, balloons, a kite and tiranga sweets under fireworks; the greeting follows the date.
  static const national = FestivalPack(
    id: 'national',
    dir: 'assets/themes/national',
    greeting: 'Happy Independence Day',
    greetingsFrom: [(1, 1, 'Happy Republic Day'), (6, 1, 'Happy Independence Day')],
    question: 'Holiday treats, delivered',
    heroAspect: 480 / 300,
    flames: [],
    halo: 'sunburst',
    banners: [
      FestivalBanner(
        image: 'assets/themes/national/banner_sweets.webp',
        tag: 'TIRANGA SPECIAL',
        title: 'Tricolour\nsweets',
        subtitle: 'Barfi, laddu & more',
        cta: 'Shop sweets',
        route: '/search?q=sweets',
      ),
      FestivalBanner(
        image: 'assets/themes/national/banner_snacks.webp',
        tag: 'HOLIDAY SNACKS',
        title: 'Snacks &\ncold drinks',
        subtitle: 'For the long weekend',
        cta: 'Shop now',
        route: '/search?q=chips',
        dark: true,
      ),
      FestivalBanner(
        image: 'assets/themes/national/banner_desi.webp',
        tag: 'PROUDLY INDIAN',
        title: 'Desi brands,\ndelivered',
        subtitle: 'Made-in-India favourites',
        cta: 'Explore',
        route: '/categories',
      ),
    ],
  );

  static FestivalPack? byId(String? id) => switch (id) {
    'diwali' => diwali,
    'pongal' => pongal,
    'christmas' => christmas,
    'valentine' => valentine,
    'puthandu' => puthandu,
    'eid' => eid,
    'national' => national,
    _ => null,
  };
}

/// The festival art in effect, set together with `AppColors.palette` (null on everyday days).
abstract final class Festive {
  static FestivalPack? pack;
}
