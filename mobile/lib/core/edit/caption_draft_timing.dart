import "../models/quick_edit_models.dart";

/// Minimum editable caption segment duration (V2.4B).
const double kCaptionDraftMinDurationSec = 0.3;

/// Timing nudge step in the draft editor (V2.4B).
const double kCaptionDraftTimingStepSec = 0.1;

double roundCaptionDraftTimingSec(double sec) =>
    (sec * 10).roundToDouble() / 10;

String captionDraftPreciseRangeLabel(double startSec, double endSec) {
  String fmt(double s) {
    var x = s;
    if (!x.isFinite || x < 0) x = 0;
    final tenthsTotal = (x * 10).round();
    final mm = (tenthsTotal ~/ 600).toString().padLeft(2, '0');
    final rem = tenthsTotal % 600;
    final ss = (rem ~/ 10).toString().padLeft(2, '0');
    final t = rem % 10;
    return '$mm:$ss.$t';
  }

  return '${fmt(startSec)}–${fmt(endSec)}';
}

CaptionDraftTimingBounds captionDraftTimingBounds({
  required int segmentIndex,
  required List<CaptionDraftSegment> segments,
  required double? videoDurationSec,
}) {
  assert(segmentIndex >= 0 && segmentIndex < segments.length);
  final seg = segments[segmentIndex];
  final prevEnd =
      segmentIndex > 0 ? segments[segmentIndex - 1].endSec : 0.0;
  double nextStart = double.infinity;
  if (segmentIndex + 1 < segments.length) {
    nextStart = segments[segmentIndex + 1].startSec;
  } else if (videoDurationSec != null &&
      videoDurationSec.isFinite &&
      videoDurationSec > 0) {
    nextStart = videoDurationSec;
  }

  return CaptionDraftTimingBounds(
    minStart: prevEnd.clamp(0.0, double.infinity).toDouble(),
    maxStart: seg.endSec - kCaptionDraftMinDurationSec,
    minEnd: seg.startSec + kCaptionDraftMinDurationSec,
    maxEnd: nextStart,
  );
}

final class CaptionDraftTimingBounds {
  const CaptionDraftTimingBounds({
    required this.minStart,
    required this.maxStart,
    required this.minEnd,
    required this.maxEnd,
  });

  final double minStart;
  final double maxStart;
  final double minEnd;
  final double maxEnd;
}

double clampCaptionDraftStartSec({
  required double startSec,
  required double endSec,
  required CaptionDraftTimingBounds bounds,
}) {
  final lo = bounds.minStart.clamp(0.0, double.infinity).toDouble();
  final maxStart = bounds.maxStart.clamp(lo, double.infinity).toDouble();
  final hi =
      (endSec - kCaptionDraftMinDurationSec).clamp(lo, maxStart).toDouble();
  if (hi < lo) return roundCaptionDraftTimingSec(lo);
  return roundCaptionDraftTimingSec(startSec.clamp(lo, hi).toDouble());
}

double clampCaptionDraftEndSec({
  required double startSec,
  required double endSec,
  required CaptionDraftTimingBounds bounds,
}) {
  final lo = (startSec + kCaptionDraftMinDurationSec)
      .clamp(bounds.minEnd, double.infinity)
      .toDouble();
  final hi = bounds.maxEnd.isFinite
      ? bounds.maxEnd.clamp(lo, double.infinity).toDouble()
      : double.infinity;
  if (!hi.isFinite) {
    return roundCaptionDraftTimingSec(
      endSec.clamp(lo, double.infinity).toDouble(),
    );
  }
  if (hi < lo) return roundCaptionDraftTimingSec(lo);
  return roundCaptionDraftTimingSec(endSec.clamp(lo, hi).toDouble());
}

CaptionDraftTimingBounds boundsForDraftTimingEdit({
  required int segmentIndex,
  required List<CaptionDraftSegment> segments,
  required double startSec,
  required double endSec,
  required double? videoDurationSec,
}) {
  final base = List<CaptionDraftSegment>.from(segments);
  base[segmentIndex] = base[segmentIndex].copyWith(
    startSec: startSec,
    endSec: endSec,
  );
  return captionDraftTimingBounds(
    segmentIndex: segmentIndex,
    segments: base,
    videoDurationSec: videoDurationSec,
  );
}

double nudgeCaptionDraftStartSec({
  required double startSec,
  required double endSec,
  required double deltaSec,
  required CaptionDraftTimingBounds bounds,
}) {
  return clampCaptionDraftStartSec(
    startSec: startSec + deltaSec,
    endSec: endSec,
    bounds: bounds,
  );
}

double nudgeCaptionDraftEndSec({
  required double startSec,
  required double endSec,
  required double deltaSec,
  required CaptionDraftTimingBounds bounds,
}) {
  return clampCaptionDraftEndSec(
    startSec: startSec,
    endSec: endSec + deltaSec,
    bounds: bounds,
  );
}
