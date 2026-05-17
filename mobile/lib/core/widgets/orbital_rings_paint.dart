import "dart:math" as math;

import "package:flutter/material.dart";

/// Concentric orbital arcs (Analyze / Edit loading heroes).
void paintLinkClipOrbitalRings({
  required Canvas canvas,
  required Offset center,
  required double shortestSide,
  required double t,
  required Color primary,
  required Color secondary,
  int ringCount = 4,
  double baseRadiusFraction = 0.18,
  double radiusStepFraction = 0.078,
}) {
  for (var i = 0; i < ringCount; i++) {
    final dir = i.isEven ? 1.0 : -1.0;
    final rot = t * 2 * math.pi * (0.12 + i * 0.07) * dir;
    final r = shortestSide * (baseRadiusFraction + i * radiusStepFraction);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rot);
    final arcPaint = Paint()
      ..color = primary.withValues(alpha: 0.26 - i * 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 + i.toDouble() * 0.35
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r),
      -math.pi * 0.38,
      math.pi * 1.62,
      false,
      arcPaint,
    );
    if (i == 1 || i == 3) {
      final dashPaint = Paint()
        ..color = secondary.withValues(alpha: 0.28 + 0.06 * (i % 2))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r * 0.93),
        math.pi * 0.15 + i * 0.4,
        math.pi * 1.05,
        false,
        dashPaint,
      );
    }
    canvas.restore();
  }
}
