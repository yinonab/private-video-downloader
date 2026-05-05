import "../../l10n/app_localizations.dart";

/// Maps raw worker/backend messages to readable localized copy for the main UI.
String formatDownloadJobError(AppLocalizations l10n, String raw) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  if (t.contains("Requested format is not available")) {
    return l10n.downloadJobErrorQuality;
  }
  if (t == "NORMALIZE_FAILED") {
    return l10n.downloadJobErrorNormalizeFailed;
  }
  return t;
}
