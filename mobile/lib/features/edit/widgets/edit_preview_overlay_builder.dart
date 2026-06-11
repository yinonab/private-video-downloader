import "package:flutter/material.dart";

import "../../../core/edit/edit_preview_state.dart";
import "../../../l10n/app_localizations.dart";
import "edit_captions_preview_overlay.dart";

/// Builds passive caption overlay widgets from [CaptionPreviewState].
Widget? buildEditCaptionPreviewOverlay({
  required AppLocalizations l10n,
  required CaptionPreviewState? state,
}) {
  if (state == null || !state.showOnVideoPreview) return null;

  final s = state.style;
  return EditCaptionsPreviewOverlay(
    l10n: l10n,
    showPreviewLabel: false,
    allowSampleFallback: state.allowSampleFallback,
    stylePreset: s.style,
    fontSize: s.fontSize,
    fontFamily: s.fontFamily,
    position: s.position,
    color: s.color,
    wordHighlight: s.wordHighlight,
    normalTextColor: s.normalTextColor,
    activeTextColor: s.activeTextColor,
    boxColor: s.boxColor,
    boxShape: s.boxShape,
    outlineEnabled: s.outlineEnabled,
    outlineColor: s.outlineColor,
    outlineWidth: s.outlineWidth,
    offsetXAss: s.offsetX,
    offsetYAss: s.offsetY,
    displayText: state.activeText,
    highlightWordIndex: state.activeWordIndex,
  );
}
