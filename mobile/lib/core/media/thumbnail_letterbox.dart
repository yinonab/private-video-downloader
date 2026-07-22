import "dart:ui" as ui;

import "package:flutter/foundation.dart";

/// Content bounds after stripping near-black letterbox / pillarbox bars.
final class ThumbnailContentBounds {
  const ThumbnailContentBounds({
    required this.imageWidth,
    required this.imageHeight,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final int imageWidth;
  final int imageHeight;
  final int left;
  final int top;
  final int right;
  final int bottom;

  int get contentWidth => right - left;
  int get contentHeight => bottom - top;

  double get imageAspect => imageWidth / imageHeight;
  double get contentAspect => contentWidth / contentHeight;

  /// True when bars take a meaningful share of the canvas.
  bool get hasSignificantBars {
    final barH = (top + (imageHeight - bottom)) / imageHeight;
    final barW = (left + (imageWidth - right)) / imageWidth;
    return barH >= 0.12 || barW >= 0.12;
  }

  /// Prefer content aspect when letterboxing is significant.
  double get displayAspect =>
      hasSignificantBars ? contentAspect : imageAspect;
}

/// Scans decoded RGBA bytes for near-black bars (common in platform thumbs).
ThumbnailContentBounds? analyzeLetterboxRgba({
  required ByteData rgba,
  required int width,
  required int height,
  int blackThreshold = 22,
  double rowBlackRatio = 0.92,
}) {
  if (width < 8 || height < 8) return null;
  final bytes = rgba.buffer.asUint8List(
    rgba.offsetInBytes,
    rgba.lengthInBytes,
  );
  if (bytes.length < width * height * 4) return null;

  bool rowMostlyBlack(int y) {
    var black = 0;
    final row = y * width * 4;
    for (var x = 0; x < width; x++) {
      final i = row + x * 4;
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      if (r <= blackThreshold && g <= blackThreshold && b <= blackThreshold) {
        black++;
      }
    }
    return black / width >= rowBlackRatio;
  }

  bool colMostlyBlack(int x) {
    var black = 0;
    for (var y = 0; y < height; y++) {
      final i = (y * width + x) * 4;
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      if (r <= blackThreshold && g <= blackThreshold && b <= blackThreshold) {
        black++;
      }
    }
    return black / height >= rowBlackRatio;
  }

  var top = 0;
  while (top < height - 2 && rowMostlyBlack(top)) {
    top++;
  }
  var bottom = height;
  while (bottom > top + 2 && rowMostlyBlack(bottom - 1)) {
    bottom--;
  }
  var left = 0;
  while (left < width - 2 && colMostlyBlack(left)) {
    left++;
  }
  var right = width;
  while (right > left + 2 && colMostlyBlack(right - 1)) {
    right--;
  }

  if (right - left < 4 || bottom - top < 4) return null;

  return ThumbnailContentBounds(
    imageWidth: width,
    imageHeight: height,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
  );
}

Future<ThumbnailContentBounds?> analyzeUiImageLetterbox(ui.Image image) async {
  final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (bd == null) return null;
  return analyzeLetterboxRgba(
    rgba: bd,
    width: image.width,
    height: image.height,
  );
}

void debugLogThumbnailAspect({
  required String pathType,
  required int? width,
  required int? height,
  required double? aspect,
  required String mode,
  bool? letterboxed,
}) {
  assert(() {
    if (kDebugMode) {
      debugPrint(
        "thumbnail aspect: pathType=$pathType "
        "width=${width ?? "-"} height=${height ?? "-"} "
        "aspect=${aspect?.toStringAsFixed(3) ?? "-"} "
        "mode=$mode letterboxed=${letterboxed ?? "-"}",
      );
    }
    return true;
  }());
}
