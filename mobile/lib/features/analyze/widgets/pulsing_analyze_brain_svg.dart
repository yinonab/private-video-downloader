import "dart:math" as math;
import "dart:ui" show ImageFilter;

import "package:flutter/material.dart";
import "package:flutter_svg/flutter_svg.dart";

/// Hero brain for Analyze: vector SVG with gentle pulse/scale and layered glow.
/// Orbital rings remain separate ([AnalyzeProcessingAnimation] backdrop).
class PulsingAnalyzeBrainSvg extends StatelessWidget {
  const PulsingAnalyzeBrainSvg({
    super.key,
    required this.t,
    required this.width,
    required this.primary,
    required this.secondary,
  });

  final double t;

  /// Target render width (≈ 60–70% of hero width).
  final double width;
  final Color primary;
  final Color secondary;

  static const String assetPath = "assets/illustrations/brain_side_profile.svg";

  static const double _viewBoxW = 1024;
  static const double _viewBoxH = 732;

  @override
  Widget build(BuildContext context) {
    final pulse = (math.sin(t * math.pi * 2 * 0.5) + 1) / 2;
    final opacity = 0.70 + 0.30 * pulse;
    final scale = 0.98 + 0.05 * pulse;
    final glowStrength = 0.35 + 0.35 * pulse;

    final h = width * (_viewBoxH / _viewBoxW);

    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Wide soft glow — does not replace SVG detail (blur disc, not tinted SVG).
          Transform.scale(
            scale: scale * 1.12,
            child: Opacity(
              opacity: glowStrength * 0.42,
              child: Container(
                width: width * 0.88,
                height: h * 0.92,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(math.min(width, h) * 0.42),
                  boxShadow: [
                    BoxShadow(
                      color: secondary.withValues(alpha: 0.55),
                      blurRadius: 38 + 22 * pulse,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: primary.withValues(alpha: 0.38),
                      blurRadius: 24 + 14 * pulse,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tighter teal halo.
          Transform.scale(
            scale: scale * 1.04,
            child: Opacity(
              opacity: glowStrength * 0.35,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: width * 0.72,
                  height: h * 0.78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: secondary.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: SvgPicture.asset(
                assetPath,
                width: width,
                height: h,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
          Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: CustomPaint(
                size: Size(width, h),
                painter: _BrainNeuralDotsPainter(
                  t: t,
                  primary: primary,
                  secondary: secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sequential teal/purple neural highlights (normalized to SVG viewBox ratio).
class _BrainNeuralDotsPainter extends CustomPainter {
  _BrainNeuralDotsPainter({
    required this.t,
    required this.primary,
    required this.secondary,
  });

  final double t;
  final Color primary;
  final Color secondary;

  static const List<Offset> _norm = [
    Offset(0.18, 0.38),
    Offset(0.28, 0.48),
    Offset(0.42, 0.34),
    Offset(0.58, 0.36),
    Offset(0.38, 0.56),
    Offset(0.52, 0.52),
    Offset(0.72, 0.46),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _norm.length; i++) {
      final center =
          Offset(_norm[i].dx * size.width, _norm[i].dy * size.height);
      final stagger = i * 1.13;
      final blink =
          math.pow(math.sin(t * math.pi * 2 * 1.75 + stagger), 2).toDouble();
      final core = Color.lerp(primary, secondary, 0.45 + 0.35 * blink)!;

      canvas.drawCircle(
        center,
        5 + blink * 3,
        Paint()
          ..color = secondary.withValues(alpha: 0.18 + 0.42 * blink)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        center,
        2.8,
        Paint()..color = core.withValues(alpha: 0.82 + 0.15 * blink),
      );
      canvas.drawCircle(
        center,
        1.35,
        Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.5 * blink),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BrainNeuralDotsPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}
