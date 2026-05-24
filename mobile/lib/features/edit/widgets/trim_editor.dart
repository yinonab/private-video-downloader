import "dart:math" as math;

import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/utils/trim_time_parse.dart";
import "trim_labeled_thumb_shape.dart";
import "trim_mm_ss_input.dart";

(double, double) _silentApplyTrimSeconds({
  required bool editingStart,
  required double requestedSecTotal,
  required double dur,
  required double currentLo,
  required double currentHi,
  double eps = 0.08,
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

/// Trim controls: tap-to-edit exact times → range slider → reset.
///
/// Preview playback loops within [startSec]..[endSec] on the parent player; final trim is server-side `/edits`.
class TrimEditor extends StatefulWidget {
  const TrimEditor({
    super.key,
    required this.durationSec,
    required this.startSec,
    required this.endSec,
    required this.playbackSec,
    required this.onChanged,
    required this.onReset,
  });

  final double durationSec;
  final double startSec;
  final double endSec;
  final double playbackSec;
  final void Function(double startSec, double endSec) onChanged;
  final VoidCallback onReset;

  @override
  State<TrimEditor> createState() => _TrimEditorState();
}

class _TrimEditorState extends State<TrimEditor> {
  Thumb? _sheetEditingThumb;
  Thumb? _dragHighlightThumb;

  RangeValues _lastRange = const RangeValues(0, 1);

  @override
  void initState() {
    super.initState();
    final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
    const eps = 0.08;
    final lo = widget.startSec.clamp(0.0, dur - eps);
    final hi = widget.endSec.clamp(lo + eps, dur);
    _lastRange = RangeValues(lo, hi);
  }

  @override
  void didUpdateWidget(covariant TrimEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final durChanged = widget.durationSec != oldWidget.durationSec;
    final rangeChanged =
        widget.startSec != oldWidget.startSec || widget.endSec != oldWidget.endSec;
    if (durChanged || rangeChanged) {
      final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
      const eps = 0.08;
      final lo = widget.startSec.clamp(0.0, dur - eps);
      final hi = widget.endSec.clamp(lo + eps, dur);
      _lastRange = RangeValues(lo, hi);
    }
  }

  Thumb? get _effectiveHighlightThumb =>
      _sheetEditingThumb ?? _dragHighlightThumb;

  void _inferDragThumb(RangeValues rv) {
    final ds = (rv.start - _lastRange.start).abs();
    final de = (rv.end - _lastRange.end).abs();
    if (ds <= 1e-10 && de <= 1e-10) {
      return;
    }
    Thumb? guess;
    if (ds >= de && ds > 1e-10) {
      guess = Thumb.start;
    } else if (de > ds) {
      guess = Thumb.end;
    }
    if (guess == null) return;
    if (_dragHighlightThumb != guess) {
      setState(() => _dragHighlightThumb = guess);
    }
  }

  void _finishRangeGesture() {
    if (_dragHighlightThumb != null) {
      setState(() => _dragHighlightThumb = null);
    }
  }

  void _rangeChanged(RangeValues rv) {
    _inferDragThumb(rv);
    widget.onChanged(rv.start, rv.end);
    _lastRange = rv;
  }

  Future<void> _openTimeSheet({required Thumb editedThumb}) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
    const eps = 0.08;

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
      final requested =
          secondsFromMmSsDigits(digits).clamp(0.0, dur);
      final currentLo = widget.startSec.clamp(0.0, dur);
      final currentHi = widget.endSec.clamp(0.0, dur);

      final pair = _silentApplyTrimSeconds(
        editingStart: editedThumb == Thumb.start,
        requestedSecTotal: requested,
        dur: dur,
        currentLo: currentLo,
        currentHi: currentHi,
        eps: eps,
      );

      widget.onChanged(pair.$1, pair.$2);
      _lastRange = RangeValues(pair.$1, pair.$2);
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
          final title = editedThumb == Thumb.start
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
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
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    signed: false, decimal: false),
                            textInputAction: TextInputAction.done,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontFeatures: [
                              const FontFeature.tabularFigures(),
                            ]),
                            inputFormatters: trimRawDigitsOnlyFormatters(),
                            onSubmitted: (_) => applyAndClose(sheetCtx),
                            onTapOutside: (_) =>
                                FocusScope.of(sheetCtx).unfocus(),
                            onChanged: (_) => setSheet(() {}),
                            decoration: InputDecoration(
                              hintText: l10n.editTrimTimeFieldHint,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              filled: true,
                              fillColor:
                                  scheme.surface.withValues(alpha: 0.92),
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
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.82),
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
                                onPressed: () =>
                                    applyAndClose(sheetCtx),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
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
    final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
    const eps = 0.08;
    final lo = widget.startSec.clamp(0.0, dur - eps);
    final hi = widget.endSec.clamp(lo + eps, dur);
    final removed = (dur - (hi - lo)).clamp(0.0, dur);
    final startStr = formatTrimDurationUi(lo);
    final endStr = formatTrimDurationUi(hi);

    final startTileFocused =
        _sheetEditingThumb == Thumb.start || _dragHighlightThumb == Thumb.start;
    final endTileFocused =
        _sheetEditingThumb == Thumb.end || _dragHighlightThumb == Thumb.end;

    final thumbHighlight = _effectiveHighlightThumb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.editTrimSectionTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: widget.onReset,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.editTrimReset),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.center,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              l10n.editTrimSelectedRange(startStr, endStr),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        if (removed > 0.05) ...[
          const SizedBox(height: 6),
          Text(
            l10n.editTrimRemovedLine(formatTrimDurationUi(removed)),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TrimTimeTapTile(
                focused: startTileFocused,
                label: l10n.editTrimFieldStart,
                value: startStr,
                onTap: () =>
                    _openTimeSheet(editedThumb: Thumb.start),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TrimTimeTapTile(
                focused: endTileFocused,
                label: l10n.editTrimFieldEnd,
                value: endStr,
                onTap: () => _openTimeSheet(editedThumb: Thumb.end),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Theme(
          data: theme.copyWith(
            sliderTheme: theme.sliderTheme.copyWith(
              rangeThumbShape: TrimLabeledRangeThumbShape(
                colorScheme: scheme,
                highlightedThumb: thumbHighlight,
              ),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: scheme.primary.withValues(alpha: 0.5),
              inactiveTrackColor: scheme.outline.withValues(alpha: 0.22),
              trackHeight: 4,
            ),
          ),
          child: RangeSlider(
            values: RangeValues(lo, hi),
            min: 0,
            max: dur,
            labels: RangeLabels(startStr, endStr),
            onChanged: _rangeChanged,
            onChangeEnd: (_) => _finishRangeGesture(),
          ),
        ),
      ],
    );
  }
}

class _TrimTimeTapTile extends StatelessWidget {
  const _TrimTimeTapTile({
    required this.focused,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final bool focused;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final borderSide = BorderSide(
      width: focused ? 1.5 : 1,
      color: focused
          ? scheme.primary.withValues(alpha: 0.55)
          : scheme.outline.withValues(alpha: 0.28),
    );

    return Material(
      color:
          scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: borderSide,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(
                          alpha: focused ? 1.0 : 0.95,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
