/// Classifies media aspect for Home list / tile thumbnails.
enum MediaAspectKind {
  portrait,
  landscape,
  square,
}

/// Helpers for aspect-aware Home media tiles (no stretching).
abstract final class MediaAspect {
  /// Width ÷ height. Null if dimensions missing/invalid.
  static double? ratioFromSize({int? width, int? height}) {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return w / h;
  }

  static MediaAspectKind kindOf(double aspect) {
    if (aspect < 0.88) return MediaAspectKind.portrait;
    if (aspect > 1.15) return MediaAspectKind.landscape;
    return MediaAspectKind.square;
  }

  /// Clamp extreme ratios so tiles stay usable in a list row.
  static double clampForTile(double aspect) => aspect.clamp(0.48, 2.0);

  /// Fit media aspect into a max box; returns (width, height).
  ///
  /// Uses the **real** aspect (clamped), not a forced portrait/landscape slot,
  /// so horizontal videos get landscape tiles and vertical get portrait tiles.
  static ({double width, double height}) tileSize({
    required double aspect,
    double maxWidth = 140,
    double maxHeight = 112,
    double minWidth = 64,
  }) {
    final a = clampForTile(aspect);
    if (a >= 1) {
      var w = maxWidth;
      var h = w / a;
      if (h > maxHeight) {
        h = maxHeight;
        w = h * a;
      }
      if (w < minWidth) {
        w = minWidth;
        h = w / a;
      }
      return (width: w, height: h);
    }
    var h = maxHeight;
    var w = h * a;
    if (w < minWidth) {
      w = minWidth;
      h = w / a;
      if (h > maxHeight) {
        h = maxHeight;
        w = h * a;
      }
    }
    if (w > maxWidth) {
      w = maxWidth;
      h = w / a;
    }
    return (width: w, height: h);
  }
}
