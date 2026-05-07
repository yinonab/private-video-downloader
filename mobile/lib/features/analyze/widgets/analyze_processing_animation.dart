import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/theme/linkclip_palette.dart";

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
  State<AnalyzeProcessingAnimation> createState() => _AnalyzeProcessingAnimationState();
}

class _AnalyzeProcessingAnimationState extends State<AnalyzeProcessingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
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
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
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
                                glowFill: palette.loaderBubble.withValues(alpha: theme.brightness == Brightness.dark ? 0.48 : 0.78),
                              ),
                            ),
                            CustomPaint(
                              size: Size(maxW, heroH),
                              painter: _AnalyzeHeroPainter(
                                t: _ctrl.value,
                                primary: scheme.primary,
                                secondary: scheme.secondary,
                                silhouette: Color.lerp(
                                      scheme.surfaceContainerHighest,
                                      scheme.primary.withValues(alpha: 0.92),
                                      theme.brightness == Brightness.dark ? 0.55 : 0.18,
                                    ) ??
                                    scheme.surfaceContainerHighest,
                              ),
                            ),
                            ..._floatingCards(context, heroH, maxW),
                            Positioned(
                              bottom: heroH * 0.06,
                              child: _PulseArrow(t: _ctrl.value, color: scheme.primary),
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
                            track: scheme.outline.withValues(alpha: theme.brightness == Brightness.dark ? 0.48 : 0.34),
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
            final bob = math.sin((_ctrl.value * 2 * math.pi * 1.3) + s.phase) * 5;
            final fade = 0.78 + 0.18 * math.sin((_ctrl.value * 2 * math.pi * 0.9) + s.phase * 0.7);
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
          Shadow(color: color.withValues(alpha: 0.28), blurRadius: 26, offset: const Offset(0, 5)),
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
          BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 7)),
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
              child: Icon(LucideIcons.play, size: width * 0.28, color: accent.withValues(alpha: 0.98)),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
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

    final rg = ui.Gradient.radial(
      c,
      size.shortestSide * 0.52 * breathe,
      [
        primary.withValues(alpha: 0.36),
        secondary.withValues(alpha: 0.16),
        glowFill.withValues(alpha: 0.08),
      ],
      const [0.0, 0.45, 1.0],
    );
    final paint = Paint()..shader = rg;
    canvas.drawCircle(c, size.shortestSide * 0.58 * breathe, paint);

    // Secondary soft halo
    canvas.drawCircle(
      c,
      size.shortestSide * 0.72,
      Paint()
        ..color = primary.withValues(alpha: 0.1 + 0.06 * math.sin(t * 2 * math.pi * 0.5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalyzeHeroBackdropPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.primary != primary;
  }
}

class _AnalyzeHeroPainter extends CustomPainter {
  _AnalyzeHeroPainter({
    required this.t,
    required this.primary,
    required this.secondary,
    required this.silhouette,
  });

  final double t;
  final Color primary;
  final Color secondary;
  final Color silhouette;

  static const List<Offset> _brainNorm = [
    Offset(0.52, 0.38),
    Offset(0.62, 0.42),
    Offset(0.58, 0.52),
    Offset(0.48, 0.54),
    Offset(0.42, 0.46),
    Offset(0.46, 0.34),
    Offset(0.56, 0.30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.42;

    canvas.save();
    canvas.translate(cx, cy);

    // Scan rings
    for (var i = 0; i < 3; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final rot = t * 2 * math.pi * (0.12 + i * 0.07) * dir;
      final r = w * (0.34 + i * 0.07);
      canvas.save();
      canvas.rotate(rot);
      final arcPaint = Paint()
        ..color = primary.withValues(alpha: 0.28 - i * 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 + i.toDouble()
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        -math.pi * 0.35,
        math.pi * 1.55,
        false,
        arcPaint,
      );
      if (i == 1) {
        final dashPaint = Paint()
          ..color = secondary.withValues(alpha: 0.34)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r * 0.92),
          math.pi * 0.2,
          math.pi * 1.1,
          false,
          dashPaint,
        );
      }
      canvas.restore();
    }

    // Head silhouette (abstract profile facing left)
    final headPath = Path()
      ..moveTo(w * 0.22, -h * 0.02)
      ..quadraticBezierTo(w * 0.42, -h * 0.34, w * 0.08, -h * 0.38)
      ..quadraticBezierTo(-w * 0.28, -h * 0.28, -w * 0.34, h * 0.02)
      ..quadraticBezierTo(-w * 0.36, h * 0.22, -w * 0.22, h * 0.30)
      ..quadraticBezierTo(-w * 0.06, h * 0.38, w * 0.06, h * 0.32)
      ..quadraticBezierTo(w * 0.18, h * 0.22, w * 0.22, -h * 0.02)
      ..close();

    canvas.drawPath(
      headPath,
      Paint()
        ..color = silhouette
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      headPath,
      Paint()
        ..color = primary.withValues(alpha: 0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Brain clip + glow
    final brainOval = Path()
      ..addOval(Rect.fromCenter(center: Offset(w * 0.02, -h * 0.06), width: w * 0.42, height: h * 0.36));

    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.intersect, headPath, brainOval));

    final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi);
    final brainShader = ui.Gradient.radial(
      Offset(w * 0.02, -h * 0.08),
      w * 0.22 * pulse,
      [
        primary.withValues(alpha: 0.82),
        secondary.withValues(alpha: 0.58),
        primary.withValues(alpha: 0.26),
      ],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawPath(brainOval, Paint()..shader = brainShader);

    // Neural connections
    final pts = _brainNorm.map((p) => Offset((p.dx - 0.5) * w * 0.52, (p.dy - 0.42) * h)).toList();
    final linePaint = Paint()
      ..color = primary.withValues(alpha: 0.42 + 0.22 * math.sin(t * 2 * math.pi))
      ..strokeWidth = 1.85;
    for (var i = 0; i < pts.length; i++) {
      for (var j = i + 1; j < pts.length; j++) {
        if ((i - j).abs() <= 2 || (i == 0 && j == pts.length - 1)) {
          canvas.drawLine(pts[i], pts[j], linePaint);
        }
      }
    }

    // Nodes
    for (var i = 0; i < pts.length; i++) {
      final phase = i * 0.73;
      final nodePulse = 0.55 + 0.45 * math.sin(t * 2 * math.pi * 1.2 + phase);
      canvas.drawCircle(
        pts[i],
        3.2 + nodePulse * 1.4,
        Paint()..color = Colors.white.withValues(alpha: 0.38 + nodePulse * 0.48),
      );
      canvas.drawCircle(
        pts[i],
        2.45,
        Paint()..color = primary.withValues(alpha: 0.95),
      );
    }

    // Slow gear
    canvas.save();
    canvas.translate(w * 0.02, -h * 0.07);
    canvas.rotate(t * 2 * math.pi * 0.35);
    final gear = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final rr = w * 0.045;
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      canvas.drawLine(
        Offset(math.cos(a) * rr * 0.5, math.sin(a) * rr * 0.5),
        Offset(math.cos(a) * rr * 1.25, math.sin(a) * rr * 1.25),
        gear,
      );
    }
    canvas.drawCircle(Offset.zero, rr * 0.55, gear);
    canvas.restore();

    canvas.restore(); // clip

    canvas.restore(); // translate cx cy
  }

  @override
  bool shouldRepaint(covariant _AnalyzeHeroPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.primary != primary || oldDelegate.silhouette != silhouette;
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
  bool shouldRepaint(covariant _DecorativeIndeterminateRingPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.primary != primary;
}
