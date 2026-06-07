import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

enum AudioTimelineTrimHandle { start, end }

enum AudioTimelineMode { preview, trim }

/// Shared LTR audio range bar — preview (scrub + playhead) or trim-only (S/E drag).
class AudioPreviewTimeline extends StatefulWidget {
  const AudioPreviewTimeline({
    super.key,
    required this.mode,
    required this.l10n,
    required this.durationSec,
    required this.startSec,
    required this.endSec,
    required this.onTrimChanged,
    this.positionSec = 0,
    this.onSeek,
    this.onScrubStart,
    this.onScrubEnd,
    this.onTapStartMarker,
    this.onTapEndMarker,
    this.onTrimHandleActive,
    this.enabled = true,
  });

  final AudioTimelineMode mode;
  final AppLocalizations l10n;
  final double durationSec;
  final double startSec;
  final double endSec;
  final double positionSec;
  final void Function(double startSec, double endSec) onTrimChanged;
  final ValueChanged<double>? onSeek;
  final VoidCallback? onScrubStart;
  final VoidCallback? onScrubEnd;
  final VoidCallback? onTapStartMarker;
  final VoidCallback? onTapEndMarker;
  final ValueChanged<AudioTimelineTrimHandle?>? onTrimHandleActive;
  final bool enabled;

  bool get _isPreview => mode == AudioTimelineMode.preview;

  @override
  State<AudioPreviewTimeline> createState() => _AudioPreviewTimelineState();
}

enum _Interaction { none, scrub, dragStart, dragEnd }

class _AudioPreviewTimelineState extends State<AudioPreviewTimeline> {
  static const double _trackHeight = 8;
  static const double _handleVisual = 26;
  static const double _handleHit = 44;
  static const double _playheadVisual = 14;
  static const double _dragSlop = 10;

  _Interaction _mode = _Interaction.none;
  double? _pointerDownX;
  double? _tooltipSec;
  int _lastHapticSecond = -1;
  double? _scrubPreviewSec;
  bool _didDrag = false;
  ScrollHoldController? _scrollHold;

  bool get _compact => !widget._isPreview;

  double get _trackTopNormal => _compact ? 28.0 : 38.0;
  double get _trackTopStacked => _compact ? 40.0 : 50.0;

  double get _dur => widget.durationSec <= 0 ? 1.0 : widget.durationSec;

  double _frac(double sec) => (sec / _dur).clamp(0.0, 1.0);

  double _secFromX(double x, double width) =>
      (x / width).clamp(0.0, 1.0) * _dur;

  @override
  void dispose() {
    _endScrollHold();
    super.dispose();
  }

  void _setActiveHandle(AudioTimelineTrimHandle? handle) {
    widget.onTrimHandleActive?.call(handle);
  }

  void _beginScrollHold() {
    _endScrollHold();
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable != null) {
      _scrollHold = scrollable.position.hold(() {});
    }
  }

  void _endScrollHold() {
    _scrollHold?.cancel();
    _scrollHold = null;
  }

  bool _hitHandle(double dx, double dy, double centerX, double centerY) {
    return (dx - centerX).abs() <= _handleHit / 2 &&
        (dy - centerY).abs() <= _handleHit / 2;
  }

  void _maybeHapticOnSecond(double sec) {
    final whole = sec.floor();
    if (whole != _lastHapticSecond) {
      _lastHapticSecond = whole;
      HapticFeedback.selectionClick();
    }
  }

  void _onPointerDown(PointerDownEvent e, BoxConstraints constraints) {
    if (!widget.enabled) return;
    final width = constraints.maxWidth;
    final local = e.localPosition;
    final dx = local.dx;
    final dy = local.dy;

    final startX = _frac(widget.startSec) * width;
    final endX = _frac(widget.endSec) * width;
    final stack = (endX - startX).abs() < _handleHit * 1.05;
    final trackTop = stack ? _trackTopStacked : _trackTopNormal;
    final startY = stack ? 8.0 : trackTop - _handleVisual / 2 + _trackHeight / 2;
    final endY = stack ? 8.0 + _handleVisual + 4 : startY;

    _pointerDownX = dx;
    _lastHapticSecond = -1;
    _scrubPreviewSec = null;
    _didDrag = false;

    if (_hitHandle(dx, dy, startX, startY)) {
      _beginScrollHold();
      setState(() {
        _mode = _Interaction.dragStart;
        _tooltipSec = widget.startSec;
      });
      _setActiveHandle(AudioTimelineTrimHandle.start);
      HapticFeedback.lightImpact();
      return;
    }
    if (_hitHandle(dx, dy, endX, endY)) {
      _beginScrollHold();
      setState(() {
        _mode = _Interaction.dragEnd;
        _tooltipSec = widget.endSec;
      });
      _setActiveHandle(AudioTimelineTrimHandle.end);
      HapticFeedback.lightImpact();
      return;
    }

    if (!widget._isPreview) return;

    setState(() {
      _mode = _Interaction.scrub;
      _scrubPreviewSec = _secFromX(dx, width);
    });
    widget.onScrubStart?.call();
    widget.onSeek?.call(_scrubPreviewSec!);
  }

  void _onPointerMove(PointerMoveEvent e, BoxConstraints constraints) {
    if (!widget.enabled || _mode == _Interaction.none) return;
    final width = constraints.maxWidth;
    final dx = e.localPosition.dx;

    if (_pointerDownX != null && (dx - _pointerDownX!).abs() > _dragSlop) {
      _didDrag = true;
    }

    final sec = _secFromX(dx, width);

    switch (_mode) {
      case _Interaction.dragStart:
        final pair = clampAudioEditTrimRange(
          startSec: sec,
          endSec: widget.endSec,
          durationSec: _dur,
        );
        widget.onTrimChanged(pair.$1, pair.$2);
        _maybeHapticOnSecond(pair.$1);
        setState(() => _tooltipSec = pair.$1);
      case _Interaction.dragEnd:
        final pair = clampAudioEditTrimRange(
          startSec: widget.startSec,
          endSec: sec,
          durationSec: _dur,
        );
        widget.onTrimChanged(pair.$1, pair.$2);
        _maybeHapticOnSecond(pair.$2);
        setState(() => _tooltipSec = pair.$2);
      case _Interaction.scrub:
        setState(() => _scrubPreviewSec = sec);
        widget.onSeek?.call(sec);
      case _Interaction.none:
        break;
    }
  }

  void _onPointerEnd() {
    if (_mode == _Interaction.none) return;

    if (widget._isPreview) {
      if (_mode == _Interaction.dragStart && !_didDrag) {
        widget.onTapStartMarker?.call();
      } else if (_mode == _Interaction.dragEnd && !_didDrag) {
        widget.onTapEndMarker?.call();
      } else if (_mode == _Interaction.dragStart) {
        widget.onSeek?.call(widget.startSec);
      } else if (_mode == _Interaction.dragEnd) {
        widget.onSeek?.call(widget.endSec);
      }
      if (_mode == _Interaction.scrub) {
        widget.onScrubEnd?.call();
      }
    }

    _endScrollHold();
    _setActiveHandle(null);
    setState(() {
      _mode = _Interaction.none;
      _pointerDownX = null;
      _tooltipSec = null;
      _scrubPreviewSec = null;
      _didDrag = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final displayPos = _scrubPreviewSec ?? widget.positionSec;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final startX = _frac(widget.startSec) * width;
          final endX = _frac(widget.endSec) * width;
          final playX = _frac(displayPos) * width;
          final stack = (endX - startX).abs() < _handleHit * 1.05;
          final trackTop = stack ? _trackTopStacked : _trackTopNormal;
          final totalHeight = _compact
              ? (stack ? 76.0 : 56.0)
              : (stack ? 92.0 : 72.0);
          final startY = stack ? 8.0 : trackTop - _handleVisual / 2 + _trackHeight / 2;
          final endY = stack ? 8.0 + _handleVisual + 4 : startY;
          final draggingStart = _mode == _Interaction.dragStart;
          final draggingEnd = _mode == _Interaction.dragEnd;

          return SizedBox(
            height: totalHeight,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _onPointerDown(e, constraints),
              onPointerMove: (e) => _onPointerMove(e, constraints),
              onPointerUp: (_) => _onPointerEnd(),
              onPointerCancel: (_) => _onPointerEnd(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: trackTop,
                    height: _trackHeight,
                    child: CustomPaint(
                      painter: _TimelineTrackPainter(
                        colorScheme: scheme,
                        durationSec: _dur,
                        startSec: widget.startSec,
                        endSec: widget.endSec,
                      ),
                    ),
                  ),
                  if (widget._isPreview)
                    Positioned(
                      left: (playX - _playheadVisual / 2)
                          .clamp(0.0, width - _playheadVisual),
                      top: trackTop + _trackHeight / 2 - _playheadVisual / 2,
                      child: Semantics(
                        label: widget.l10n.audioEditPlayheadSemantics,
                        child: IgnorePointer(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            width: _playheadVisual,
                            height: _playheadVisual,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.onSurface,
                              border: Border.all(color: scheme.surface, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.shadow.withValues(alpha: 0.2),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  _TrimHandle(
                    label: "S",
                    semanticsLabel: widget.l10n.audioEditTrimStartMarkerSemantics,
                    centerX: startX,
                    centerY: startY,
                    visualSize: _handleVisual,
                    active: draggingStart,
                    scheme: scheme,
                    theme: theme,
                  ),
                  _TrimHandle(
                    label: "E",
                    semanticsLabel: widget.l10n.audioEditTrimEndMarkerSemantics,
                    semanticsHint: widget._isPreview
                        ? widget.l10n.audioEditPreviewEndingSemantics
                        : null,
                    centerX: endX,
                    centerY: endY,
                    visualSize: _handleVisual,
                    active: draggingEnd,
                    scheme: scheme,
                    theme: theme,
                  ),
                  if (_tooltipSec != null && _mode != _Interaction.scrub)
                    _DragTooltip(
                      timeSec: _tooltipSec!,
                      centerX: _mode == _Interaction.dragEnd ? endX : startX,
                      width: width,
                      theme: theme,
                      scheme: scheme,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrimHandle extends StatelessWidget {
  const _TrimHandle({
    required this.label,
    required this.semanticsLabel,
    this.semanticsHint,
    required this.centerX,
    required this.centerY,
    required this.visualSize,
    required this.active,
    required this.scheme,
    required this.theme,
  });

  final String label;
  final String semanticsLabel;
  final String? semanticsHint;
  final double centerX;
  final double centerY;
  final double visualSize;
  final bool active;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scale = active ? 1.12 : 1.0;
    final elevation = active ? 6.0 : 2.0;

    return Positioned(
      left: centerX - visualSize / 2,
      top: centerY - visualSize / 2,
      child: Semantics(
        label: semanticsLabel,
        hint: semanticsHint,
        child: IgnorePointer(
          child: AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Material(
              elevation: elevation,
              color: active
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.92),
              shape: CircleBorder(
                side: BorderSide(
                  color: active
                      ? scheme.primary.withValues(alpha: 0.95)
                      : scheme.surface,
                  width: active ? 2.5 : 2,
                ),
              ),
              child: SizedBox(
                width: visualSize,
                height: visualSize,
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DragTooltip extends StatelessWidget {
  const _DragTooltip({
    required this.timeSec,
    required this.centerX,
    required this.width,
    required this.theme,
    required this.scheme,
  });

  final double timeSec;
  final double centerX;
  final double width;
  final ThemeData theme;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    const tooltipW = 72.0;
    final left = (centerX - tooltipW / 2).clamp(4.0, width - tooltipW - 4);

    return Positioned(
      left: left,
      top: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.inverseSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            formatAudioEditTimeSec(timeSec),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onInverseSurface,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineTrackPainter extends CustomPainter {
  _TimelineTrackPainter({
    required this.colorScheme,
    required this.durationSec,
    required this.startSec,
    required this.endSec,
  });

  final ColorScheme colorScheme;
  final double durationSec;
  final double startSec;
  final double endSec;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = Radius.circular(h / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), r),
      Paint()..color = colorScheme.outline.withValues(alpha: 0.22),
    );

    final dur = durationSec <= 0 ? 1.0 : durationSec;
    final s = (startSec / dur).clamp(0.0, 1.0);
    final e = (endSec / dur).clamp(s, 1.0);
    final selLeft = w * s;
    final selWidth = math.max(0.0, w * (e - s));

    if (selLeft > 0.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, selLeft, h), r),
        Paint()..color = colorScheme.onSurface.withValues(alpha: 0.28),
      );
    }

    final afterLeft = selLeft + selWidth;
    if (afterLeft < w - 0.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(afterLeft, 0, w - afterLeft, h), r),
        Paint()..color = colorScheme.onSurface.withValues(alpha: 0.28),
      );
    }

    if (selWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(selLeft, 0, selWidth, h), r),
        Paint()..color = colorScheme.primary.withValues(alpha: 0.78),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineTrackPainter oldDelegate) {
    return oldDelegate.durationSec != durationSec ||
        oldDelegate.startSec != startSec ||
        oldDelegate.endSec != endSec ||
        oldDelegate.colorScheme != colorScheme;
  }
}
