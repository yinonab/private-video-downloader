import "package:flutter/material.dart";

/// Muted thumbs with **S** / **E** (always LTR). Touch target ≥ 44 px; visual ~30 px.
class TrimLabeledRangeThumbShape extends RangeSliderThumbShape {
  const TrimLabeledRangeThumbShape({
    required this.colorScheme,
    this.highlightedThumb,
  });

  final ColorScheme colorScheme;
  final Thumb? highlightedThumb;

  static const double visualRadius = 15;

  static const double interactionSide = 44;

  Color _thumbFill(Thumb thumb, bool enabled) {
    final base = colorScheme.primary.withValues(alpha: enabled ? 0.86 : 0.45);
    if (highlightedThumb == null || highlightedThumb == thumb) {
      return base;
    }
    return base.withValues(alpha: enabled ? 0.62 : 0.38);
  }

  BorderSide _border(Thumb thumb) {
    if (highlightedThumb == thumb) {
      return BorderSide(
        color: colorScheme.primary.withValues(alpha: 0.78),
        width: 2,
      );
    }
    return BorderSide(
      color: colorScheme.outline.withValues(alpha: 0.42),
      width: 1,
    );
  }

  String _letter(Thumb thumb) => thumb == Thumb.start ? "S" : "E";

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return const Size.square(interactionSide);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required SliderThemeData sliderTheme,
    bool? isDiscrete,
    bool? isEnabled,
    bool? isOnTop,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    if (thumb == null) return;

    final enabled = isEnabled ?? true;
    final pressed = isPressed ?? false;
    final canvas = context.canvas;

    final fill = Paint()
      ..color = _thumbFill(thumb, enabled)
      ..style = PaintingStyle.fill;

    final b = _border(thumb);
    final stroke = Paint()
      ..color = b.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = b.width;

    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: visualRadius)),
      Colors.black.withValues(alpha: pressed ? 0.42 : 0.26),
      pressed ? 6.5 : 3.8,
      true,
    );
    canvas.drawCircle(center, visualRadius, fill);
    canvas.drawCircle(center, visualRadius - b.width / 2, stroke);

    final tp = TextPainter(
      text: TextSpan(
        text: _letter(thumb),
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimary.withValues(alpha: enabled ? 0.95 : 0.55),
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 2,
              offset: const Offset(0, 0.85),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }
}
