import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/downloads/redownload_request_resolution.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/download_models.dart";
import "../download_status/download_status_screen.dart";

/// Shown when Quick Edit cannot run because server-side source media likely expired or API returned
/// [EDIT_INVALID_SOURCE].
Future<void> showQuickEditSourceExpiredSheet(
  BuildContext parentContext, {
  required String sourceDownloadJobId,
  DownloadDetailResponse? prefetchedDetail,
  DownloadItem? prefetchedItem,
}) async {
  final l10n = parentContext.l10n;
  final scheme = Theme.of(parentContext).colorScheme;
  final theme = Theme.of(parentContext);

  await showModalBottomSheet<void>(
    context: parentContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.paddingOf(sheetCtx).bottom,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.38)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.editSourceExpiredTitle,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.editSourceExpiredBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      await _startRedownloadAfterExpiryResolved(
                        parentContext,
                        sourceDownloadJobId,
                        prefetchedDetail: prefetchedDetail,
                        prefetchedItem: prefetchedItem,
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(l10n.editSourceExpiredDownloadNow),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(sheetCtx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(l10n.editSourceExpiredCancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _startRedownloadAfterExpiryResolved(
  BuildContext parentContext,
  String jobId, {
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
    jobId: jobId,
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
      debugPrint("expired_redownload_navigate oldJobId=$jobId forceNew=true");
    }
    return true;
  }());
  await Navigator.of(parentContext).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => DownloadStatusScreen.pendingCreate(
        request: freshReq,
        expiredRedownloadPriorJobId: jobId.trim(),
      ),
    ),
  );
}
