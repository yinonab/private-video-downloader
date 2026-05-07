import "dart:math" as math;
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/theme/linkclip_palette.dart";

enum _HeroVisualMode { pulse, download, scan, process, finalize }

/// Compact animated hero for active download / processing on [DownloadStatusScreen].
class DownloadProgressHeroAnimation extends StatefulWidget {
  const DownloadProgressHeroAnimation({
    super.key,
    required this.processingStage,
    required this.status,
    required this.subtitle,
    this.progressPercent,
    this.isTikTokReady = false,
  });

  final String processingStage;
  final String status;
  final String subtitle;

  /// Raw server percent; `null` or `<= 0` yields indeterminate ring (no fake 0%).
  final int? progressPercent;
  final bool isTikTokReady;

  @override
  State<DownloadProgressHeroAnimation> createState() => _DownloadProgressHeroAnimationState();
}

class _DownloadProgressHeroAnimationState extends State<DownloadProgressHeroAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3800))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static String _effectiveStage(String raw, String status) {
    final r = raw.trim().toLowerCase();
    if (r.isNotEmpty) return r;
    switch (status.trim()) {
      case "queued":
        return "queued";
      case "analyzing":
        return "preparing";
      case "running":
        return "downloading";
      default:
        return "queued";
    }
  }

  static _HeroVisualMode _modeForStage(String stage) {
    switch (stage) {
      case "queued":
      case "preparing":
        return _HeroVisualMode.pulse;
      case "downloading":
        return _HeroVisualMode.download;
      case "checking_compatibility":
        return _HeroVisualMode.scan;
      case "remuxing":
      case "normalizing_audio":
      case "full_transcoding":
        return _HeroVisualMode.process;
      case "finalizing":
        return _HeroVisualMode.finalize;
      default:
        return _HeroVisualMode.pulse;
    }
  }

  static int? _effectivePercent(int? p) {
    if (p == null || p <= 0) return null;
    return p.clamp(1, 100);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.lcPalette;

    final stage = _effectiveStage(widget.processingStage, widget.status);
    final mode = _modeForStage(stage);
    final pct = _effectivePercent(widget.progressPercent);

    final accent = widget.isTikTokReady ? palette.tiktokAccent : scheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final heroH = (maxW * 0.42).clamp(152.0, 248.0);

        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: heroH,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      CustomPaint(
                        size: Size(maxW, heroH),
                        painter: _DownloadHeroBackdropPainter(
                          t: _ctrl.value,
                          primary: accent,
                          secondary: scheme.secondary,
                          soft: palette.loaderBubble.withValues(alpha: theme.brightness == Brightness.dark ? 0.52 : 0.68),
                          mode: mode,
                        ),
                      ),
                      CustomPaint(
                        size: Size(maxW, heroH),
                        painter: _DownloadHeroEffectsPainter(
                          t: _ctrl.value,
                          primary: accent,
                          secondary: scheme.secondary,
                          mode: mode,
                          progress: pct,
                          dark: theme.brightness == Brightness.dark,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.download,
                            size: heroH * 0.22,
                            color: accent.withValues(alpha: 0.98),
                          ),
                          if (pct != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              "$pct%",
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DownloadHeroBackdropPainter extends CustomPainter {
  _DownloadHeroBackdropPainter({
    required this.t,
    required this.primary,
    required this.secondary,
    required this.soft,
    required this.mode,
  });

  final double t;
  final Color primary;
  final Color secondary;
  final Color soft;
  final _HeroVisualMode mode;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.5);
    final breathe = switch (mode) {
      _HeroVisualMode.finalize => 0.94 + 0.06 * math.sin(t * 2 * math.pi * 1.2),
      _ => 0.9 + 0.1 * math.sin(t * 2 * math.pi * 0.9),
    };

    final rg = ui.Gradient.radial(
      c,
      size.shortestSide * 0.55 * breathe,
      [
        primary.withValues(alpha: 0.28),
        secondary.withValues(alpha: 0.14),
        soft.withValues(alpha: 0.05),
      ],
      const [0.0, 0.5, 1.0],
    );
    canvas.drawCircle(c, size.shortestSide * 0.62, Paint()..shader = rg);
  }

  @override
  bool shouldRepaint(covariant _DownloadHeroBackdropPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.mode != mode || oldDelegate.primary != primary;
}

class _DownloadHeroEffectsPainter extends CustomPainter {
  _DownloadHeroEffectsPainter({
    required this.t,
    required this.primary,
    required this.secondary,
    required this.mode,
    required this.progress,
    required this.dark,
  });

  final double t;
  final Color primary;
  final Color secondary;
  final _HeroVisualMode mode;
  final int? progress;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.5);
    final r = size.shortestSide * 0.38;

    final track = Paint()
      ..color = primary.withValues(alpha: dark ? 0.38 : 0.26)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    canvas.drawCircle(c, r, track);

    // Progress ring
    if (progress != null) {
      final sweep = 2 * math.pi * (progress! / 100.0);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..color = primary.withValues(alpha: 0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final rot = t * 2 * math.pi * 1.25;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(rot);
      final seg = math.pi * 0.42;
      for (var i = 0; i < 3; i++) {
        final a = i * math.pi * 2 / 3 - math.pi / 2;
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          a,
          seg,
          false,
          Paint()
            ..color = primary.withValues(alpha: 0.72 + 0.22 * math.sin(t * 2 * math.pi + i))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
    }

    // Mode-specific motion inside ring
    switch (mode) {
      case _HeroVisualMode.download:
        _drawParticles(canvas, c, r * 0.55);
        break;
      case _HeroVisualMode.finalize:
        _drawFinalizeGlow(canvas, c, r * 0.58);
        break;
      case _HeroVisualMode.scan:
        _drawRadar(canvas, c, r * 0.72);
        break;
      case _HeroVisualMode.process:
        _drawWaveBars(canvas, c, r * 0.65);
        break;
      case _HeroVisualMode.pulse:
        _drawPulseRing(canvas, c, r * 0.62);
        break;
    }
  }

  void _drawFinalizeGlow(Canvas canvas, Offset c, double baseR) {
    final pulse = 0.82 + 0.18 * math.sin(t * 2 * math.pi * 1.05);
    canvas.drawCircle(
      c,
      baseR * pulse,
      Paint()
        ..color = secondary.withValues(alpha: 0.14 + 0.1 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      c,
      baseR * 0.72 * pulse,
      Paint()
        ..color = primary.withValues(alpha: 0.1 + 0.06 * math.sin(t * 2 * math.pi * 1.4))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawParticles(Canvas canvas, Offset c, double spread) {
    final count = 10;
    for (var i = 0; i < count; i++) {
      final phase = i / count;
      final y = ((t + phase) % 1.0) * (spread * 2.6) - spread * 1.25;
      final x = math.sin((phase + t) * math.pi * 2) * spread * 0.55;
      final op = (1 - ((t + phase) % 1.0)) * 0.72;
      canvas.drawCircle(
        Offset(c.dx + x, c.dy + y),
        2.2 + phase * 1.5,
        Paint()..color = secondary.withValues(alpha: op.clamp(0.15, 0.72)),
      );
    }
  }

  void _drawRadar(Canvas canvas, Offset c, double radius) {
    final sweepPaint = Paint()
      ..shader = ui.Gradient.radial(
        c.translate(math.cos(math.pi * 2 * t + math.pi * 0.28) * radius * 0.35,
            math.sin(math.pi * 2 * t + math.pi * 0.28) * radius * 0.35),
        radius * 0.85,
        [
          primary.withValues(alpha: 0.28),
          primary.withValues(alpha: 0.0),
        ],
      )
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: radius),
      math.pi * 2 * t,
      math.pi * 0.55,
      true,
      sweepPaint,
    );
    canvas.drawCircle(
      c,
      radius,
      Paint()
        ..color = primary.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawWaveBars(Canvas canvas, Offset c, double width) {
    final bars = 5;
    final gap = width * 2 / (bars * 2 + 1);
    for (var i = 0; i < bars; i++) {
      final cx = c.dx - width + gap + i * gap * 2;
      final h = 8 + 14 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 1.4 + i * 0.9));
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, c.dy + 8), width: gap * 0.55, height: h),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = primary.withValues(alpha: 0.35 + 0.25 * math.sin(t * 2 * math.pi + i)),
      );
    }
  }

  void _drawPulseRing(Canvas canvas, Offset c, double baseR) {
    final pulse = baseR + 6 * math.sin(t * 2 * math.pi * 1.1);
    canvas.drawCircle(
      c,
      pulse,
      Paint()
        ..color = primary.withValues(alpha: 0.18 + 0.1 * math.sin(t * 2 * math.pi))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _DownloadHeroEffectsPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.mode != mode ||
        oldDelegate.progress != progress ||
        oldDelegate.primary != primary;
  }
}
