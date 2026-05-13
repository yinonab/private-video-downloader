import "dart:math" as math;

import "package:flutter/material.dart";

import "../../../core/theme/linkclip_palette.dart";

/// Export / processing hero: **recognizable scissors** (`Icons.content_cut`) +
/// painted filmstrip + vertical video frame + flying film shards + rotating glow ring.
///
/// Decorative only — real editing happens on the server (`/edits`).
class EditProcessingAnimation extends StatefulWidget {
  const EditProcessingAnimation({
    super.key,
    this.size = 300,
    this.color,
    this.accentGlow,
  });

  final double size;
  final Color? color;
  final Color? accentGlow;

  @override
  State<EditProcessingAnimation> createState() =>
      _EditProcessingAnimationState();
}

class _EditProcessingAnimationState extends State<EditProcessingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.lcPalette;
    final primary = widget.color ?? scheme.primary;
    final glow = widget.accentGlow ?? palette.loaderBubble;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.size;

    return RepaintBoundary(
      child: SizedBox(
        width: s,
        height: s,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(s, s),
                  painter: _FilmCutBackdropPainter(
                    t: t,
                    primary: primary,
                    accentGlow: glow,
                    dark: dark,
                  ),
                ),
                for (var i = 0; i < 6; i++)
                  _orbitScissor(
                    index: i,
                    t: t,
                    size: s,
                    color: primary,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Six large Material **content_cut** icons on elliptical orbits; periodic “bunch”
  /// toward the central film frame reads as cutting / editing.
  Widget _orbitScissor({
    required int index,
    required double t,
    required double size,
    required Color color,
  }) {
    const count = 6;
    final cx = size / 2;
    final cy = size * 0.48;

    final orbitAngle = t * math.pi * 2 + index * (math.pi * 2 / count);
    // Periodic tighten toward center (cut beats).
    final cosBeat = (math.cos(t * math.pi * 6 + index * 0.4)).clamp(-1.0, 1.0);
    final bunch = 0.58 + 0.42 * (cosBeat * cosBeat);

    var rx = size * 0.39 * bunch;
    var ry = size * 0.30 * bunch;

    var ox = cx + math.cos(orbitAngle) * rx;
    var oy = cy + math.sin(orbitAngle) * ry;

    // Pair-cross moment: two scissors dip toward filmstrip midline.
    final crossWave = math.sin(t * math.pi * 10);
    if (index == 1 || index == 4) {
      oy += crossWave * size * 0.035;
      ox += (index == 1 ? 1 : -1) * crossWave.abs() * size * 0.022;
    }

    // Blade “snip” wobble on rotation (whole icon tilts).
    final snip = math.sin(t * math.pi * 14 + index * 1.1) * 0.28;

    final rotation = orbitAngle + math.pi * 0.5 + snip;
    final iconSize = size * 0.145;

    return Positioned(
      left: ox - iconSize / 2,
      top: oy - iconSize / 2,
      child: Transform.rotate(
        angle: rotation,
        child: Icon(
          Icons.content_cut_rounded,
          size: iconSize,
          color: color.withValues(alpha: 0.94),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            Shadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: Offset.zero,
            ),
          ],
        ),
      ),
    );
  }
}

/// Background only: rotating processing ring, vertical video/film card, filmstrip
/// interior, flying mini film frames, subtle sparks (no painted scissors).
class _FilmCutBackdropPainter extends CustomPainter {
  _FilmCutBackdropPainter({
    required this.t,
    required this.primary,
    required this.accentGlow,
    required this.dark,
  });

  final double t;
  final Color primary;
  final Color accentGlow;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.48;
    final s = size.shortestSide;

    _vignette(canvas, size, cx, cy, s);
    _rotatingGlowRing(canvas, cx, cy, s);
    _softOrbBehindPhone(canvas, cx, cy, s);

    final phoneW = s * 0.34;
    final phoneH = s * 0.58;
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: phoneW, height: phoneH),
      Radius.circular(s * 0.045),
    );

    _phoneDropShadow(canvas, phone);
    _phoneBezel(canvas, phone, s);
    final inner = phone.deflate(s * 0.026);
    _videoGradientFill(canvas, inner);
    _filmstripInsideFrame(canvas, inner, s);
    _flyingFilmShards(canvas, inner, cx, cy, s);
    _ringSparksOnly(canvas, cx, cy, s * 0.42);
  }

  void _vignette(Canvas canvas, Size size, double cx, double cy, double s) {
    final p = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: dark ? 0.08 : 0.05),
          Colors.black.withValues(alpha: dark ? 0.62 : 0.42),
        ],
        stops: const [0.25, 1],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s));
    canvas.drawRect(Offset.zero & size, p);
  }

  void _rotatingGlowRing(Canvas canvas, double cx, double cy, double s) {
    final r = s * 0.42;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.034
      ..shader = SweepGradient(
        colors: [
          accentGlow.withValues(alpha: 0.88),
          primary.withValues(alpha: 0.32),
          accentGlow.withValues(alpha: 0.62),
          primary.withValues(alpha: 0.48),
          accentGlow.withValues(alpha: 0.92),
        ],
        stops: const [0.0, 0.22, 0.48, 0.72, 1.0],
        transform: GradientRotation(-t * math.pi * 2),
      ).createShader(rect);
    canvas.drawArc(rect, 0, math.pi * 2, false, ring);
  }

  void _softOrbBehindPhone(Canvas canvas, double cx, double cy, double s) {
    final pulse = 0.85 + 0.15 * math.sin(t * math.pi * 2);
    final orb = Paint()
      ..shader = RadialGradient(
        colors: [
          accentGlow.withValues(alpha: (dark ? 0.38 : 0.26) * pulse),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s * 0.32));
    canvas.drawCircle(Offset(cx, cy), s * 0.32, orb);
  }

  void _phoneDropShadow(Canvas canvas, RRect phone) {
    canvas.drawRRect(
      phone.shift(const Offset(5, 9)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  void _phoneBezel(Canvas canvas, RRect phone, double s) {
    final bezel = Paint()
      ..shader = LinearGradient(
        colors: [
          primary.withValues(alpha: 0.92),
          accentGlow.withValues(alpha: 0.68),
        ],
      ).createShader(phone.outerRect);
    canvas.drawRRect(phone.inflate(2.5), bezel);

    canvas.drawRRect(
      phone.inflate(2.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.01
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  void _videoGradientFill(Canvas canvas, RRect inner) {
    final pulse = 0.04 * math.sin(t * math.pi * 3);
    canvas.drawRRect(
      inner,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(primary, Colors.white, 0.28 + pulse)!,
            Color.lerp(primary, Colors.deepPurple, 0.42)!,
            Colors.black.withValues(alpha: 0.72),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(inner.outerRect),
    );
  }

  /// Clear filmstrip: perforated edges + stacked “frames” inside the phone.
  void _filmstripInsideFrame(Canvas canvas, RRect inner, double s) {
    final rect = inner.outerRect;
    final hole = Paint()..color = Colors.white.withValues(alpha: 0.48);
    final step = math.max(10.0, rect.height / 10);
    for (var y = rect.top + 7; y < rect.bottom - 6; y += step) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(rect.left + 6, y),
              width: 5,
              height: math.min(7.0, step * 0.55)),
          const Radius.circular(1.5),
        ),
        hole,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(rect.right - 6, y),
              width: 5,
              height: math.min(7.0, step * 0.55)),
          const Radius.circular(1.5),
        ),
        hole,
      );
    }

    const bands = 4;
    final bh = rect.height / bands;
    for (var i = 0; i < bands; i++) {
      final glow =
          0.55 + 0.45 * math.sin(t * math.pi * 2 + i / bands * math.pi * 2);
      final top = rect.top + i * bh + bh * 0.1;
      final cell = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + rect.width * 0.14,
          top,
          rect.width * 0.72,
          bh * 0.74,
        ),
        Radius.circular(bh * 0.12),
      );
      canvas.drawRRect(
        cell,
        Paint()..color = Colors.white.withValues(alpha: 0.06 + 0.16 * glow),
      );
      canvas.drawRRect(
        cell,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.18 + 0.18 * glow),
      );
    }
  }

  /// Mini film frames (rounded rects + sprocket dots) drift outward and fade.
  void _flyingFilmShards(
      Canvas canvas, RRect inner, double cx, double cy, double s) {
    const n = 10;
    final rect = inner.outerRect;
    for (var i = 0; i < n; i++) {
      final phase = (t * 1.35 + i / n) % 1.0;
      final ang = i / n * math.pi * 2 + t * math.pi * 0.8;
      final dist = phase * s * 0.46;
      final sx = rect.center.dx + math.cos(ang) * (rect.width * 0.42 + dist);
      final sy =
          rect.center.dy + math.sin(ang) * (rect.height * 0.42 + dist * 0.85);

      final a = ((1 - phase) * 0.82).clamp(0.0, 1.0);
      if (a < 0.03) continue;

      canvas.save();
      canvas.translate(sx, sy);
      canvas.rotate(ang * 0.6 + phase * math.pi);
      final fw = s * 0.088;
      final fh = s * 0.054;
      final shard = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: fw, height: fh),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        shard,
        Paint()
          ..color = primary.withValues(alpha: 0.35 * a + 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        shard,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.45 * a),
      );
      // Tiny “perfs”
      final perf = Paint()..color = Colors.white.withValues(alpha: 0.35 * a);
      canvas.drawCircle(Offset(-fw * 0.38, -fh * 0.15), 1.8, perf);
      canvas.drawCircle(Offset(-fw * 0.38, fh * 0.15), 1.8, perf);
      canvas.restore();
    }
  }

  /// Few sparks sitting on the ring — secondary only.
  void _ringSparksOnly(Canvas canvas, double cx, double cy, double r) {
    const m = 8;
    for (var i = 0; i < m; i++) {
      final ang = i / m * math.pi * 2 + t * math.pi * 2.5;
      final wobble = 0.94 + 0.06 * math.sin(t * math.pi * 8 + i);
      final sx = cx + math.cos(ang) * r * wobble;
      final sy = cy + math.sin(ang) * r * wobble * 0.88;
      final spark = Paint()
        ..color = Color.lerp(primary, accentGlow, i.isEven ? 0.55 : 0.2)!
            .withValues(alpha: 0.22 + 0.38 * ((i + (t * m).floor()) % 3 / 3));
      canvas.drawCircle(Offset(sx, sy), 2.8, spark);
    }
  }

  @override
  bool shouldRepaint(covariant _FilmCutBackdropPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.primary != primary ||
        oldDelegate.accentGlow != accentGlow ||
        oldDelegate.dark != dark;
  }
}
