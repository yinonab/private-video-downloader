import "dart:math" as math;

import "package:flutter/material.dart";

import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

/// Approximate captions on the editor video frame (upright; not rotated with preview).
/// Rough ASS PlayRes parity via [kCaptionAssPlayResX] / [kCaptionAssPlayResY].
class EditCaptionsPreviewOverlay extends StatelessWidget {
  const EditCaptionsPreviewOverlay({
    super.key,
    required this.l10n,
    required this.stylePreset,
    required this.fontSize,
    required this.position,
    required this.color,
    required this.offsetXAss,
    required this.offsetYAss,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionsStylePreset stylePreset;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;
  final int offsetXAss;
  final int offsetYAss;

  @override
  Widget build(BuildContext context) {
    final textColor =
        color == QuickEditCaptionColor.yellow ? const Color(0xFFFFD966) : Colors.white;
    final fz = switch (fontSize) {
      QuickEditCaptionFontSize.extraSmall => 10.4,
      QuickEditCaptionFontSize.small => 11.8,
      QuickEditCaptionFontSize.medium => 13.9,
      QuickEditCaptionFontSize.large => 16.4,
    };
    final fw = switch (stylePreset) {
      QuickEditCaptionsStylePreset.bold => FontWeight.w700,
      _ => FontWeight.w500,
    };

    TextStyle cleanBoldBase() => TextStyle(
          color: textColor,
          fontSize: fz,
          fontWeight: fw,
          height: 1.2,
        );

    late final Widget body;
    switch (stylePreset) {
      case QuickEditCaptionsStylePreset.darkBox:
        body = DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              l10n.editCaptionsSampleLabel,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.fade,
              style: cleanBoldBase(),
            ),
          ),
        );
        break;
      case QuickEditCaptionsStylePreset.bold:
        body = Text(
          l10n.editCaptionsSampleLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.fade,
          style: cleanBoldBase().copyWith(
            shadows: [
              Shadow(blurRadius: 14, color: Colors.black.withValues(alpha: 0.92)),
              Shadow(
                blurRadius: 0,
                offset: const Offset(0, 1.5),
                color: Colors.black.withValues(alpha: 0.92),
              ),
            ],
          ),
        );
        break;
      case QuickEditCaptionsStylePreset.clean:
        body = Text(
          l10n.editCaptionsSampleLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.fade,
          style: cleanBoldBase().copyWith(
            shadows: [
              Shadow(blurRadius: 11, color: Colors.black.withValues(alpha: 0.88)),
            ],
          ),
        );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = math.max(c.maxWidth, 1.0);
        final h = math.max(c.maxHeight, 1.0);
        final sx = w / kCaptionAssPlayResX;
        final sy = h / kCaptionAssPlayResY;
        final dx = offsetXAss * sx;
        final dy = offsetYAss * sy;
        final bottom = position == QuickEditCaptionPosition.bottom;
        final baseY = bottom ? (-h * 0.086) : (h * 0.086);
        final fx = dx.clamp(-w * 0.42, w * 0.42).toDouble();
        final fy = (baseY + dy).clamp(
          bottom ? -h * 0.42 : -h * 0.06,
          bottom ? h * 0.06 : h * 0.42,
        ).toDouble();

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Align(
              alignment: bottom ? Alignment.bottomCenter : Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(fx, fy),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: body,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
