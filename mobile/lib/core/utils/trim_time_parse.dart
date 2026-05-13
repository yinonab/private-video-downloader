/// Parses flexible user trim time strings into seconds.
///
/// Supported:
/// - Plain seconds: `5`, `12.5`
/// - `mm:ss` or `m:ss`
/// - `hh:mm:ss` (leading parts may be single digits)
double? parseFlexibleTimeSeconds(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  final plain = RegExp(r"^(\d+)(\.\d+)?$");
  final mPlain = plain.firstMatch(s);
  if (mPlain != null) {
    return double.tryParse(s.replaceAll(",", "."));
  }

  final parts =
      s.split(":").map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return null;

  double? parseChunk(String chunk) =>
      double.tryParse(chunk.replaceAll(",", "."));

  if (parts.length == 1) {
    return parseChunk(parts[0]);
  }
  if (parts.length == 2) {
    final mm = parseChunk(parts[0]);
    final ss = parseChunk(parts[1]);
    if (mm == null || ss == null) return null;
    if (mm < 0 || ss < 0 || ss >= 60) return null;
    return mm * 60 + ss;
  }
  if (parts.length >= 3) {
    final hh = parseChunk(parts[parts.length - 3]);
    final mm = parseChunk(parts[parts.length - 2]);
    final ss = parseChunk(parts[parts.length - 1]);
    if (hh == null || mm == null || ss == null) return null;
    if (mm < 0 || mm >= 60 || ss < 0 || ss >= 60 || hh < 0) return null;
    return hh * 3600 + mm * 60 + ss;
  }
  return null;
}

/// Formats seconds as `HH:MM:SS` when duration ≥ 1h, else `MM:SS`.
String formatTrimDurationUi(double seconds) {
  final sec = seconds.floor().clamp(0, 864000);
  if (sec >= 3600) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return "${h.toString().padLeft(2, "0")}:${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}";
  }
  final m = sec ~/ 60;
  final s = sec % 60;
  return "${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}";
}
