import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/festival_pack.dart';
import '../core/theme.dart';

bool _still(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Mango-leaf and marigold thoranam draped across the top of a header: spans the width on
/// phones (tied at both edges), repeats on tablets.
class Thoranam extends StatelessWidget {
  const Thoranam({super.key, required this.pack, this.height = 44});
  final FestivalPack pack;
  final double height;

  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width < 520;
    return IgnorePointer(
      child: phone
          ? Image.asset(pack.thoranam, height: height, width: double.infinity, fit: BoxFit.fill)
          : Image.asset(pack.thoranam, height: height, fit: BoxFit.fitHeight, repeat: ImageRepeat.repeatX, alignment: Alignment.topLeft),
    );
  }
}

/// Three agal vilakku on a rangoli; the flames flicker.
class DiyaCluster extends StatefulWidget {
  const DiyaCluster({super.key, required this.pack, this.width = 132});
  final FestivalPack pack;
  final double width;

  @override
  State<DiyaCluster> createState() => _DiyaClusterState();
}

class _DiyaClusterState extends State<DiyaCluster> with SingleTickerProviderStateMixin {
  late final _flicker = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _flicker.stop();
    } else if (!_flicker.isAnimating) {
      _flicker.repeat();
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * 270 / 480;
    return IgnorePointer(
      child: RepaintBoundary(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: Image.asset(widget.pack.diyas, fit: BoxFit.fill)),
              for (final (i, (x, y, size)) in widget.pack.wicks.indexed) _flame(i, left: x * w, wickY: y * h, width: size * w * 0.52),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flame(int i, {required double left, required double wickY, required double width}) {
    final height = width * 1.6;
    final phase = i * 1.9;
    return Positioned(
      left: left - width / 2,
      top: wickY - height * 0.9,
      width: width,
      height: height,
      child: AnimatedBuilder(
        animation: _flicker,
        builder: (context, child) {
          final t = _flicker.value * math.pi * 2;
          final sy = 1 + 0.07 * math.sin(t * 3 + phase) + 0.035 * math.sin(t * 7 + phase * 2);
          final sx = 1 - 0.045 * math.sin(t * 3 + phase);
          final tilt = 0.05 * math.sin(t * 2 + phase);
          return Transform(alignment: const Alignment(0, 0.8), transform: Matrix4.rotationZ(tilt)..scaleByDouble(sx, sy, 1, 1), child: child);
        },
        child: Image.asset(widget.pack.flame, fit: BoxFit.fill),
      ),
    );
  }
}

/// Gold sparkles that twinkle in and out across a festive header.
class Twinkles extends StatefulWidget {
  const Twinkles({super.key});

  @override
  State<Twinkles> createState() => _TwinklesState();
}

class _TwinklesState extends State<Twinkles> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(painter: _TwinklePainter(_clock), size: Size.infinite),
    ),
  );
}

class _TwinklePainter extends CustomPainter {
  _TwinklePainter(this.clock) : super(repaint: clock);
  final Animation<double> clock;

  /// (x, y) as fractions of the header, size in dp, phase — kept clear of the text on the left.
  static const _stars = [
    (0.60, 0.30, 5.0, 0.00),
    (0.76, 0.21, 6.5, 0.37),
    (0.93, 0.33, 5.5, 0.71),
    (0.68, 0.47, 4.5, 0.18),
    (0.87, 0.52, 6.0, 0.55),
    (0.54, 0.19, 4.0, 0.83),
    (0.97, 0.17, 4.5, 0.28),
    (0.81, 0.40, 3.5, 0.92),
    (0.40, 0.17, 3.5, 0.62),
    (0.72, 0.63, 4.0, 0.44),
    (0.12, 0.31, 3.0, 0.08),
    (0.95, 0.62, 3.5, 0.66),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final star = Paint();
    for (final (fx, fy, r, phase) in _stars) {
      final wave = math.sin((clock.value + phase) * math.pi * 2);
      final a = math.pow(math.max(0, wave), 3).toDouble();
      if (a < 0.02) continue;
      final c = Offset(fx * size.width, fy * size.height);
      final radius = r * (0.55 + 0.45 * a);
      canvas.drawCircle(c, radius * 1.2, glow..color = const Color(0xFFFFD54F).withValues(alpha: 0.45 * a));
      canvas.drawPath(_star(c, radius), star..color = const Color(0xFFFFF6D5).withValues(alpha: a));
    }
  }

  Path _star(Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.24;
      final pt = c + Offset(math.cos(angle) * rr, math.sin(angle) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter oldDelegate) => false;
}

/// Lays the petal shower over [child] while a festival with art is on (the Stack stays put,
/// so switching the festival on or off keeps the child's state).
class PetalOverlay extends StatelessWidget {
  const PetalOverlay({super.key, required this.pack, required this.child});
  final FestivalPack? pack;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(children: [
        child,
        if (pack case final pack?) Positioned.fill(child: PetalShower(pack: pack)),
      ]);
}

/// Marigold petals drift down over Home once per visit when a festival starts showing.
class PetalShower extends StatefulWidget {
  const PetalShower({super.key, required this.pack});
  final FestivalPack pack;

  @override
  State<PetalShower> createState() => _PetalShowerState();
}

class _PetalShowerState extends State<PetalShower> with SingleTickerProviderStateMixin {
  static final _played = <String>{};
  late final _fall = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  late final List<_Petal> _petals;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(widget.pack.id.hashCode);
    _petals = List.generate(38, (i) => _Petal(rnd, i % widget.pack.petals.length));
    _fall.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _done = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done || _fall.isAnimating) return;
    if (_still(context) || _played.contains(widget.pack.id)) {
      _done = true;
      return;
    }
    _played.add(widget.pack.id);
    _fall.forward();
  }

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _fall,
          builder: (context, _) => Stack(
            children: [
              for (final p in _petals)
                if (p.at(_fall.value, box.biggest) case final pos?)
                  Positioned(
                    left: pos.$1,
                    top: pos.$2,
                    child: Transform.rotate(
                      angle: pos.$3,
                      child: Image.asset(widget.pack.petals[p.sprite], width: p.size, height: p.size, opacity: AlwaysStoppedAnimation(pos.$4)),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Petal {
  _Petal(math.Random rnd, this.sprite)
    : x = rnd.nextDouble(),
      delay = rnd.nextDouble() * 0.35,
      speed = 0.75 + rnd.nextDouble() * 0.5,
      sway = 10 + rnd.nextDouble() * 22,
      swayFreq = 1 + rnd.nextDouble() * 1.6,
      spin = (rnd.nextDouble() - 0.5) * 9,
      phase = rnd.nextDouble() * math.pi * 2,
      size = (sprite == 3 ? 26 : 16) + rnd.nextDouble() * 9;

  final int sprite;
  final double x, delay, speed, sway, swayFreq, spin, phase, size;

  /// (left, top, angle, opacity) at progress [t] of the shower, or null when off-screen.
  (double, double, double, double)? at(double t, Size area) {
    final local = (t - delay) / (1 - delay);
    if (local <= 0 || local >= 1) return null;
    final fall = local * speed * (area.height * 0.9 + 80) - 40;
    if (fall > area.height) return null;
    final left = x * area.width + math.sin(local * swayFreq * math.pi * 2 + phase) * sway;
    final fade = local < 0.08 ? local / 0.08 : (local > 0.8 ? (1 - local) / 0.2 : 1.0);
    return (left, fall, phase + local * spin, fade.clamp(0.0, 1.0));
  }
}

/// Festival banner: illustrated art on the right, live text on the left (stays crisp and editable).
class FestiveBannerCard extends StatelessWidget {
  const FestiveBannerCard(this.banner, {super.key});
  final FestivalBanner banner;

  static const _gold = Color(0xFFF6C445);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dark = banner.dark;
    final radius = BorderRadius.circular(AppRadius.xl);
    void open() => banner.route.startsWith('/search') ? context.push(banner.route) : context.go(banner.route);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: dark ? AppColors.brand900 : AppColors.brandTint,
          image: DecorationImage(image: AssetImage(banner.image), fit: BoxFit.cover, alignment: Alignment.centerRight),
        ),
        child: InkWell(
          onTap: open,
          borderRadius: radius,
          child: Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: (dark ? _gold : const Color(0xFFD9962B)).withValues(alpha: 0.55), width: 1.2),
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
            // Marketing art has a fixed height: cap text growth so large accessibility sizes still fit.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.1,
              // The card hands down a tight width; FractionallySizedBox keeps the text on the left 54%.
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: dark ? _gold : AppColors.brand700, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        banner.tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(color: dark ? AppColors.brand900 : Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      banner.title,
                      maxLines: 2,
                      style: text.titleLarge?.copyWith(height: 1.1, color: dark ? Colors.white : AppColors.brand900, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      banner.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: dark ? Colors.white.withValues(alpha: 0.85) : AppColors.ink),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: dark
                          ? BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFFFE08A), _gold, Color(0xFFE0A82E)]),
                              borderRadius: BorderRadius.circular(20),
                            )
                          : AppDecor.brandFill(radius: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              banner.cta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelLarge?.copyWith(color: dark ? AppColors.brand900 : Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 16, color: dark ? AppColors.brand900 : Colors.white),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
