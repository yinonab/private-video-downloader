import "package:flutter/material.dart";

import "../../core/config/quick_edit_config.dart";
import "../../core/models/download_models.dart";
import "../../core/models/quick_edit_models.dart";
import "edit_video_screen.dart";
import "launch_audio_edit.dart";
import "quick_edit_source_expired_sheet.dart";

/// Opens Quick Edit, or the server-expired sheet when [serverRetentionReferenceUtc] is past retention.
Future<void> launchQuickEditForJob(
  BuildContext context, {
  required String jobId,
  required DateTime? serverRetentionReferenceUtc,
  DownloadItem? prefetchListItem,
  DownloadDetailResponse? prefetchDetail,
}) async {
  if (!context.mounted) return;
  if (prefetchDetail != null && downloadDetailIsAudioOnly(prefetchDetail)) {
    await launchAudioEditForJob(context, jobId: jobId);
    return;
  }
  if (prefetchListItem != null && downloadItemIsAudioOnly(prefetchListItem)) {
    await launchAudioEditForJob(context, jobId: jobId);
    return;
  }
  if (quickEditServerSourceLikelyExpired(serverRetentionReferenceUtc)) {
    await showQuickEditSourceExpiredSheet(
      context,
      sourceDownloadJobId: jobId,
      prefetchedItem: prefetchListItem,
      prefetchedDetail: prefetchDetail,
    );
    return;
  }
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => EditVideoScreen.download(sourceDownloadJobId: jobId),
    ),
  );
}
