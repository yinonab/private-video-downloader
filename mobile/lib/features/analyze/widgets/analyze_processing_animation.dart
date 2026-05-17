import "dart:math" as math;

import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/theme/linkclip_palette.dart";
import "../../../core/widgets/orbital_rings_paint.dart";
import "pulsing_analyze_brain_svg.dart";

/// Premium animated hero for the Analyze screen loading state.
class AnalyzeProcessingAnimation extends StatefulWidget {
  const AnalyzeProcessingAnimation({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<AnalyzeProcessingAnimation> createState() =>
      _AnalyzeProcessingAnimationState();
}

class _AnalyzeProcessingAnimationState extends State<AnalyzeProcessingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.lcPalette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final maxH = constraints.maxHeight;
        final heroH = maxH.isFinite
            ? (maxH * 0.52).clamp(320.0, 560.0)
            : math.min(480.0, maxW * 1.08).clamp(380.0, 560.0);

        return Align(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.min(maxW, 520)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: heroH,
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, _) {
                        final heroBand = math.min(maxW, 520);
                        final brainW = heroBand * 0.67;
                        return Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size(maxW, heroH),
                              painter: _AnalyzeHeroBackdropPainter(
                                t: _ctrl.value,
                                primary: scheme.primary,
                                secondary: scheme.secondary,
                                glowFill: palette.loaderBubble.withValues(
                                    alpha: theme.brightness == Brightness.dark
                                        ? 0.48
                                        : 0.78),
                              ),
                            ),
                            Align(
                              alignment: const Alignment(0, -0.06),
                              child: PulsingAnalyzeBrainSvg(
                                t: _ctrl.value,
                                width: brainW,
                                primary: scheme.primary,
                                secondary: scheme.secondary,
                              ),
                            ),
                            ..._floatingCards(context, heroH, maxW),
                            Positioned(
                              bottom: heroH * 0.06,
                              child: _PulseArrow(
                                  t: _ctrl.value, color: scheme.primary),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    width: 52,
                    child: AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, _) {
                        return CustomPaint(
                          painter: _DecorativeIndeterminateRingPainter(
                            t: _ctrl.value,
                            primary: scheme.primary,
                            track: scheme.outline.withValues(
                                alpha: theme.brightness == Brightness.dark
                                    ? 0.48
                                    : 0.34),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _floatingCards(BuildContext context, double heroH, double maxW) {
    final scheme = Theme.of(context).colorScheme;
    final specs = <({double xFrac, double yFrac, double phase, double w})>[
      (xFrac: 0.08, yFrac: 0.14, phase: 0.0, w: 52),
      (xFrac: 0.72, yFrac: 0.10, phase: 1.1, w: 48),
      (xFrac: 0.18, yFrac: 0.42, phase: 2.0, w: 46),
      (xFrac: 0.78, yFrac: 0.38, phase: 2.7, w: 50),
      (xFrac: 0.48, yFrac: 0.06, phase: 3.4, w: 44),
    ];

    return specs.map((s) {
      final dx = maxW * s.xFrac - s.w / 2;
      final dy = heroH * s.yFrac;
      return Positioned(
        left: dx,
        top: dy,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final bob =
                math.sin((_ctrl.value * 2 * math.pi * 1.3) + s.phase) * 5;
            final fade = 0.78 +
                0.18 *
                    math.sin((_ctrl.value * 2 * math.pi * 0.9) + s.phase * 0.7);
            return Transform.translate(
              offset: Offset(0, bob),
              child: Opacity(
                opacity: fade.clamp(0.62, 1.0),
                child: _MiniVideoCard(
                  width: s.w,
                  accent: scheme.primary,
                  surface: scheme.surface,
                  outline: scheme.outline.withValues(alpha: 0.52),
                  playBadgeFill: scheme.surfaceContainerHighest,
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}

class _PulseArrow extends StatelessWidget {
  const _PulseArrow({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.88 + 0.12 * math.sin(t * 2 * math.pi * 2);
    final dy = math.sin(t * 2 * math.pi * 1.5) * 4;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Icon(
        LucideIcons.arrowDown,
        size: 34 * pulse,
        color: color.withValues(alpha: 0.96),
        shadows: [
          Shadow(color: color.withValues(alpha: 0.52), blurRadius: 16),
          Shadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 26,
              offset: const Offset(0, 5)),
        ],
      ),
    );
  }
}

class _MiniVideoCard extends StatelessWidget {
  const _MiniVideoCard({
    required this.width,
    required this.accent,
    required this.surface,
    required this.outline,
    required this.playBadgeFill,
  });

  final double width;
  final Color accent;
  final Color surface;
  final Color outline;
  final Color playBadgeFill;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.62;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: outline),
        boxShadow: [
          BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 7)),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.46),
                    accent.withValues(alpha: 0.12),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: playBadgeFill.withValues(alpha: 0.96),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.play,
                  size: width * 0.28, color: accent.withValues(alpha: 0.98)),
            ),
          ),
          Positioned(
            right: 5,
            bottom: 4,
            child: Text(
              "00:00",
              style: TextStyle(
                fontSize: width * 0.14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyzeHeroBackdropPainter extends CustomPainter {
  _AnalyzeHeroBackdropPainter({
    required this.t,
    required this.primary,
    required this.secondary,
    required this.glowFill,
  });

  final double t;
  final Color primary;
  final Color secondary;
  final Color glowFill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.42);
    final breathe = 0.92 + 0.08 * math.sin(t * 2 * math.pi);
    final ss = size.shortestSide * breathe;

    paintLinkClipOrbitalRings(
      canvas: canvas,
      center: c,
      shortestSide: ss,
      t: t,
      primary: primary,
      secondary: secondary,
      ringCount: 5,
      baseRadiusFraction: 0.19,
      radiusStepFraction: 0.064,
    );

    // Extra faint full circles — orbital depth (no central blob fill).
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        c,
        ss * (0.48 + i * 0.11),
        Paint()
          ..color = glowFill.withValues(
              alpha: 0.045 + 0.025 * math.sin(t * math.pi * 2 + i * 1.1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnalyzeHeroBackdropPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary ||
        oldDelegate.glowFill != glowFill;
  }
}

class _DecorativeIndeterminateRingPainter extends CustomPainter {
  _DecorativeIndeterminateRingPainter({
    required this.t,
    required this.primary,
    required this.track,
  });

  final double t;
  final Color primary;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 3;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final sweep = math.pi * 1.35;
    final start = -math.pi / 2 + t * 2 * math.pi * 1.8;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      sweep,
      false,
      Paint()
        ..color = primary.withValues(alpha: 0.96)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(
          covariant _DecorativeIndeterminateRingPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.primary != primary;
}
