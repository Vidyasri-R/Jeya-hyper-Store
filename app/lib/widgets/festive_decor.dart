import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A string of warm lights hanging across the top of the Diwali header (painted — no assets).
class DiwaliLights extends StatelessWidget {
  const DiwaliLights({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(child: CustomPaint(painter: _LightsPainter(), size: Size.infinite));
}

class _LightsPainter extends CustomPainter {
  const _LightsPainter();

  static const _bulbs = [Color(0xFFFFD54F), Color(0xFFFF8A65), Color(0xFFFFF59D), Color(0xFFFFB74D)];

  @override
  void paint(Canvas canvas, Size size) {
    final wire = Path()
      ..moveTo(-12, 4)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.9, size.width + 12, 4);
    canvas.drawPath(
      wire,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final metric = wire.computeMetrics().first;
    var i = 0;
    for (var d = 16.0; d < metric.length - 8; d += 26, i++) {
      final at = metric.getTangentForOffset(d)!.position.translate(0, 6);
      final colour = _bulbs[i % _bulbs.length];
      canvas.drawCircle(at, 8, Paint()
        ..color = colour.withValues(alpha: 0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawLine(at.translate(0, -6), at.translate(0, -3), Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.4);
      canvas.drawOval(Rect.fromCenter(center: at, width: 6.4, height: 8), Paint()..color = colour);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A lit clay lamp (diya).
class Diya extends StatelessWidget {
  const Diya({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(child: CustomPaint(size: Size(size, size), painter: const _DiyaPainter()));
}

class _DiyaPainter extends CustomPainter {
  const _DiyaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // flame glow, then the flame (teardrop)
    final flameCentre = Offset(w * 0.5, h * 0.36);
    canvas.drawCircle(flameCentre, w * 0.32, Paint()
      ..color = const Color(0xFFFFC53D).withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.18));
    final flame = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..cubicTo(w * 0.62, h * 0.24, w * 0.64, h * 0.42, w * 0.5, h * 0.52)
      ..cubicTo(w * 0.36, h * 0.42, w * 0.38, h * 0.24, w * 0.5, h * 0.08)
      ..close();
    canvas.drawPath(flame, Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFFFF8E1), Color(0xFFFFC107), Color(0xFFFF6F00)], stops: [0.0, 0.55, 1.0])
          .createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.38), radius: w * 0.2)));

    // clay bowl
    final bowl = Path()
      ..moveTo(w * 0.06, h * 0.56)
      ..quadraticBezierTo(w * 0.5, h * 1.02, w * 0.94, h * 0.56)
      ..quadraticBezierTo(w * 0.5, h * 0.7, w * 0.06, h * 0.56)
      ..close();
    canvas.drawPath(bowl, Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFB74D), Color(0xFFD84315), Color(0xFF8D1B12)])
          .createShader(Rect.fromLTWH(0, h * 0.5, w, h * 0.45)));
    // gold rim + spout dot
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.06, h * 0.56)
        ..quadraticBezierTo(w * 0.5, h * 0.7, w * 0.94, h * 0.56),
      Paint()
        ..color = const Color(0xFFFFE082)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, w * 0.04),
    );
    canvas.drawCircle(Offset(w * 0.5, h * 0.78), w * 0.05, Paint()..color = const Color(0xFFFFE082).withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
