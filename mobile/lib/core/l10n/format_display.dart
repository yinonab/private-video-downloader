import "package:flutter/widgets.dart";

import "../../l10n/app_localizations.dart";
import "../models/analyze_models.dart";

/// Uses backend label when unknown id; otherwise ARB quality titles.
String formatOptionDisplayLabel(BuildContext context, FormatOption f) {
  final l10n = AppLocalizations.of(context);
  switch (f.value) {
    case "best":
      return l10n.formatBestMp4;
    case "1080p":
      return l10n.format1080pMp4;
    case "720p":
      return l10n.format720pMp4;
    case "480p":
      return l10n.format480pMp4;
    case "tiktok_ready":
      return l10n.qualityTikTokReady;
    case "audio":
    case "audio_mp3":
      return l10n.formatAudioMp3;
    default:
      return f.label.isEmpty ? f.value : f.label;
  }
}
