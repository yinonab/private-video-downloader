import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/theme/linkclip_palette.dart";

/// Full-page hero while download status has no [DownloadDetailResponse] yet (and no error).
/// Visual theme: media flowing downward into the app — distinct from the Analyze “brain” hero.
class InitialDownloadLoadingAnimation extends StatefulWidget {
  const InitialDownloadLoadingAnimation({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  State<InitialDownloadLoadingAnimation> createState() => _InitialDownloadLoadingAnimationState();
}

class _InitialDownloadLoadingAnimationState extends State<InitialDownloadLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
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
        final heroH = (maxW * 1.05).clamp(320.0, 460.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
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
                          painter: _InitialDownloadBackdropPainter(
                            t: _ctrl.value,
                            primary: scheme.primary,
                            secondary: scheme.secondary,
                            glowFill: palette.loaderBubble.withValues(
                              alpha: theme.brightness == Brightness.dark ? 0.45 : 0.72,
                            ),
                          ),
                        ),
                        CustomPaint(
                          size: Size(maxW, heroH),
                          painter: _InitialDownloadMotionPainter(
                            t: _ctrl.value,
                            primary: scheme.primary,
                            secondary: scheme.secondary,
                          ),
                        ),
                        ..._descendingCards(context, heroH, maxW, scheme, palette),
                        Positioned(
                          bottom: heroH * 0.14,
                          child: _DownloadPulseArrow(t: _ctrl.value, color: scheme.primary),
                        ),
                        Transform.translate(
                          offset: Offset(0, math.sin(_ctrl.value * 2 * math.pi * 1.2) * 5),
                          child: Icon(
                            LucideIcons.download,
                            size: heroH * 0.16,
                            color: scheme.primary.withValues(alpha: 0.96),
                            shadows: [
                              Shadow(color: scheme.primary.withValues(alpha: 0.42), blurRadius: 22),
                              Shadow(color: scheme.secondary.withValues(alpha: 0.28), blurRadius: 34),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                width: 48,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _InitialScanRingPainter(
                        t: _ctrl.value,
                        primary: scheme.primary,
                        track: scheme.outline.withValues(alpha: theme.brightness == Brightness.dark ? 0.42 : 0.28),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
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
        );
      },
    );
  }

  List<Widget> _descendingCards(
    BuildContext context,
    double heroH,
    double maxW,
    ColorScheme scheme,
    LinkClipPalette palette,
  ) {
    final specs = <({double xFrac, double phase, double w, double span})>[
      (xFrac: 0.12, phase: 0.0, w: 54, span: 0.85),
      (xFrac: 0.78, phase: 0.22, w: 50, span: 0.92),
      (xFrac: 0.42, phase: 0.55, w: 48, span: 0.78),
      (xFrac: 0.62, phase: 0.38, w: 52, span: 0.88),
      (xFrac: 0.88, phase: 0.72, w: 46, span: 0.95),
      (xFrac: 0.22, phase: 0.65, w: 50, span: 0.82),
    ];

    return specs.map((s) {
      final dx = maxW * s.xFrac - s.w / 2;
      return Positioned(
        left: dx,
        top: 0,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final progress = (_ctrl.value + s.phase) % 1.0;
            final y = -heroH * 0.08 + progress * heroH * (0.92 + s.span * 0.08);
            final sway = math.sin(progress * math.pi * 4 + s.phase * 3) * 9;
            final fade = (progress < 0.15)
                ? progress / 0.15
                : (progress > 0.82 ? (1 - progress) / 0.18 : 1.0);
            return Transform.translate(
              offset: Offset(sway, y),
              child: Opacity(
                opacity: fade.clamp(0.35, 1.0),
                child: _FlowMiniVideoCard(
                  width: s.w,
                  accent: scheme.primary,
                  surface: scheme.surface,
                  outline: scheme.outline.withValues(alpha: 0.48),
                  playBadgeFill: scheme.surfaceContainerHighest,
                  palette: palette,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
}

class _DownloadPulseArrow extends StatelessWidget {
  const _DownloadPulseArrow({required this.t, required this.color});

  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pulse = 0.9 + 0.1 * math.sin(t * 2 * math.pi * 2.2);
    final dy = math.sin(t * 2 * math.pi * 1.8) * 6;
    return Transform.translate(
      offset: Offset(0, dy),
      child: Icon(
        LucideIcons.arrowDown,
        size: 42 * pulse,
        color: color.withValues(alpha: 0.96),
        shadows: [
          Shadow(color: color.withValues(alpha: 0.55), blurRadius: 18),
          Shadow(color: color.withValues(alpha: 0.28), blurRadius: 28, offset: const Offset(0, 6)),
        ],
      ),
    );
  }
}

class _FlowMiniVideoCard extends StatelessWidget {
  const _FlowMiniVideoCard({
    required this.width,
    required this.accent,
    required this.surface,
    required this.outline,
    required this.playBadgeFill,
    required this.palette,
    required this.dark,
  });

  final double width;
  final Color accent;
  final Color surface;
  final Color outline;
  final Color playBadgeFill;
  final LinkClipPalette palette;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final h = width * 0.62;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: outline, width: dark ? 1.2 : 1.4),
        boxShadow: dark
            ? [BoxShadow(color: accent.withValues(alpha: 0.42), blurRadius: 20, offset: const Offset(0, 9))]
            : [
                BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8)),
                ...palette.cardShadows,
              ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: dark ? 0.52 : 0.42),
                    accent.withValues(alpha: 0.12),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: playBadgeFill.withValues(alpha: 0.97),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.play, size: width * 0.3, color: accent.withValues(alpha: 0.96)),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 5,
            child: Text(
              "00:00",
              style: TextStyle(
                fontSize: width * 0.15,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialDownloadBackdropPainter extends CustomPainter {
  _InitialDownloadBackdropPainter({
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
    final breathe = 0.9 + 0.1 * math.sin(t * 2 * math.pi);

    final rg = ui.Gradient.radial(
      c,
      size.shortestSide * 0.48 * breathe,
      [
        primary.withValues(alpha: 0.38),
        secondary.withValues(alpha: 0.18),
        glowFill.withValues(alpha: 0.06),
      ],
      const [0.0, 0.48, 1.0],
    );
    canvas.drawCircle(c, size.shortestSide * 0.58 * breathe, Paint()..shader = rg);

    canvas.drawCircle(
      c,
      size.shortestSide * 0.68,
      Paint()
        ..color = primary.withValues(alpha: 0.12 + 0.08 * math.sin(t * 2 * math.pi * 0.55))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _InitialDownloadBackdropPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.primary != primary;
}

class _InitialDownloadMotionPainter extends CustomPainter {
  _InitialDownloadMotionPainter({
    required this.t,
    required this.primary,
    required this.secondary,
  });

  final double t;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.48);

    // Orbiting arcs
    for (var i = 0; i < 2; i++) {
      final dir = i.isEven ? 1.0 : -1.0;
      final rot = t * 2 * math.pi * (0.18 + i * 0.06) * dir;
      final r = size.shortestSide * (0.32 + i * 0.09);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rot);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        -math.pi * 0.25,
        math.pi * 1.35,
        false,
        Paint()
          ..color = primary.withValues(alpha: 0.26 - i * 0.06)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 + i.toDouble()
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }

    // Target tray at bottom (gathering area)
    final trayW = size.width * 0.44;
    final trayH = size.height * 0.08;
    final trayRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(c.dx, size.height * 0.88), width: trayW, height: trayH),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      trayRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(c.dx - trayW / 2, trayRect.center.dy),
          Offset(c.dx + trayW / 2, trayRect.center.dy),
          [
            primary.withValues(alpha: 0.22 + 0.08 * math.sin(t * 2 * math.pi)),
            secondary.withValues(alpha: 0.14),
          ],
        ),
    );
    canvas.drawRRect(
      trayRect,
      Paint()
        ..color = primary.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Falling sparks into tray
    for (var i = 0; i < 14; i++) {
      final phase = i / 14;
      final yy = ((t + phase) % 1.0) * size.height * 0.62;
      final xx = c.dx + math.sin((phase + t * 1.3) * math.pi * 3) * size.width * 0.22;
      final op = (1 - ((t + phase) % 1.0)) * 0.62;
      canvas.drawCircle(
        Offset(xx, size.height * 0.18 + yy),
        2.0 + phase,
        Paint()..color = secondary.withValues(alpha: op.clamp(0.12, 0.62)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InitialDownloadMotionPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.primary != primary;
}

class _InitialScanRingPainter extends CustomPainter {
  _InitialScanRingPainter({
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
        ..strokeWidth = 4,
    );
    final sweep = math.pi * 1.45;
    final start = -math.pi / 2 + t * 2 * math.pi * 2.1;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      start,
      sweep,
      false,
      Paint()
        ..color = primary.withValues(alpha: 0.94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _InitialScanRingPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.primary != primary;
}
