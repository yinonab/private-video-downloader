import "../../l10n/app_localizations.dart";
import "local_edit_history_item.dart";

String audioEditQualityLabel(AppLocalizations l10n, String? preset) {
  switch ((preset ?? "").toLowerCase()) {
    case "standard":
      return l10n.audioEditQualityStandard;
    case "best":
      return l10n.audioEditQualityBest;
    case "high":
    default:
      return l10n.audioEditQualityHigh;
  }
}

/// Compact summary for Edits tab audio cards, e.g. `MP3 · 1.5x · High · 00:34`.
String? audioEditSummaryLine(AppLocalizations l10n, LocalEditHistoryItem item) {
  if (!item.isAudioOutput) return null;
  final parts = <String>[l10n.editsMp3Badge];
  if (item.audioTrimApplied == true) {
    parts.add(l10n.editsSummaryTrimmed);
  }
  final spd = item.audioSpeedFactor;
  if (spd != null && (spd - 1.0).abs() > 1e-6) {
    final label = spd == spd.roundToDouble()
        ? "${spd.toInt()}x"
        : "${spd}x".replaceAll(".0", "");
    parts.add(label);
  }
  if (item.audioQualityPreset != null &&
      item.audioQualityPreset!.isNotEmpty &&
      item.audioQualityPreset != "high") {
    parts.add(audioEditQualityLabel(l10n, item.audioQualityPreset));
  }
  final dur = item.durationSeconds;
  if (dur != null && dur > 0) {
    final m = dur ~/ 60;
    final s = dur % 60;
    parts.add("$m:${s.toString().padLeft(2, "0")}");
  }
  return parts.join(" · ");
}
