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
    final theme = Theme.of(context);
    final textColor = color == QuickEditCaptionColor.yellow
        ? const Color(0xFFFFD966)
        : Colors.white;
    final fz = switch (fontSize) {
      QuickEditCaptionFontSize.extraSmall => 9.6,
      QuickEditCaptionFontSize.small => 10.8,
      QuickEditCaptionFontSize.medium => 12.6,
      QuickEditCaptionFontSize.large => 14.8,
    };
    final fw = switch (stylePreset) {
      QuickEditCaptionsStylePreset.bold => FontWeight.w700,
      _ => FontWeight.w500,
    };

    TextStyle sampleStyle() => TextStyle(
          color: textColor,
          fontSize: fz,
          fontWeight: fw,
          height: 1.15,
        );

    late final Widget captionBody;
    switch (stylePreset) {
      case QuickEditCaptionsStylePreset.darkBox:
        captionBody = DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              l10n.editCaptionsSampleLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sampleStyle(),
            ),
          ),
        );
        break;
      case QuickEditCaptionsStylePreset.bold:
        captionBody = Text(
          l10n.editCaptionsSampleLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: sampleStyle().copyWith(
            shadows: [
              Shadow(
                blurRadius: 10,
                color: Colors.black.withValues(alpha: 0.9),
              ),
              Shadow(
                blurRadius: 0,
                offset: const Offset(0, 1),
                color: Colors.black.withValues(alpha: 0.88),
              ),
            ],
          ),
        );
        break;
      case QuickEditCaptionsStylePreset.clean:
        captionBody = Text(
          l10n.editCaptionsSampleLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: sampleStyle().copyWith(
            shadows: [
              Shadow(
                blurRadius: 8,
                color: Colors.black.withValues(alpha: 0.82),
              ),
            ],
          ),
        );
    }

    final previewLabel = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          l10n.editCaptionsV3PreviewLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
            fontSize: 9.5,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final w = math.max(c.maxWidth, 1.0);
        final h = math.max(c.maxHeight, 1.0);
        final sx = w / kCaptionAssPlayResX;
        final sy = h / kCaptionAssPlayResY;
        final dx = offsetXAss * sx;
        final dy = offsetYAss * sy;
        final bottom = position == QuickEditCaptionPosition.bottom;
        final baseY = bottom ? (-h * 0.068) : (h * 0.068);
        final fx = dx.clamp(-w * 0.36, w * 0.36).toDouble();
        final fy = (baseY + dy)
            .clamp(
              bottom ? -h * 0.34 : -h * 0.05,
              bottom ? h * 0.05 : h * 0.34,
            )
            .toDouble();

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Align(
              alignment:
                  bottom ? Alignment.bottomCenter : Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(fx, fy),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!bottom) ...[
                        previewLabel,
                        const SizedBox(height: 4),
                      ],
                      captionBody,
                      if (bottom) ...[
                        const SizedBox(height: 4),
                        previewLabel,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
