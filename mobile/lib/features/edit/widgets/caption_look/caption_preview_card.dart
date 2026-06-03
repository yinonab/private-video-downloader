import "package:flutter/material.dart";

import "../../../../core/models/quick_edit_models.dart";
import "../../../../l10n/app_localizations.dart";
import "../edit_captions_preview_overlay.dart";

/// Premium mini-stage preview for the caption look editor (V3.4E).
class CaptionPreviewCard extends StatelessWidget {
  const CaptionPreviewCard({
    super.key,
    required this.l10n,
    required this.snapshot,
  });

  final AppLocalizations l10n;
  final CaptionLookSnapshot snapshot;

  static const double _stageHeight = 80;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final label = l10n.editCaptionsV3PreviewLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Material(
        elevation: isDark ? 2 : 3,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0D0D0F),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outline.withValues(alpha: isDark ? 0.28 : 0.2),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A1A1E),
                  const Color(0xFF08080A),
                ],
              ),
            ),
            child: SizedBox(
              height: _stageHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: EditCaptionsPreviewOverlay(
                      l10n: l10n,
                      layout: CaptionPreviewLayout.stage,
                      stylePreset: snapshot.style,
                      fontSize: snapshot.fontSize,
                      fontFamily: snapshot.fontFamily,
                      position: snapshot.position,
                      color: snapshot.color,
                      wordHighlight: snapshot.wordHighlight,
                      normalTextColor: snapshot.normalTextColor,
                      activeTextColor: snapshot.activeTextColor,
                      boxColor: snapshot.boxColor,
                      boxShape: snapshot.boxShape,
                      offsetXAss: snapshot.offsetX,
                      offsetYAss: snapshot.offsetY,
                    ),
                  ),
                  PositionedDirectional(
                    top: 8,
                    start: 10,
                    child: _PreviewLabelChip(text: label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewLabelChip extends StatelessWidget {
  const _PreviewLabelChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
                fontSize: 10,
                letterSpacing: 0.15,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
