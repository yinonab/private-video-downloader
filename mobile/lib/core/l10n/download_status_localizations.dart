import "../../l10n/app_localizations.dart";

String localizedDownloadJobStatus(AppLocalizations l10n, String status) {
  switch (status.trim()) {
    case "queued":
      return l10n.downloadStatusQueued;
    case "running":
    case "analyzing":
      return l10n.downloadStatusRunning;
    case "done":
      return l10n.downloadStatusDone;
    case "failed":
      return l10n.downloadStatusFailed;
    case "canceled":
      return l10n.downloadStatusCanceled;
    default:
      return status.isEmpty ? l10n.downloadStatusUnknown : status;
  }
}
