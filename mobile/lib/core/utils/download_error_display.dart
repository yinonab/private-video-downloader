import "../../l10n/app_localizations.dart";

/// Legacy Hebrew messages previously stored by the worker (before stable error codes).
const String _legacyQualityUnavailableHe =
    "האיכות שנבחרה לא זמינה לסרטון הזה. נסה איכות אחרת או Best MP4.";
const String _legacyFallbackFailedHe = "לא ניתן להוריד את הסרטון הזה בפורמט זמין.";

bool _looksLikeTechnicalLeak(String raw) {
  final s = raw.toLowerCase();
  const markers = [
    "yt-dlp",
    "yt_dlp",
    "youtube-dl",
    "[debug]",
    "[warning]",
    "csrf",
    "cookies-from-browser",
    "--cookies",
    "ffmpeg",
    "ffprobe",
    "stderr",
    "traceback",
    "github.com",
    "http error",
    "fragment",
    "requested formats",
    "extractor",
    "unable to download",
  ];
  return markers.any(s.contains);
}

/// Maps stored job error strings (codes or legacy copy) to localized UI text.
/// Raw yt-dlp stderr must never be shown; unknown / technical strings fall back to [AppLocalizations.downloadErrorGeneric].
String formatDownloadJobError(AppLocalizations l10n, String raw) {
  final t = raw.trim();
  if (t.isEmpty) return l10n.downloadErrorGeneric;

  switch (t) {
    case "LINKCLIP_ERR_INSTAGRAM_RESTRICTED":
      return l10n.downloadErrorInstagramRestricted;
    case "LINKCLIP_ERR_UNSUPPORTED_OR_PRIVATE":
      return l10n.downloadErrorUnsupportedOrPrivate;
    case "LINKCLIP_ERR_GENERIC":
      return l10n.downloadErrorGeneric;
    case "LINKCLIP_ERR_QUALITY_UNAVAILABLE":
      return l10n.downloadJobErrorQuality;
    case "LINKCLIP_ERR_QUALITY_FALLBACK_FAILED":
      return l10n.downloadErrorGeneric;
    case "NORMALIZE_FAILED":
      return l10n.downloadJobErrorNormalizeFailed;
  }

  if (t.contains("Requested format is not available")) {
    return l10n.downloadJobErrorQuality;
  }
  if (t == _legacyQualityUnavailableHe) {
    return l10n.downloadJobErrorQuality;
  }
  if (t == _legacyFallbackFailedHe) {
    return l10n.downloadErrorGeneric;
  }

  if (_looksLikeTechnicalLeak(t)) {
    return l10n.downloadErrorGeneric;
  }

  return l10n.downloadErrorGeneric;
}
