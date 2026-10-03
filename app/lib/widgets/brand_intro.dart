import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand_intro_parts.dart';

/// The store's logo arriving on the splash: the peacock swoops in with a sparkle trail (its nine
/// feathers trailing as a train, wings beating), lands upright as the "J", fans its feathers out
/// into the logo, a shine runs across it and the wordmark rises in.
///
/// Built from the logo's own pieces (assets/brand/intro/, cut by design/brand-intro/split_logo.py),
/// so the last frame is exactly logo_full.png. Turned off with the system's reduce-motion setting.
class BrandIntro extends StatefulWidget {
  const BrandIntro({super.key, required this.width, this.onDone});

  final double width;

  /// Called once the logo is complete (straight away when animations are off).
  final VoidCallback? onDone;

  static const duration = Duration(milliseconds: 2800);

  @override
  State<BrandIntro> createState() => BrandIntroState();
}

class BrandIntroState extends State<BrandIntro> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: BrandIntro.duration)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
  bool _started = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _clock.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
      return;
    }
    // Decode every piece first so nothing pops in mid-flight.
    Future.wait([for (final piece in BrandIntroParts.all) precacheImage(AssetImage(piece.asset), context)]).whenComplete(() {
      if (mounted && !_done) _clock.forward();
    });
  }

  /// Jump to the finished logo (the splash was tapped).
  void skip() {
    _clock.value = 1;
    _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone?.call();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.width / BrandIntroParts.size.width;
    final swoop = _Swoop(MediaQuery.sizeOf(context), widget.width);
    return SizedBox.fromSize(
      size: BrandIntroParts.size * k,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => _frame(_clock.value * BrandIntro.duration.inMilliseconds, k, swoop),
      ),
    );
  }

  Widget _frame(double ms, double k, _Swoop swoop) {
    final pivot = BrandIntroParts.pivot * k; // the bird turns about the point behind the J

    // Flight: fast in, gliding to a stop; nose follows the climb, then pulls up to stand as the J.
    final fly = Curves.easeOutCubic.transform(_span(ms, 0, 1150));
    final at = swoop.at(fly);
    final slope = swoop.slope(fly);
    final land = Curves.easeInOutCubic.transform(_span(ms, 820, 1250));
    final pitch = slope.distance == 0 ? 0.0 : slope.dy / slope.distance * 26;
    final heading = (72 + pitch) * (1 - land);
    final scale = 0.62 + 0.38 * fly + math.sin(math.pi * _span(ms, 1150, 1480)) * 0.05;
    final bird = _about(pivot, rotate: heading, scale: scale, then: at);

    final beat = 30 * (1 - Curves.easeOut.transform(_span(ms, 900, 1250))) * math.sin(ms / 1000 * math.pi * 2 * 3.1);
    final wingSize = 1 + 0.4 * (1 - land);
    final ripple = 1 - land;

    final feathers = <Widget>[];
    for (final (i, piece) in BrandIntroParts.feathers.indexed) {
      if (i == 4) continue; // the crest feather rises on its own, below
      // Train: every feather points back (down from the pivot), a little spread; fans out to its place.
      final trainAngle = 180 + (i - 4) * 5.0;
      final turn = piece.angle <= 0 ? trainAngle - (piece.angle + 360) : trainAngle - piece.angle;
      final lag = (4 - (i - 4).abs()) * 35.0;
      final open = Curves.easeOutBack.transform(_span(ms, 1180 + lag, 1820 + lag));
      final wave = 5 * ripple * math.sin(ms / 1000 * math.pi * 2 * 1.7 + i * 0.6);
      final out = 70 * (1 - open);
      final dir = Offset(math.sin(piece.angle * math.pi / 180), -math.cos(piece.angle * math.pi / 180));
      feathers.add(_piece(piece, k, _about(pivot, rotate: turn * (1 - open) + wave, scale: 0.82 + 0.18 * open, before: dir * out * k)));
    }
    final rise = Curves.easeOutBack.transform(_span(ms, 1480, 2050));
    final crest = BrandIntroParts.feathers[4];
    feathers.add(_piece(crest, k, _about(pivot, scale: 0.25 + 0.75 * rise), (rise * 2).clamp(0.0, 1.0)));

    final wings = [
      _piece(BrandIntroParts.wingLeft, k, _about(BrandIntroParts.wingLeft.hinge * k, rotate: beat, scale: wingSize)),
      _piece(BrandIntroParts.wingRight, k, _about(BrandIntroParts.wingRight.hinge * k, rotate: -beat, scale: wingSize)),
    ];

    Widget mark = Stack(
      clipBehavior: Clip.none,
      children: [...feathers, ...wings, _piece(BrandIntroParts.body, k), _piece(BrandIntroParts.head, k)],
    );
    final shine = _span(ms, 1850, 2400);
    if (shine > 0 && shine < 1) {
      final s = shine * 1.6 - 0.3;
      mark = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0x00FFFFFF), Color(0xAAFFFFFF), Color(0x00FFFFFF)],
          stops: [(s - 0.14).clamp(0.0, 1.0), s.clamp(0.0, 1.0), (s + 0.14).clamp(0.0, 1.0)],
        ).createShader(rect),
        child: mark,
      );
    }

    final word = Curves.easeOutCubic.transform(_span(ms, 1950, 2500));
    final store = Curves.easeOutCubic.transform(_span(ms, 2200, 2750));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _Sparkles(ms: ms, swoop: swoop, pivot: pivot))),
        Positioned.fill(child: Transform(transform: bird, child: mark)),
        if (word > 0)
          _place(
            BrandIntroParts.wordTop,
            k,
            Opacity(opacity: word, child: Transform.translate(offset: Offset(0, 22 * k * (1 - word)), child: _image(BrandIntroParts.wordTop))),
          ),
        if (store > 0)
          _place(
            BrandIntroParts.wordBottom,
            k,
            Opacity(opacity: store, child: ClipRect(clipper: _FromCentre(store), child: _image(BrandIntroParts.wordBottom))),
          ),
      ],
    );
  }

  static Widget _image(BrandPiece piece) => Image.asset(piece.asset, fit: BoxFit.fill, filterQuality: FilterQuality.medium, gaplessPlayback: true);

  static Widget _place(BrandPiece piece, double k, Widget child) {
    final r = piece.rect;
    return Positioned(left: r.left * k, top: r.top * k, width: r.width * k, height: r.height * k, child: child);
  }

  /// A piece in its place in the logo, moved by [transform] (in the logo's coordinates).
  static Widget _piece(BrandPiece piece, double k, [Matrix4? transform, double opacity = 1]) {
    final image = _image(piece);
    if (transform == null) return _place(piece, k, image);
    // Transform a logo-sized layer so pivots and hinges stay in the logo's coordinates.
    Widget layer = Transform(
      transform: transform,
      child: Stack(clipBehavior: Clip.none, children: [_place(piece, k, image)]),
    );
    if (opacity < 1) layer = Opacity(opacity: opacity, child: layer);
    return Positioned.fill(child: layer);
  }

  /// Turn/scale about [centre], after moving the piece by [before]; then move everything by [then].
  static Matrix4 _about(Offset centre, {double rotate = 0, double scale = 1, Offset before = Offset.zero, Offset then = Offset.zero}) =>
      Matrix4.translationValues(then.dx + centre.dx, then.dy + centre.dy, 0)
        ..multiply(Matrix4.rotationZ(rotate * math.pi / 180))
        ..multiply(Matrix4.diagonal3Values(scale, scale, 1))
        ..multiply(Matrix4.translationValues(before.dx - centre.dx, before.dy - centre.dy, 0));
}

/// 0 → 1 as [ms] runs from [from] to [to].
double _span(double ms, double from, double to) => ((ms - from) / (to - from)).clamp(0.0, 1.0);

/// The flight: from off the screen bottom-left, up over the logo's left, curling up into place.
class _Swoop {
  _Swoop(Size screen, double width)
    : p0 = Offset(-screen.width * 0.5 - width * 0.9, screen.height * 0.36),
      p1 = Offset(-screen.width * 0.5, -screen.height * 0.28),
      p2 = Offset(-screen.width * 0.04, screen.height * 0.1);

  final Offset p0, p1, p2;
  static const p3 = Offset.zero;

  Offset at(double t) {
    final u = 1 - t;
    return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t);
  }

  Offset slope(double t) {
    final u = 1 - t;
    return (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t);
  }
}

/// Glittering trail behind the bird in flight, and a soft ring of light where it lands.
class _Sparkles extends CustomPainter {
  _Sparkles({required this.ms, required this.swoop, required this.pivot});

  final double ms;
  final _Swoop swoop;
  final Offset pivot;

  static const _colours = [Color(0xFFFFD54F), Color(0xFF2EA65A), Color(0xFF4F86E8), Color(0xFFFFF3C4)];

  @override
  void paint(Canvas canvas, Size size) {
    if (ms <= 0) return;
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final haze = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final dot = Paint();
    final rnd = math.Random(11);
    final fade = 1 - _span(ms, 1100, 1600);
    Offset? trailAt(double when) => when < 0 || when > 1150 ? null : swoop.at(Curves.easeOutCubic.transform(when / 1150)) + pivot;
    // a soft golden comet tail along the path…
    for (var j = 0; j < 16 && fade > 0; j++) {
      final at = trailAt(ms - 20 - j * 18);
      if (at == null) continue;
      canvas.drawCircle(at, 14 * (1 - j / 16) + 4, haze..color = const Color(0xFFFFD54F).withValues(alpha: 0.28 * (1 - j / 16) * fade));
    }
    // …glittering with gold, green and blue sparks that drift apart as they age
    for (var j = 0; j < 44 && fade > 0; j++) {
      final jitter = Offset(rnd.nextDouble() - 0.5, rnd.nextDouble() - 0.5);
      final at = trailAt(ms - 26 - j * 13);
      if (at == null) continue;
      final age = j / 44;
      final spark = at + jitter * (10 + 52 * age);
      final r = 1.6 + 4.4 * (1 - age);
      final colour = _colours[j % _colours.length];
      canvas.drawCircle(spark, r * 2.2, glow..color = colour.withValues(alpha: 0.7 * (1 - age) * fade));
      canvas.drawCircle(spark, r * 0.75, dot..color = Colors.white.withValues(alpha: (1 - age) * fade));
    }
    final ring = _span(ms, 1150, 1700);
    if (ring > 0 && ring < 1) {
      final e = Curves.easeOutCubic.transform(ring);
      canvas.drawCircle(
        pivot,
        24 + size.width * 0.6 * e,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * (1 - e)
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.7 * (1 - e)),
      );
      canvas.drawCircle(
        pivot,
        size.width * 0.32,
        Paint()
          ..color = const Color(0xFFFFE082).withValues(alpha: 0.22 * (1 - e))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
      );
    }
  }

  @override
  bool shouldRepaint(_Sparkles old) => old.ms != ms;
}

/// Reveals its child outwards from the middle (the wordmark's rules drawing out).
class _FromCentre extends CustomClipper<Rect> {
  _FromCentre(this.t);
  final double t;

  @override
  Rect getClip(Size size) => Rect.fromCenter(center: size.center(Offset.zero), width: size.width * t, height: size.height);

  @override
  bool shouldReclip(_FromCentre old) => old.t != t;
}
