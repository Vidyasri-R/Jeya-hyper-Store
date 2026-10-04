import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'brand_intro_parts.dart';

/// The store's logo arriving on the splash: the J opens out in a flash of warm light with a ring
/// round it, the peacock's feathers fan up from behind it into the crown (the crest feather rising
/// last), a shine runs across the mark and the wordmark rises in.
///
/// Built from the logo's own pieces (assets/brand/intro/, cut by design/brand-intro/split_logo.py),
/// so the last frame is exactly logo_full.png. Turned off with the system's reduce-motion setting.
class BrandIntro extends StatefulWidget {
  const BrandIntro({super.key, required this.width, this.onDone});

  final double width;

  /// Called once the logo is complete (straight away when animations are off).
  final VoidCallback? onDone;

  static const duration = Duration(milliseconds: 1900);

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
    // Decode every piece first so nothing pops in.
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
    return SizedBox.fromSize(
      size: BrandIntroParts.size * k,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) => _frame(_clock.value * BrandIntro.duration.inMilliseconds, k),
      ),
    );
  }

  Widget _frame(double ms, double k) {
    final pivot = BrandIntroParts.pivot * k; // where the feathers fan from (behind the J)

    // The J opens out in a flash of light, its feathers hanging closed behind it.
    final appear = Curves.easeOut.transform(_span(ms, 0, 160));
    final opening = Curves.easeOutCubic.transform(_span(ms, 40, 260));
    final flash = math.sin(math.pi * _span(ms, 0, 420));

    final layers = <Widget>[];
    for (final (i, piece) in BrandIntroParts.feathers.indexed) {
      if (i == 4) continue; // the crest feather rises on its own, below
      // Closed: every feather points down from the pivot, close together and layered, the longest in
      // the middle; then they fan up to their places in the logo, centre ones a beat later.
      final closedAngle = 180 + (i - 4) * 3.5;
      final closedReach = 100.0 + 30 * (4 - (i - 4).abs());
      final turn = piece.angle <= 0 ? closedAngle - (piece.angle + 360) : closedAngle - piece.angle;
      final lag = (4 - (i - 4).abs()) * 35.0;
      final open = Curves.easeOutBack.transform(_span(ms, 220 + lag, 860 + lag));
      final sway = 4 * (1 - open) * math.sin(ms / 1000 * math.pi * 2 * 1.7 + i * 0.6);
      final along = (closedReach - piece.reach) * (1 - open);
      final dir = Offset(math.sin(piece.angle * math.pi / 180), -math.cos(piece.angle * math.pi / 180));
      layers.add(_piece(
        piece,
        k,
        transform: _about(pivot, rotate: turn * (1 - open) + sway, scale: 0.82 + 0.18 * open, before: dir * along * k),
        opacity: appear,
      ));
    }
    final rise = Curves.easeOutBack.transform(_span(ms, 520, 1080));
    layers.add(_piece(BrandIntroParts.feathers[4], k, transform: _about(pivot, scale: 0.25 + 0.75 * rise), opacity: (rise * 2).clamp(0.0, 1.0)));
    layers.add(Positioned.fill(
      child: Opacity(
        opacity: appear,
        child: Transform(
          transform: Matrix4.translationValues(pivot.dx, 0, 0)
            ..multiply(Matrix4.diagonal3Values(0.08 + 0.92 * opening, 1, 1))
            ..multiply(Matrix4.translationValues(-pivot.dx, 0, 0)),
          child: _lit(
            flash,
            Stack(
              clipBehavior: Clip.none,
              children: [_piece(BrandIntroParts.wingLeft, k), _piece(BrandIntroParts.wingRight, k), _piece(BrandIntroParts.body, k), _piece(BrandIntroParts.head, k)],
            ),
          ),
        ),
      ),
    ));

    Widget mark = Stack(clipBehavior: Clip.none, children: layers);
    final shine = _span(ms, 880, 1430);
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

    final word = Curves.easeOutCubic.transform(_span(ms, 980, 1530));
    final store = Curves.easeOutCubic.transform(_span(ms, 1230, 1780));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _Glow(ms: ms, centre: pivot))),
        Positioned.fill(child: mark),
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

  /// Washes [child] towards warm white by [flash] (0–1).
  static Widget _lit(double flash, Widget child) => flash > 0.01
      ? ColorFiltered(colorFilter: ColorFilter.mode(const Color(0xFFFFF3C4).withValues(alpha: 0.75 * flash), BlendMode.srcATop), child: child)
      : child;

  static Widget _image(BrandPiece piece) => Image.asset(piece.asset, fit: BoxFit.fill, filterQuality: FilterQuality.medium, gaplessPlayback: true);

  static Widget _place(BrandPiece piece, double k, Widget child) {
    final r = piece.rect;
    return Positioned(left: r.left * k, top: r.top * k, width: r.width * k, height: r.height * k, child: child);
  }

  /// A piece in its place in the logo, moved by [transform] (in the logo's coordinates).
  static Widget _piece(BrandPiece piece, double k, {Matrix4? transform, double opacity = 1}) {
    final image = _image(piece);
    if (transform == null && opacity >= 1) return _place(piece, k, image);
    // Transform a logo-sized layer so the pivot stays in the logo's coordinates.
    Widget layer = Stack(clipBehavior: Clip.none, children: [_place(piece, k, image)]);
    if (transform != null) layer = Transform(transform: transform, child: layer);
    if (opacity < 1) layer = Opacity(opacity: opacity, child: layer);
    return Positioned.fill(child: layer);
  }

  /// Turn/scale about [centre], after moving the piece by [before].
  static Matrix4 _about(Offset centre, {double rotate = 0, double scale = 1, Offset before = Offset.zero}) =>
      Matrix4.translationValues(centre.dx, centre.dy, 0)
        ..multiply(Matrix4.rotationZ(rotate * math.pi / 180))
        ..multiply(Matrix4.diagonal3Values(scale, scale, 1))
        ..multiply(Matrix4.translationValues(before.dx - centre.dx, before.dy - centre.dy, 0));
}

/// 0 → 1 as [ms] runs from [from] to [to].
double _span(double ms, double from, double to) => ((ms - from) / (to - from)).clamp(0.0, 1.0);

/// A soft glow and a ring of light spreading from behind the J as it opens.
class _Glow extends CustomPainter {
  _Glow({required this.ms, required this.centre});

  final double ms;
  final Offset centre;

  @override
  void paint(Canvas canvas, Size size) {
    final t = _span(ms, 60, 640);
    if (t <= 0 || t >= 1) return;
    final e = Curves.easeOutCubic.transform(t);
    canvas.drawCircle(
      centre,
      size.width * 0.32,
      Paint()
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.26 * (1 - e))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );
    canvas.drawCircle(
      centre,
      24 + size.width * 0.6 * e,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * (1 - e)
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.7 * (1 - e)),
    );
  }

  @override
  bool shouldRepaint(_Glow old) => old.ms != ms;
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
