/// Splits a possibly long yt-dlp title / caption into a short headline and optional body for expandable UI.
final class VideoTitleSplit {
  const VideoTitleSplit({required this.headlineTitle, this.expandableDescription});

  /// Short line shown by default (may be truncated).
  final String headlineTitle;

  /// Full extra text behind “Open description”; null when nothing to expand.
  final String? expandableDescription;
}

const int _headlineMaxChars = 120;

/// Single-line titles longer than [singleLineThreshold] get a truncated headline + full text expandable.
const int _singleLineFoldChars = 100;

VideoTitleSplit splitVideoTitleForDisplay(String? rawTitle) {
  final t = (rawTitle ?? "").trim();
  if (t.isEmpty) {
    return const VideoTitleSplit(headlineTitle: "");
  }

  final lines = t.split(RegExp(r"\r?\n")).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (lines.isEmpty) {
    return const VideoTitleSplit(headlineTitle: "");
  }

  if (lines.length == 1) {
    final only = lines.first;
    if (only.length <= _singleLineFoldChars) {
      return VideoTitleSplit(headlineTitle: only);
    }
    final short = only.length > _headlineMaxChars ? "${only.substring(0, _headlineMaxChars - 1)}…" : only;
    return VideoTitleSplit(headlineTitle: short, expandableDescription: only);
  }

  final first = lines.first;
  final rest = lines.skip(1).join("\n").trim();

  final truncatedHead =
      first.length > _headlineMaxChars ? "${first.substring(0, _headlineMaxChars - 1)}…" : first;

  final buf = StringBuffer();
  if (first.length > _headlineMaxChars) {
    buf.writeln(first);
  }
  if (rest.isNotEmpty) {
    buf.write(rest);
  }
  final expandable = buf.toString().trim();
  if (expandable.isEmpty) {
    return VideoTitleSplit(headlineTitle: truncatedHead);
  }
  return VideoTitleSplit(headlineTitle: truncatedHead, expandableDescription: expandable);
}
