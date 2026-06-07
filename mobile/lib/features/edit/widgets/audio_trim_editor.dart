import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";
import "repeat_nudge_icon_button.dart";
import "trim_labeled_thumb_shape.dart";

enum _TrimThumb { start, end }

/// Audio trim UI: start/end cards, range bar, slider handles, long-press nudge.
class AudioTrimEditor extends StatefulWidget {
  const AudioTrimEditor({
    super.key,
    required this.durationSec,
    required this.startSec,
    required this.endSec,
    required this.onChanged,
    required this.onReset,
  });

  final double durationSec;
  final double startSec;
  final double endSec;
  final void Function(double startSec, double endSec) onChanged;
  final VoidCallback onReset;

  @override
  State<AudioTrimEditor> createState() => _AudioTrimEditorState();
}

class _AudioTrimEditorState extends State<AudioTrimEditor> {
  _TrimThumb? _dragHighlight;

  RangeValues _clampRange(double lo, double hi) {
    final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
    const minSpan = kAudioEditMinTrimSpanSec;
    var start = lo.clamp(0.0, dur - minSpan);
    var end = hi.clamp(start + minSpan, dur);
    if (end - start < minSpan) {
      end = (start + minSpan).clamp(minSpan, dur);
      start = (end - minSpan).clamp(0.0, dur - minSpan);
    }
    return RangeValues(start, end);
  }

  void _nudgeStart(double delta) {
    final rv = _clampRange(widget.startSec + delta, widget.endSec);
    widget.onChanged(rv.start, rv.end);
  }

  void _nudgeEnd(double delta) {
    final rv = _clampRange(widget.startSec, widget.endSec + delta);
    widget.onChanged(rv.start, rv.end);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dur = widget.durationSec <= 0 ? 1.0 : widget.durationSec;
    final rv = _clampRange(widget.startSec, widget.endSec);
    final startStr = formatAudioEditTimeSec(rv.start);
    final endStr = formatAudioEditTimeSec(rv.end);
    final rangeLine = l10n.audioEditTrimRange("$startStr–$endStr");

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
        Text(
          rangeLine,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        _AudioTrimTimelineBar(
          durationSec: dur,
          startSec: rv.start,
          endSec: rv.end,
        ),
        const SizedBox(height: 14),
        Theme(
          data: theme.copyWith(
            sliderTheme: theme.sliderTheme.copyWith(
              rangeThumbShape: TrimLabeledRangeThumbShape(
                colorScheme: scheme,
                highlightedThumb: _dragHighlight == _TrimThumb.start
                    ? Thumb.start
                    : (_dragHighlight == _TrimThumb.end ? Thumb.end : null),
              ),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: scheme.primary.withValues(alpha: 0.55),
              inactiveTrackColor: scheme.outline.withValues(alpha: 0.22),
              trackHeight: 4,
            ),
          ),
          child: RangeSlider(
            values: rv,
            min: 0,
            max: dur,
            labels: RangeLabels(startStr, endStr),
            onChanged: (v) {
              setState(() {
                if ((v.start - rv.start).abs() >= (v.end - rv.end).abs()) {
                  _dragHighlight = _TrimThumb.start;
                } else {
                  _dragHighlight = _TrimThumb.end;
                }
              });
              final clamped = _clampRange(v.start, v.end);
              widget.onChanged(clamped.start, clamped.end);
            },
            onChangeEnd: (_) => setState(() => _dragHighlight = null),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TrimPointCard(
                label: l10n.audioEditTrimStart,
                helper: l10n.audioEditMoveStartHint,
                time: startStr,
                focused: _dragHighlight == _TrimThumb.start,
                onMinus: () => _nudgeStart(-kAudioEditTrimNudgeSec),
                onPlus: () => _nudgeStart(kAudioEditTrimNudgeSec),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TrimPointCard(
                label: l10n.audioEditTrimEnd,
                helper: l10n.audioEditMoveEndHint,
                time: endStr,
                focused: _dragHighlight == _TrimThumb.end,
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
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String helper;
  final String time;
  final bool focused;
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              time,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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

class _AudioTrimTimelineBar extends StatelessWidget {
  const _AudioTrimTimelineBar({
    required this.durationSec,
    required this.startSec,
    required this.endSec,
  });

  final double durationSec;
  final double startSec;
  final double endSec;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final dur = durationSec <= 0 ? 1.0 : durationSec;
        final s = (startSec / dur).clamp(0.0, 1.0);
        final e = (endSec / dur).clamp(s, 1.0);
        final left = w * s;
        final selW = (w * (e - s)).clamp(0.0, w - left);

        return SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Positioned(
                left: left,
                width: selW,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: (left - 7).clamp(0.0, w - 14),
                child: _HandleDot(scheme: scheme),
              ),
              Positioned(
                left: (left + selW - 7).clamp(0.0, w - 14),
                child: _HandleDot(scheme: scheme),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HandleDot extends StatelessWidget {
  const _HandleDot({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary,
        border: Border.all(color: scheme.surface, width: 2),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
