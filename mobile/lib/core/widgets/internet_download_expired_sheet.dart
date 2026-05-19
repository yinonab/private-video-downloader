import "package:flutter/material.dart";

import "../downloads/expired_download_navigation.dart";
import "../l10n/context_l10n.dart";
import "../models/download_models.dart";

/// Expired/missing **internet download** job media — offer explicit redownload (no passive triggers).
Future<void> showInternetDownloadExpiredSheet(
  BuildContext parentContext, {
  required String jobId,
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
              border: Border.all(color: scheme.outline.withValues(alpha: 0.38)),
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
                    l10n.fileNoLongerAvailableTitle,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.fileNoLongerAvailableRedownloadBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      await navigateToRedownloadAfterExpiry(
                        parentContext,
                        sourceDownloadJobId: jobId,
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
                    child: Text(l10n.downloadAgainAction),
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
                    child: Text(l10n.homeCancel),
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

/// Upload source missing on server — user must choose video again (no redownload).
Future<void> showUploadSourceExpiredDialog(BuildContext context) async {
  final l10n = context.l10n;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.fileNoLongerAvailableTitle),
      content: Text(l10n.uploadSourceNoLongerAvailableBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.chooseAgainAction),
        ),
      ],
    ),
  );
}
