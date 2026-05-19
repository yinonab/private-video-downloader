import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../app_scope.dart";
import "../l10n/context_l10n.dart";
import "../models/download_models.dart";
import "../../features/download_status/download_status_screen.dart";
import "redownload_request_resolution.dart";

/// Starts the existing “force new download” flow after server-side media expired.
///
/// Shared by Quick Edit expiry sheet and generic Save/Open/Share expiry prompts.
Future<void> navigateToRedownloadAfterExpiry(
  BuildContext parentContext, {
  required String sourceDownloadJobId,
  DownloadDetailResponse? prefetchedDetail,
  DownloadItem? prefetchedItem,
}) async {
  if (!parentContext.mounted) return;
  final scope = AppScope.read(parentContext);
  final messenger = ScaffoldMessenger.maybeOf(parentContext);
  final l10n = parentContext.l10n;

  final req = await resolveRedownloadRequestForJob(
    session: scope.session,
    fetchDetail: scope.downloadService.detail,
    jobId: sourceDownloadJobId,
    prefetchedDetail: prefetchedDetail,
    prefetchedItem: prefetchedItem,
  );

  if (!parentContext.mounted) return;

  if (req == null) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.editSourceMissingOriginalUrl)),
    );
    return;
  }

  final freshReq = CreateDownloadRequest(
    url: req.url,
    format: req.format,
    quality: req.quality,
    forceNew: true,
  );

  assert(() {
    if (kDebugMode) {
      debugPrint(
        "expired_redownload_navigate oldJobId=$sourceDownloadJobId forceNew=true",
      );
    }
    return true;
  }());

  await Navigator.of(parentContext).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DownloadStatusScreen.pendingCreate(
        request: freshReq,
        expiredRedownloadPriorJobId: sourceDownloadJobId.trim(),
      ),
    ),
  );
}
