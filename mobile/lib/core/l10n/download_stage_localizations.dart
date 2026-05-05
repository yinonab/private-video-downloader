import "../../l10n/app_localizations.dart";

/// Maps backend job [status] to a short stage title for progress UI.
String downloadStageTitle(AppLocalizations l10n, String status) {
  switch (status.trim()) {
    case "queued":
      return l10n.downloadStageQueued;
    case "analyzing":
      return l10n.downloadStagePreparing;
    case "running":
      return l10n.downloadStageDownloading;
    case "done":
      return l10n.downloadStageReadyServer;
    case "failed":
      return l10n.downloadStageFailed;
    case "canceled":
      return l10n.downloadStageCanceled;
    default:
      return l10n.downloadStageUnknown;
  }
}
