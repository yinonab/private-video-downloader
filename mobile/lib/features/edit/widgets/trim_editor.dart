import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/utils/trim_time_parse.dart";

/// Trim controls: metrics → tap-to-edit exact times (bottom sheet) → range arrow → slider → reset.
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
  Future<void> _openTimeSheet({required bool isStart}) async {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
    const eps = 0.05;
    final initial = isStart ? widget.startSec : widget.endSec;
    final controller =
        TextEditingController(text: formatTrimDurationUi(initial));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        String? sheetErr;

        bool validateAndApply(void Function(void Function()) setSheet) {
          final parsed = parseFlexibleTimeSeconds(controller.text);
          if (parsed == null) {
            setSheet(() => sheetErr = isStart
                ? l10n.editTrimInvalidStartTime
                : l10n.editTrimInvalidEndTime);
            return false;
          }
          final ps = parsed;
          if (ps < 0 || ps > dur) {
            setSheet(() => sheetErr = isStart
                ? l10n.editTrimInvalidStartTime
                : l10n.editTrimInvalidEndTime);
            return false;
          }
          if (isStart) {
            if (ps >= widget.endSec - eps) {
              setSheet(() => sheetErr = l10n.editTrimEndMustBeAfterStart);
              return false;
            }
            final lo = ps.clamp(0.0, dur - eps);
            final hi = widget.endSec.clamp(lo + eps, dur);
            widget.onChanged(lo, hi);
          } else {
            if (ps <= widget.startSec + eps) {
              setSheet(() => sheetErr = l10n.editTrimEndMustBeAfterStart);
              return false;
            }
            final hi = ps.clamp(widget.startSec + eps, dur);
            widget.onChanged(widget.startSec, hi);
          }
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.pop(sheetCtx);
          return true;
        }

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final inset = MediaQuery.viewInsetsOf(ctx).bottom;
            final title = isStart
                ? l10n.editTrimSheetTitleStart
                : l10n.editTrimSheetTitleEnd;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: inset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                  border:
                      Border.all(color: scheme.outline.withValues(alpha: 0.35)),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    18 + MediaQuery.paddingOf(ctx).bottom,
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
                      TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.datetime,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r"[0-9:. ]")),
                        ],
                        onSubmitted: (_) => validateAndApply(setSheet),
                        decoration: InputDecoration(
                          hintText: l10n.editTrimTimeExample,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: scheme.surface.withValues(alpha: 0.92),
                        ),
                        onChanged: (_) {
                          if (sheetErr != null) {
                            setSheet(() => sheetErr = null);
                          }
                        },
                      ),
                      if (sheetErr != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          sheetErr!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.error),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                              onPressed: () => validateAndApply(setSheet),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
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

    controller.dispose();
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
    final selected = (hi - lo).clamp(eps, dur);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.editTrimSectionTitle,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onReset,
              icon:
                  Icon(Icons.refresh_rounded, color: scheme.primary, size: 20),
              label: Text(l10n.editTrimReset),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "${formatTrimDurationUi(widget.playbackSec.clamp(0, dur))} / ${formatTrimDurationUi(dur)}",
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
        ),
        const SizedBox(height: 14),
        _MetricRow(
            label: l10n.editTrimVideoDuration,
            value: formatTrimDurationUi(dur)),
        _MetricRow(
            label: l10n.editTrimSelectedClip,
            value: formatTrimDurationUi(selected)),
        _MetricRow(
            label: l10n.editTrimRemoved, value: formatTrimDurationUi(removed)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricRow(
                label: l10n.editTrimStart,
                value: formatTrimDurationUi(lo),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricRow(
                label: l10n.editTrimEnd,
                value: formatTrimDurationUi(hi),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.editTrimTapToEditHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _TrimTimeTapTile(
          label: l10n.editTrimFieldStart,
          value: formatTrimDurationUi(lo),
          onTap: () => _openTimeSheet(isStart: true),
        ),
        const SizedBox(height: 10),
        _TrimTimeTapTile(
          label: l10n.editTrimFieldEnd,
          value: formatTrimDurationUi(hi),
          onTap: () => _openTimeSheet(isStart: false),
        ),
        const SizedBox(height: 16),
        _RangeArrowRow(
            startLabel: formatTrimDurationUi(lo),
            endLabel: formatTrimDurationUi(hi)),
        const SizedBox(height: 18),
        RangeSlider(
          values: RangeValues(lo, hi),
          min: 0,
          max: dur,
          labels:
              RangeLabels(formatTrimDurationUi(lo), formatTrimDurationUi(hi)),
          onChanged: (rv) {
            widget.onChanged(rv.start, rv.end);
          },
        ),
      ],
    );
  }
}

class _TrimTimeTapTile extends StatelessWidget {
  const _TrimTimeTapTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined,
                  color: scheme.primary.withValues(alpha: 0.85)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeArrowRow extends StatelessWidget {
  const _RangeArrowRow({
    required this.startLabel,
    required this.endLabel,
  });

  final String startLabel;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final chip = BoxDecoration(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
    );
    // Ambient text direction: RTL lays out Row right-to-start → start chip on the right, end on the left.
    // Arrow points along the trim timeline (toward end): right in LTR, left in RTL.
    final arrowIcon =
        rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: chip,
            child: Text(
              startLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(arrowIcon, color: scheme.primary, size: 28),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: chip,
            child: Text(
              endLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
