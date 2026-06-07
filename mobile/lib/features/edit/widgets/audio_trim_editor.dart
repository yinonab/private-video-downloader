import "dart:math" as math;

import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";
import "repeat_nudge_icon_button.dart";
import "audio_preview_timeline.dart";
import "trim_mm_ss_input.dart";

enum _TrimThumb { start, end }

(double, double) _silentApplyTrimSeconds({
  required bool editingStart,
  required double requestedSecTotal,
  required double dur,
  required double currentLo,
  required double currentHi,
  double eps = kAudioEditMinTrimSpanSec,
}) {
  double lo = editingStart ? requestedSecTotal : currentLo;
  double hi = editingStart ? currentHi : requestedSecTotal;

  lo = lo.clamp(0.0, dur);
  hi = hi.clamp(0.0, dur);

  if (lo > hi + 1e-12) {
    if (editingStart) {
      hi = math.min(lo + eps, dur);
    } else {
      lo = math.max(hi - eps, 0.0);
    }
    lo = lo.clamp(0.0, dur);
    hi = hi.clamp(0.0, dur);
  }

  if (hi - lo < eps - 1e-11) {
    if (editingStart) {
      hi = math.min(lo + eps, dur);
      if (hi - lo < eps - 1e-11 && dur >= eps - 1e-11) {
        hi = dur;
        lo = math.max(0.0, hi - eps);
      }
    } else {
      lo = math.max(0.0, hi - eps);
      if (hi - lo < eps - 1e-11 && dur >= eps - 1e-11) {
        lo = 0;
        hi = math.min(lo + eps, dur);
      }
    }
  }

  if (hi - lo < eps - 1e-11 && dur >= eps - 1e-11) {
    hi = dur;
    lo = math.max(0.0, hi - eps);
  }

  lo = lo.clamp(0.0, dur);
  hi = hi.clamp(0.0, dur);
  return (lo, hi);
}

/// Audio trim precision controls: Start/End cards, +/- nudge, MM:SS entry.
class AudioTrimEditor extends StatefulWidget {
  const AudioTrimEditor({
    super.key,
    required this.durationSec,
    required this.startSec,
    required this.endSec,
    required this.onChanged,
    required this.onReset,
    this.startHandleActive = false,
    this.endHandleActive = false,
    this.onTrimHandleActive,
  });

  final double durationSec;
  final double startSec;
  final double endSec;
  final void Function(double startSec, double endSec) onChanged;
  final VoidCallback onReset;
  final bool startHandleActive;
  final bool endHandleActive;
  final ValueChanged<AudioTimelineTrimHandle?>? onTrimHandleActive;

  @override
  State<AudioTrimEditor> createState() => _AudioTrimEditorState();
}

class _AudioTrimEditorState extends State<AudioTrimEditor> {
  _TrimThumb? _sheetEditingThumb;

  RangeValues _clampRange(double lo, double hi) {
    final pair = clampAudioEditTrimRange(
      startSec: lo,
      endSec: hi,
      durationSec: widget.durationSec,
    );
    return RangeValues(pair.$1, pair.$2);
  }

  void _nudgeStart(double delta) {
    final rv = _clampRange(widget.startSec + delta, widget.endSec);
    widget.onChanged(rv.start, rv.end);
  }

  void _nudgeEnd(double delta) {
    final rv = _clampRange(widget.startSec, widget.endSec + delta);
    widget.onChanged(rv.start, rv.end);
  }

  Future<void> _openTimeSheet({required _TrimThumb editedThumb}) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;

    final controller = TextEditingController();
    final focusNode = FocusNode();

    setState(() => _sheetEditingThumb = editedThumb);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });

    void applyAndClose(BuildContext sheetCtx) {
      final digits = trimTimeDigitsOnly(controller.text);
      if (digits.isEmpty) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pop(sheetCtx);
        return;
      }
      final requested = secondsFromMmSsDigits(digits).clamp(0.0, dur);
      final currentLo = widget.startSec.clamp(0.0, dur);
      final currentHi = widget.endSec.clamp(0.0, dur);

      final pair = _silentApplyTrimSeconds(
        editingStart: editedThumb == _TrimThumb.start,
        requestedSecTotal: requested,
        dur: dur,
        currentLo: currentLo,
        currentHi: currentHi,
      );

      widget.onChanged(pair.$1, pair.$2);
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pop(sheetCtx);
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) {
          final inset = MediaQuery.viewInsetsOf(sheetCtx).bottom;
          final title = editedThumb == _TrimThumb.start
              ? l10n.editTrimSheetTitleStart
              : l10n.editTrimSheetTitleEnd;

          return StatefulBuilder(
            builder: (ctx, setSheet) {
              final rawDigits = trimTimeDigitsOnly(controller.text);
              final previewFormatted =
                  rawDigits.isEmpty ? null : formatMmSsDisplayFromDigits(rawDigits);

              return AnimatedPadding(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: inset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      18 + MediaQuery.paddingOf(sheetCtx).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.editTrimTapToEditHint,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            autofocus: true,
                            keyboardType: const TextInputType.numberWithOptions(
                              signed: false,
                              decimal: false,
                            ),
                            textInputAction: TextInputAction.done,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontFeatures: [const FontFeature.tabularFigures()],
                            ),
                            inputFormatters: trimRawDigitsOnlyFormatters(),
                            onSubmitted: (_) => applyAndClose(sheetCtx),
                            onTapOutside: (_) => FocusScope.of(sheetCtx).unfocus(),
                            onChanged: (_) => setSheet(() {}),
                            decoration: InputDecoration(
                              hintText: l10n.editTrimTimeFieldHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              filled: true,
                              fillColor: scheme.surface.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                        if (previewFormatted != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.center,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                l10n.editTrimPreview(previewFormatted),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  Navigator.pop(sheetCtx);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                                onPressed: () => applyAndClose(sheetCtx),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(l10n.editTrimSheetApply),
                              ),
                            ),
                          ],
                        ),
                      ],
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
      if (mounted) {
        setState(() => _sheetEditingThumb = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rv = _clampRange(widget.startSec, widget.endSec);
    final startStr = formatAudioEditTimeSec(rv.start);
    final endStr = formatAudioEditTimeSec(rv.end);
    final rangeLine = l10n.audioEditTrimRange("$startStr–$endStr");
    final startFocused =
        widget.startHandleActive || _sheetEditingThumb == _TrimThumb.start;
    final endFocused =
        widget.endHandleActive || _sheetEditingThumb == _TrimThumb.end;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.audioEditTrimTitle,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: widget.onReset,
              child: Text(l10n.audioEditResetTrim),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.center,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              rangeLine,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 12),
        AudioPreviewTimeline(
          mode: AudioTimelineMode.trim,
          l10n: l10n,
          durationSec: widget.durationSec,
          startSec: rv.start,
          endSec: rv.end,
          enabled: widget.durationSec > 0,
          onTrimChanged: widget.onChanged,
          onTrimHandleActive: widget.onTrimHandleActive,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TrimPointCard(
                label: l10n.audioEditTrimStart,
                helper: l10n.editTrimTapToEditHint,
                time: startStr,
                focused: startFocused,
                onTapTime: () => _openTimeSheet(editedThumb: _TrimThumb.start),
                onMinus: () => _nudgeStart(-kAudioEditTrimNudgeSec),
                onPlus: () => _nudgeStart(kAudioEditTrimNudgeSec),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TrimPointCard(
                label: l10n.audioEditTrimEnd,
                helper: l10n.editTrimTapToEditHint,
                time: endStr,
                focused: endFocused,
                onTapTime: () => _openTimeSheet(editedThumb: _TrimThumb.end),
                onMinus: () => _nudgeEnd(-kAudioEditTrimNudgeSec),
                onPlus: () => _nudgeEnd(kAudioEditTrimNudgeSec),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrimPointCard extends StatelessWidget {
  const _TrimPointCard({
    required this.label,
    required this.helper,
    required this.time,
    required this.focused,
    required this.onTapTime,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String helper;
  final String time;
  final bool focused;
  final VoidCallback onTapTime;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outline.withValues(alpha: 0.28),
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              helper,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapTime,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      time,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                RepeatNudgeIconButton(
                  icon: LucideIcons.minus,
                  tooltip: "-${kAudioEditTrimNudgeSec}s",
                  onStep: onMinus,
                ),
                RepeatNudgeIconButton(
                  icon: LucideIcons.plus,
                  tooltip: "+${kAudioEditTrimNudgeSec}s",
                  onStep: onPlus,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
