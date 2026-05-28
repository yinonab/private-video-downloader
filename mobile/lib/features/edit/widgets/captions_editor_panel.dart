import "package:flutter/material.dart";

import "../../../core/edit/caption_draft_timing.dart";
import "../../../core/theme/linkclip_palette.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

/// Quick Edit — captions auto burn-in + styling + **V2.2** offsets + **V2.3** presets (UX only).
class CaptionsEditorPanel extends StatelessWidget {
  const CaptionsEditorPanel({
    super.key,
    required this.autoCaptionsEnabled,
    required this.stylePreset,
    required this.fontSize,
    required this.position,
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.onAutoCaptionsChanged,
    required this.onStyleChanged,
    required this.onFontSizeChanged,
    required this.onPositionChanged,
    required this.onColorChanged,
    required this.onOffsetReset,
    required this.onOffsetNudgeAss,
    required this.effectiveCaptionPreset,
    required this.onCaptionBuiltInPresetSelected,
    required this.onGenerateCaptionsDraft,
    required this.onRegenerateCaptionsDraftRequested,
    this.captionDraftSegments,
    required this.onCaptionDraftSegmentUpdated,
    required this.onClearCaptionDraftSegmentText,
    required this.isCaptionDraftGenerating,
    required this.showCaptionDraftTimingStaleHint,
    required this.videoDurationSec,
  });

  final bool autoCaptionsEnabled;
  final QuickEditCaptionsStylePreset stylePreset;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;
  final int offsetX;
  final int offsetY;

  /// Inferred from current size/position/color/style/offsets ([QuickEditCaptionPreset.custom] if no match).
  final QuickEditCaptionPreset effectiveCaptionPreset;

  /// User picked a named preset (**not** [QuickEditCaptionPreset.custom]).
  final ValueChanged<QuickEditCaptionPreset> onCaptionBuiltInPresetSelected;

  /// V2.4A captions draft (`POST /edits/captions/draft`).
  final VoidCallback onGenerateCaptionsDraft;
  /// When a draft is already loaded; parent shows confirm then re-requests draft API.
  final VoidCallback onRegenerateCaptionsDraftRequested;
  final List<CaptionDraftSegment>? captionDraftSegments;
  final void Function(
    String segmentId, {
    required String text,
    required double startSec,
    required double endSec,
  }) onCaptionDraftSegmentUpdated;
  final void Function(String segmentId) onClearCaptionDraftSegmentText;
  final bool isCaptionDraftGenerating;
  /// After trim/speed/source identity changed post-draft.
  final bool showCaptionDraftTimingStaleHint;
  final double videoDurationSec;

  final ValueChanged<bool> onAutoCaptionsChanged;
  final ValueChanged<QuickEditCaptionsStylePreset> onStyleChanged;
  final ValueChanged<QuickEditCaptionFontSize> onFontSizeChanged;
  final ValueChanged<QuickEditCaptionPosition> onPositionChanged;
  final ValueChanged<QuickEditCaptionColor> onColorChanged;
  final VoidCallback onOffsetReset;

  /// Nudge offsets in ASS PlayRes pixels (typically ± [kQuickEditCaptionsOffsetFineStep]). Screen-absolute axes (not mirrored in RTL).
  final void Function(int dxAss, int dyAss) onOffsetNudgeAss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = context.lcPalette.tiktokAccent;
    final l10n = AppLocalizations.of(context);

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.editCaptionsSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.editCaptionsSectionSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.42 : 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              title: Text(
                l10n.editCaptionsAutoToggle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Theme(
                data: theme.copyWith(
                  switchTheme: SwitchThemeData(
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.onPrimary;
                      }
                      return scheme.outline;
                    }),
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.primary.withValues(alpha: 0.42);
                      }
                      return scheme.surfaceContainerHighest;
                    }),
                  ),
                ),
                child: Switch.adaptive(
                  value: autoCaptionsEnabled,
                  onChanged: onAutoCaptionsChanged,
                ),
              ),
            ),
          ),
          if (autoCaptionsEnabled) ...[
            const SizedBox(height: 16),
            Text(
              l10n.editCaptionsDraftTextSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.editCaptionsDraftReviewHelper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.editCaptionsDraftLongVideoHelper,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                height: 1.35,
              ),
            ),
            if (showCaptionDraftTimingStaleHint) ...[
              const SizedBox(height: 10),
              Text(
                l10n.editCaptionsDraftStaleHelper,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (captionDraftSegments == null && !isCaptionDraftGenerating)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: onGenerateCaptionsDraft,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface.withValues(alpha: 0.9),
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.42)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.editCaptionsDraftGenerateButton),
                ),
              ),
            if (captionDraftSegments != null &&
                captionDraftSegments!.isNotEmpty &&
                !isCaptionDraftGenerating)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: onRegenerateCaptionsDraftRequested,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface.withValues(alpha: 0.9),
                    side: BorderSide(color: scheme.outline.withValues(alpha: 0.42)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l10n.editCaptionsDraftRegenerateButton),
                ),
              ),
            if (isCaptionDraftGenerating)
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.editCaptionsDraftGenerating,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            if (captionDraftSegments != null && captionDraftSegments!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: captionDraftSegments!.length,
                itemBuilder: (context, i) {
                  final seg = captionDraftSegments![i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CaptionDraftSegmentRow(
                      segment: seg,
                      segmentIndex: i,
                      allSegments: captionDraftSegments!,
                      videoDurationSec: videoDurationSec,
                      editSemanticsLabel: l10n.editCaptionsDraftEditTitle,
                      clearSemanticsLabel: l10n.editCaptionsDraftClearSegment,
                      adjustedLabel: l10n.editCaptionsDraftTimingAdjusted,
                      onSave: (text, startSec, endSec) =>
                          onCaptionDraftSegmentUpdated(
                        seg.id,
                        text: text,
                        startSec: startSec,
                        endSec: endSec,
                      ),
                      onClear: () => onClearCaptionDraftSegmentText(seg.id),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 18),
            _CaptionsPresetSection(
              accent: accent,
              theme: theme,
              l10n: l10n,
              effectivePreset: effectiveCaptionPreset,
              onBuiltInSelected: onCaptionBuiltInPresetSelected,
            ),
            const SizedBox(height: 14),
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsTextSizeLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CaptionChip(
                    label: l10n.editCaptionsSizeExtraSmall,
                    selected:
                        fontSize == QuickEditCaptionFontSize.extraSmall,
                    accent: accent,
                    onTap: () => onFontSizeChanged(
                      QuickEditCaptionFontSize.extraSmall,
                    ),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsSizeSmall,
                    selected: fontSize == QuickEditCaptionFontSize.small,
                    accent: accent,
                    onTap: () => onFontSizeChanged(QuickEditCaptionFontSize.small),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsSizeMedium,
                    selected: fontSize == QuickEditCaptionFontSize.medium,
                    accent: accent,
                    onTap: () => onFontSizeChanged(QuickEditCaptionFontSize.medium),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsSizeLarge,
                    selected: fontSize == QuickEditCaptionFontSize.large,
                    accent: accent,
                    onTap: () => onFontSizeChanged(QuickEditCaptionFontSize.large),
                  ),
                ],
              ),
            ),
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsPositionLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CaptionChip(
                    label: l10n.editCaptionsPositionTop,
                    selected: position == QuickEditCaptionPosition.top,
                    accent: accent,
                    onTap: () => onPositionChanged(QuickEditCaptionPosition.top),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsPositionBottom,
                    selected: position == QuickEditCaptionPosition.bottom,
                    accent: accent,
                    onTap: () => onPositionChanged(QuickEditCaptionPosition.bottom),
                  ),
                ],
              ),
            ),
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsColorLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CaptionChip(
                    label: l10n.editCaptionsColorWhite,
                    selected: color == QuickEditCaptionColor.white,
                    accent: accent,
                    onTap: () => onColorChanged(QuickEditCaptionColor.white),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsColorYellow,
                    selected: color == QuickEditCaptionColor.yellow,
                    accent: accent,
                    onTap: () => onColorChanged(QuickEditCaptionColor.yellow),
                  ),
                ],
              ),
            ),
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsStyleLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CaptionChip(
                    label: l10n.editCaptionsStyleClean,
                    selected: stylePreset == QuickEditCaptionsStylePreset.clean,
                    accent: accent,
                    onTap: () => onStyleChanged(QuickEditCaptionsStylePreset.clean),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsStyleBold,
                    selected: stylePreset == QuickEditCaptionsStylePreset.bold,
                    accent: accent,
                    onTap: () => onStyleChanged(QuickEditCaptionsStylePreset.bold),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsStyleDarkBox,
                    selected:
                        stylePreset == QuickEditCaptionsStylePreset.darkBox,
                    accent: accent,
                    onTap: () =>
                        onStyleChanged(QuickEditCaptionsStylePreset.darkBox),
                  ),
                ],
              ),
            ),
            _CaptionsFineTuneSection(
              accent: accent,
              scheme: scheme,
              theme: theme,
              l10n: l10n,
              offsetX: offsetX,
              offsetY: offsetY,
              onReset: onOffsetReset,
              onNudge: onOffsetNudgeAss,
            ),
          ],
          const SizedBox(height: 14),
          Text(
            l10n.editCaptionsBurnInHelper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
              height: 1.38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            autoCaptionsEnabled
                ? l10n.editCaptionsSpeechDenseHint
                : l10n.editCaptionsMayTakeLongerNote,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

String _captionRangeClockLabel(double startSec, double endSec) =>
    captionDraftPreciseRangeLabel(startSec, endSec);

Future<void> _showCaptionDraftSegmentEditSheet(
  BuildContext context, {
  required CaptionDraftSegment segment,
  required int segmentIndex,
  required List<CaptionDraftSegment> allSegments,
  required double? videoDurationSec,
  required void Function(String text, double startSec, double endSec) onSave,
}) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final controller = TextEditingController(text: segment.text);
  final focusNode = FocusNode();
  var startSec = segment.startSec;
  var endSec = segment.endSec;

  CaptionDraftTimingBounds currentBounds() => boundsForDraftTimingEdit(
        segmentIndex: segmentIndex,
        segments: allSegments,
        startSec: startSec,
        endSec: endSec,
        videoDurationSec: videoDurationSec,
      );

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final inset = MediaQuery.viewInsetsOf(sheetCtx).bottom;

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final rangeLabel = _captionRangeClockLabel(startSec, endSec);
            final bounds = currentBounds();

            void nudgeStart(double delta) {
              setSheet(() {
                startSec = nudgeCaptionDraftStartSec(
                  startSec: startSec,
                  endSec: endSec,
                  deltaSec: delta,
                  bounds: bounds,
                );
              });
            }

            void nudgeEnd(double delta) {
              setSheet(() {
                endSec = nudgeCaptionDraftEndSec(
                  startSec: startSec,
                  endSec: endSec,
                  deltaSec: delta,
                  bounds: bounds,
                );
              });
            }

            void resetTiming() {
              setSheet(() {
                startSec = roundCaptionDraftTimingSec(segment.originalStartSec);
                endSec = roundCaptionDraftTimingSec(segment.originalEndSec);
                final resetBounds = boundsForDraftTimingEdit(
                  segmentIndex: segmentIndex,
                  segments: allSegments,
                  startSec: startSec,
                  endSec: endSec,
                  videoDurationSec: videoDurationSec,
                );
                startSec = clampCaptionDraftStartSec(
                  startSec: startSec,
                  endSec: endSec,
                  bounds: resetBounds,
                );
                endSec = clampCaptionDraftEndSec(
                  startSec: startSec,
                  endSec: endSec,
                  bounds: resetBounds,
                );
              });
            }

            return AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: inset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    18 + MediaQuery.paddingOf(sheetCtx).bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.editCaptionsDraftEditTitle,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: true,
                          minLines: 3,
                          maxLines: 8,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style:
                              theme.textTheme.bodyLarge?.copyWith(height: 1.42),
                          onTapOutside: (_) =>
                              FocusScope.of(sheetCtx).unfocus(),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: scheme.surface.withValues(alpha: 0.92),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => controller.clear(),
                            child: Text(l10n.editCaptionsDraftEditClearText),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.editCaptionsDraftTimingSectionTitle,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            rangeLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.88),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _CaptionDraftTimingControlRow(
                          label: l10n.editTrimStart,
                          minusTooltip: l10n.editCaptionsDraftTimingEarlier,
                          plusTooltip: l10n.editCaptionsDraftTimingLater,
                          onMinus: () => nudgeStart(-kCaptionDraftTimingStepSec),
                          onPlus: () => nudgeStart(kCaptionDraftTimingStepSec),
                        ),
                        const SizedBox(height: 8),
                        _CaptionDraftTimingControlRow(
                          label: l10n.editTrimEnd,
                          minusTooltip: l10n.editCaptionsDraftTimingEarlier,
                          plusTooltip: l10n.editCaptionsDraftTimingLater,
                          onMinus: () => nudgeEnd(-kCaptionDraftTimingStepSec),
                          onPlus: () => nudgeEnd(kCaptionDraftTimingStepSec),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: resetTiming,
                            child: Text(l10n.editCaptionsDraftTimingReset),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  FocusManager.instance.primaryFocus
                                      ?.unfocus();
                                  Navigator.pop(sheetCtx);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(l10n.homeCancel),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  onSave(controller.text, startSec, endSec);
                                  FocusManager.instance.primaryFocus
                                      ?.unfocus();
                                  Navigator.pop(sheetCtx);
                                },
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(l10n.editSave),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    focusNode.dispose();
    controller.dispose();
  }
}

class _CaptionDraftTimingControlRow extends StatelessWidget {
  const _CaptionDraftTimingControlRow({
    required this.label,
    required this.minusTooltip,
    required this.plusTooltip,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String minusTooltip;
  final String plusTooltip;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: minusTooltip,
                  child: OutlinedButton(
                    onPressed: onMinus,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '−0.1s',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: plusTooltip,
                  child: OutlinedButton(
                    onPressed: onPlus,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '+0.1s',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaptionDraftSegmentRow extends StatelessWidget {
  const _CaptionDraftSegmentRow({
    required this.segment,
    required this.segmentIndex,
    required this.allSegments,
    required this.videoDurationSec,
    required this.editSemanticsLabel,
    required this.clearSemanticsLabel,
    required this.adjustedLabel,
    required this.onSave,
    required this.onClear,
  });

  final CaptionDraftSegment segment;
  final int segmentIndex;
  final List<CaptionDraftSegment> allSegments;
  final double videoDurationSec;
  final String editSemanticsLabel;
  final String clearSemanticsLabel;
  final String adjustedLabel;
  final void Function(String text, double startSec, double endSec) onSave;
  final VoidCallback onClear;

  Future<void> _openEditSheet(BuildContext context) {
    return _showCaptionDraftSegmentEditSheet(
      context,
      segment: segment,
      segmentIndex: segmentIndex,
      allSegments: allSegments,
      videoDurationSec: videoDurationSec > 0 ? videoDurationSec : null,
      onSave: onSave,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final preview = segment.text.trim();
    final hasText = preview.isNotEmpty;
    final timeRangeLabel =
        _captionRangeClockLabel(segment.startSec, segment.endSec);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.32 : 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditSheet(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2, end: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeRangeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (segment.hasTimingAdjustment) ...[
                        const SizedBox(height: 2),
                        Text(
                          adjustedLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(top: 2),
                  child: Text(
                    hasText ? segment.text : '—',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.38,
                      color: hasText
                          ? scheme.onSurface.withValues(alpha: 0.92)
                          : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: editSemanticsLabel,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                  ),
                  onPressed: () => _openEditSheet(context),
                ),
              ),
              Tooltip(
                message: clearSemanticsLabel,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  onPressed: onClear,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _captionsPresetChipLabel(AppLocalizations l10n, QuickEditCaptionPreset preset) {
  return switch (preset) {
    QuickEditCaptionPreset.minimal => l10n.editCaptionsPresetMinimal,
    QuickEditCaptionPreset.social => l10n.editCaptionsPresetSocial,
    QuickEditCaptionPreset.boldYellow => l10n.editCaptionsPresetBoldYellow,
    QuickEditCaptionPreset.darkBox => l10n.editCaptionsPresetDarkBox,
    QuickEditCaptionPreset.topClean => l10n.editCaptionsPresetTopClean,
    QuickEditCaptionPreset.custom => "",
  };
}

/// Preset chips (built‑in only); [QuickEditCaptionPreset.custom] surfaced as Manual badge beside title.
class _CaptionsPresetSection extends StatelessWidget {
  const _CaptionsPresetSection({
    required this.accent,
    required this.theme,
    required this.l10n,
    required this.effectivePreset,
    required this.onBuiltInSelected,
  });

  final Color accent;
  final ThemeData theme;
  final AppLocalizations l10n;
  final QuickEditCaptionPreset effectivePreset;
  final ValueChanged<QuickEditCaptionPreset> onBuiltInSelected;

  bool get _isManual =>
      effectivePreset == QuickEditCaptionPreset.custom;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    Widget? badge;
    if (_isManual) {
      badge = Semantics(
        label: l10n.editCaptionsPresetManualBadge,
        container: true,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
            color: scheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.38 : 0.52),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              l10n.editCaptionsPresetManualBadge,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.06,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.editCaptionsPresetLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10),
                  child: badge,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, end: 4),
            child: SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: kQuickEditCaptionBuiltInPresetsOrdered.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = kQuickEditCaptionBuiltInPresetsOrdered[i];
                  return _CaptionChip(
                    label: _captionsPresetChipLabel(l10n, p),
                    selected: effectivePreset == p,
                    accent: accent,
                    onTap: () => onBuiltInSelected(p),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arrow pad uses screen-relative up/down/left/right (consistent in RTL).
class _CaptionsFineTuneSection extends StatelessWidget {
  const _CaptionsFineTuneSection({
    required this.accent,
    required this.scheme,
    required this.theme,
    required this.l10n,
    required this.offsetX,
    required this.offsetY,
    required this.onReset,
    required this.onNudge,
  });

  final Color accent;
  final ColorScheme scheme;
  final ThemeData theme;
  final AppLocalizations l10n;
  final int offsetX;
  final int offsetY;
  final VoidCallback onReset;
  final void Function(int dxAss, int dyAss) onNudge;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;
    final mutedAccent = accent.withValues(alpha: dark ? 0.55 : 0.85);
    final step = kQuickEditCaptionsOffsetFineStep;

    Widget padBtn({required Widget icon, required VoidCallback onPressed}) {
      return Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
        shape: CircleBorder(side: BorderSide(color: mutedAccent.withValues(alpha: 0.22))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: IconTheme.merge(
              data: IconThemeData(size: 20, color: scheme.onSurface.withValues(alpha: 0.72)),
              child: icon,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(
            alpha: dark ? 0.28 : 0.42,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.editCaptionsFineTuneTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.editCaptionsOffsetCompact(offsetX, offsetY),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    padBtn(
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      onPressed: () => onNudge(0, -step),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        padBtn(
                          icon: const Icon(Icons.keyboard_arrow_left_rounded),
                          onPressed: () => onNudge(-step, 0),
                        ),
                        const SizedBox(width: 10),
                        padBtn(
                          icon: const Icon(Icons.keyboard_arrow_right_rounded),
                          onPressed: () => onNudge(step, 0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    padBtn(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () => onNudge(0, step),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                    textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.editCaptionsResetPosition),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _SpacingFn = Wrap Function();

class _CaptionsChipSection extends StatelessWidget {
  const _CaptionsChipSection({
    required this.accent,
    required this.title,
    required this.spacing,
  });

  final Color accent;
  final String title;
  final _SpacingFn spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          spacing(),
        ],
      ),
    );
  }
}

class _CaptionChip extends StatelessWidget {
  const _CaptionChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final mutedBlue = accent.withValues(alpha: dark ? 0.52 : 0.88);
    final borderColor =
        selected ? mutedBlue : scheme.outline.withValues(alpha: 0.32);
    final bg = selected
        ? accent.withValues(alpha: dark ? 0.14 : 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.38 : 0.48);

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.12,
          color: selected ? accent.withValues(alpha: dark ? 0.95 : 0.94) : scheme.onSurface.withValues(alpha: 0.88),
        ),
      ),
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.25 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              child: child,
            ),
    );
  }
}