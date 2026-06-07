import "dart:math" as math;

import "package:flutter/material.dart";

import "../../../l10n/app_localizations.dart";

/// Interactive LTR audio timeline: full track, trim range, playhead, S/E markers.
class AudioPreviewTimeline extends StatelessWidget {
  const AudioPreviewTimeline({
    super.key,
    required this.l10n,
    required this.durationSec,
    required this.startSec,
    required this.endSec,
    required this.positionSec,
    required this.onSeek,
    required this.onTapStartMarker,
    required this.onTapEndMarker,
  });

  final AppLocalizations l10n;
  final double durationSec;
  final double startSec;
  final double endSec;
  final double positionSec;
  final ValueChanged<double> onSeek;
  final VoidCallback onTapStartMarker;
  final VoidCallback onTapEndMarker;

  static const double _trackHeight = 6;
  static const double _markerSize = 22;
  static const double _playheadWidth = 2;
  static const double _verticalPad = 4;

  double get _dur => durationSec <= 0 ? 1.0 : durationSec;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final startX = (startSec / _dur).clamp(0.0, 1.0) * width;
          final endX = (endSec / _dur).clamp(0.0, 1.0) * width;
          final playX = (positionSec / _dur).clamp(0.0, 1.0) * width;
          final markerGap = (endX - startX).abs();
          final stackMarkers = markerGap < _markerSize + 6;
          final startMarkerTop = stackMarkers ? _verticalPad : _verticalPad;
          final endMarkerTop = stackMarkers ? _verticalPad + _markerSize + 2 : _verticalPad;

          return SizedBox(
            height: stackMarkers ? 78 : 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: (stackMarkers ? 52 : 34) - _trackHeight / 2,
                  height: _trackHeight,
                  child: _TimelineTrack(
                    durationSec: _dur,
                    startSec: startSec.clamp(0.0, _dur),
                    endSec: endSec.clamp(0.0, _dur),
                    positionSec: positionSec.clamp(0.0, _dur),
                    onSeek: onSeek,
                  ),
                ),
                Positioned(
                  left: (playX - _playheadWidth / 2).clamp(0.0, width - _playheadWidth),
                  top: (stackMarkers ? 44 : 26),
                  bottom: 6,
                  child: IgnorePointer(
                    child: Container(
                      width: _playheadWidth,
                      decoration: BoxDecoration(
                        color: scheme.onSurface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                _MarkerBadge(
                  label: "S",
                  semanticsLabel: l10n.audioEditTrimStartMarkerSemantics,
                  left: (startX - _markerSize / 2).clamp(0.0, width - _markerSize),
                  top: startMarkerTop,
                  size: _markerSize,
                  onTap: onTapStartMarker,
                ),
                _MarkerBadge(
                  label: "E",
                  semanticsLabel: l10n.audioEditTrimEndMarkerSemantics,
                  semanticsHint: l10n.audioEditPreviewEndingSemantics,
                  left: (endX - _markerSize / 2).clamp(0.0, width - _markerSize),
                  top: endMarkerTop,
                  size: _markerSize,
                  onTap: onTapEndMarker,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimelineTrack extends StatelessWidget {
  const _TimelineTrack({
    required this.durationSec,
    required this.startSec,
    required this.endSec,
    required this.positionSec,
    required this.onSeek,
  });

  final double durationSec;
  final double startSec;
  final double endSec;
  final double positionSec;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      slider: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          final frac = (local.dx / box.size.width).clamp(0.0, 1.0);
          onSeek(frac * durationSec);
        },
        child: CustomPaint(
          painter: _TimelineTrackPainter(
            colorScheme: scheme,
            durationSec: durationSec,
            startSec: startSec,
            endSec: endSec,
          ),
          child: const SizedBox.expand(),
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

class _MarkerBadge extends StatelessWidget {
  const _MarkerBadge({
    required this.label,
    required this.semanticsLabel,
    this.semanticsHint,
    required this.left,
    required this.top,
    required this.size,
    required this.onTap,
  });

  final String label;
  final String semanticsLabel;
  final String? semanticsHint;
  final double left;
  final double top;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        hint: semanticsHint,
        child: Material(
          color: scheme.primary.withValues(alpha: 0.9),
          shape: CircleBorder(
            side: BorderSide(color: scheme.surface, width: 2),
          ),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
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
    );
  }
}
