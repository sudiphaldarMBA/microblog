import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bold scalloped verified badge: pink fill with a thick rounded tick.
/// The tick is black in light mode and white in dark mode.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});

  static const Color pink = Color(0xFFF91880);

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return CustomPaint(
      size: Size.square(size),
      painter: _BadgePainter(
        fill: pink,
        tick: dark ? Colors.white : Colors.black,
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({required this.fill, required this.tick});

  final Color fill;
  final Color tick;

  static const int _points = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);

    // Scalloped outline: radius wobbles between ~0.86R and R.
    final outer = s / 2;
    final path = Path();

    const steps = 360;

    for (var i = 0; i <= steps; i++) {
      final angle = (i / steps) * math.pi * 2;
      final wave = (math.cos(angle * _points) + 1) / 2; // 0..1
      final radius = outer * (0.86 + 0.14 * wave);

      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();

    canvas.drawPath(path, Paint()..color = fill..isAntiAlias = true);

    // Thick rounded tick.
    final tickPath = Path()
      ..moveTo(s * .29, s * .52)
      ..lineTo(s * .44, s * .67)
      ..lineTo(s * .71, s * .35);

    canvas.drawPath(
      tickPath,
      Paint()
        ..color = tick
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * .13
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.fill != fill || old.tick != tick;
}