import "package:flutter/material.dart";

import "../../../core/edit/caption_draft_timing.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

String captionDraftRangeClockLabel(double startSec, double endSec) =>
    captionDraftPreciseRangeLabel(startSec, endSec);

Future<void> showCaptionDraftSegmentEditSheet(
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
            final rangeLabel = captionDraftRangeClockLabel(startSec, endSec);
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
                      'גˆ’0.1s',
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

class CaptionDraftSegmentRow extends StatelessWidget {
  const CaptionDraftSegmentRow({
    super.key,
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
    return showCaptionDraftSegmentEditSheet(
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
        captionDraftRangeClockLabel(segment.startSec, segment.endSec);

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
                    hasText ? segment.text : 'ג€”',
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
