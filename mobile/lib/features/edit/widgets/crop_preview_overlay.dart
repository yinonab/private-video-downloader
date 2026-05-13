import "package:flutter/material.dart";

import "../../../core/models/quick_edit_models.dart";

/// Dimmed outside region + rule-of-thirds inside crop window (center-crop approximation).
class CropPreviewOverlay extends StatelessWidget {
  const CropPreviewOverlay({
    super.key,
    required this.aspect,
    required this.primaryColor,
  });

  final QuickEditCropAspect aspect;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CropOverlayPainter(aspect: aspect, accent: primaryColor),
      child: const SizedBox.expand(),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter({required this.aspect, required this.accent});

  final QuickEditCropAspect aspect;
  final Color accent;

  double _targetAspect() {
    return switch (aspect) {
      QuickEditCropAspect.original => -1,
      QuickEditCropAspect.nineSixteen => 9 / 16,
      QuickEditCropAspect.oneOne => 1,
      QuickEditCropAspect.sixteenNine => 16 / 9,
      QuickEditCropAspect.fourFive => 4 / 5,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final frameW = size.width;
    final frameH = size.height;
    if (frameW <= 0 || frameH <= 0) return;

    final containerAspect = frameW / frameH;
    final targetAspect = _targetAspect();
    if (targetAspect <= 0) return;

    double iw;
    double ih;
    if (targetAspect >= containerAspect) {
      iw = frameW;
      ih = frameW / targetAspect;
    } else {
      ih = frameH;
      iw = frameH * targetAspect;
    }

    iw = iw.clamp(1.0, frameW);
    ih = ih.clamp(1.0, frameH);

    final left = (frameW - iw) / 2;
    final top = (frameH - ih) / 2;
    final cropRect = Rect.fromLTWH(left, top, iw, ih);

    final dim = Paint()..color = Colors.black.withValues(alpha: 0.62);
    canvas.drawRect(Rect.fromLTWH(0, 0, frameW, top), dim);
    canvas.drawRect(Rect.fromLTWH(0, top + ih, frameW, frameH - top - ih), dim);
    canvas.drawRect(Rect.fromLTWH(0, top, left, ih), dim);
    canvas.drawRect(Rect.fromLTWH(left + iw, top, frameW - left - iw, ih), dim);

    final accentBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = accent.withValues(alpha: 0.95);
    canvas.drawRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(6)),
        accentBorder);
    final innerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.42);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            cropRect.deflate(1.25), const Radius.circular(5)),
        innerGlow);

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Colors.white.withValues(alpha: 0.42);
    final gx1 = cropRect.left + cropRect.width / 3;
    final gx2 = cropRect.left + 2 * cropRect.width / 3;
    final gy1 = cropRect.top + cropRect.height / 3;
    final gy2 = cropRect.top + 2 * cropRect.height / 3;
    canvas.drawLine(
        Offset(gx1, cropRect.top), Offset(gx1, cropRect.bottom), grid);
    canvas.drawLine(
        Offset(gx2, cropRect.top), Offset(gx2, cropRect.bottom), grid);
    canvas.drawLine(
        Offset(cropRect.left, gy1), Offset(cropRect.right, gy1), grid);
    canvas.drawLine(
        Offset(cropRect.left, gy2), Offset(cropRect.right, gy2), grid);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.aspect != aspect || oldDelegate.accent != accent;
  }
}
