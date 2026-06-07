import "dart:async";
import "dart:io";

import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/media_export_constants.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/media_export_display_path.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/utils/format_bytes_ui.dart";
import "../../core/widgets/branded_progress.dart";
import "../../core/widgets/keep_app_open_hint.dart";
import "../../services/saved_media_actions.dart";
import "audio_edit_screen.dart";

/// Whether the download job has a readable local file (internal app storage).
Future<bool> isDownloadJobSavedLocally(BuildContext context, String jobId) async {
  return validateSavedDownload(AppScope.read(context).session, jobId);
}

Future<void> _dismissSaveProgressDialog(BuildContext context) async {
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) {
    nav.pop();
  }
}

Future<bool> _saveDownloadToDevice(
  BuildContext context, {
  required String jobId,
  DownloadDetailResponse? prefetchedDetail,
}) async {
  final scope = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final progress = ValueNotifier<(int received, int total)>((0, 0));

  if (context.mounted) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogCtx) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text(l10n.loadingSavingToDeviceDot),
              content: ValueListenableBuilder<(int, int)>(
                valueListenable: progress,
                builder: (ctx, pair, _) {
                  final received = pair.$1;
                  final total = pair.$2;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BrandedProgressBar(
                        indeterminate: total <= 0,
                        value: total > 0 ? (received / total).clamp(0.0, 1.0) : null,
                        percentLabel: total > 0
                            ? l10n.progressPercent(
                                (100 * received / total).clamp(0, 100).round(),
                              )
                            : null,
                        stageLabel: l10n.loadingSavingToDeviceDot,
                        bytesSubtitle: total > 0
                            ? "${formatBytesUi(received)} / ${formatBytesUi(total)}"
                            : null,
                      ),
                      const SizedBox(height: 12),
                      KeepAppOpenHint(l10n.keepAppOpenUntilDownloadFinished),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  try {
    final detail = prefetchedDetail ?? await scope.api.downloadDetail(jobId);
    if (detail.status != "done") {
      if (context.mounted) {
        await _dismissSaveProgressDialog(context);
        messenger.showSnackBar(SnackBar(content: Text(l10n.audioEditRequiresSaveBody)));
      }
      return false;
    }
    final outcome = await scope.files.downloadJobMedia(
      jobId: jobId,
      detail: detail,
      onProgress: (received, total) {
        progress.value = (received, total);
      },
    );
    final ok = await validateSavedDownload(scope.session, jobId);
    if (context.mounted) {
      await _dismissSaveProgressDialog(context);
      if (ok) {
        final displayPath = MediaExportDisplayPath.downloadsThenFolder(
          l10n,
          kLinkClipMediaStoreFolderName,
        );
        final msg = outcome.mediaStorePublished == true && outcome.publicUri != null
            ? l10n.downloadSavedToDownloads(displayPath)
            : (Platform.isAndroid
                ? l10n.downloadSavedInAppOnly(displayPath)
                : l10n.downloadSavedGeneric);
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
      }
    }
    return ok;
  } catch (e) {
    if (context.mounted) {
      await _dismissSaveProgressDialog(context);
      final msg = e is ApiError ? localizedApiErrorMessage(l10n, e) : "$e";
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
    return false;
  } finally {
    progress.dispose();
  }
}

/// Blocking dialog when local source is missing. Returns true when file is local after flow.
Future<bool> ensureLocalDownloadForAudioActions(
  BuildContext context, {
  required String jobId,
  DownloadDetailResponse? prefetchedDetail,
  DownloadItem? prefetchedItem,
}) async {
  final scope = AppScope.read(context);
  if (await validateSavedDownload(scope.session, jobId)) return true;
  if (!context.mounted) return false;

  final l10n = context.l10n;
  final save = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.audioEditRequiresSaveTitle),
      content: Text(l10n.audioEditRequiresSaveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.audioEditRequiresSaveCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.audioEditRequiresSaveNow),
        ),
      ],
    ),
  );
  if (save != true || !context.mounted) return false;

  DownloadDetailResponse? detail = prefetchedDetail;
  if (detail == null && prefetchedItem != null) {
    try {
      detail = await scope.api.downloadDetail(jobId);
    } catch (_) {
      detail = null;
    }
  }

  if (!context.mounted) return false;
  return _saveDownloadToDevice(context, jobId: jobId, prefetchedDetail: detail);
}

/// Opens [AudioEditScreen] only when the source MP3 exists locally.
Future<void> launchAudioEditForJob(
  BuildContext context, {
  required String jobId,
  DownloadDetailResponse? prefetchedDetail,
  DownloadItem? prefetchedItem,
}) async {
  if (!context.mounted) return;
  final ok = await ensureLocalDownloadForAudioActions(
    context,
    jobId: jobId,
    prefetchedDetail: prefetchedDetail,
    prefetchedItem: prefetchedItem,
  );
  if (!ok || !context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => AudioEditScreen(jobId: jobId),
    ),
  );
}

Future<void> openAudioDownloadIfLocal(
  BuildContext context, {
  required String jobId,
  required bool isAudioOnly,
  DownloadDetailResponse? prefetchedDetail,
}) async {
  if (!isAudioOnly) {
    await openSavedDownload(context: context, session: AppScope.read(context).session, jobId: jobId);
    return;
  }
  final ok = await ensureLocalDownloadForAudioActions(
    context,
    jobId: jobId,
    prefetchedDetail: prefetchedDetail,
  );
  if (!ok || !context.mounted) return;
  await openSavedDownload(context: context, session: AppScope.read(context).session, jobId: jobId);
}

Future<void> shareAudioDownloadIfLocal(
  BuildContext context, {
  required String jobId,
  required bool isAudioOnly,
  String? title,
  DownloadDetailResponse? prefetchedDetail,
}) async {
  final scope = AppScope.read(context);
  if (!isAudioOnly) {
    await shareSavedDownload(
      context: context,
      session: scope.session,
      jobId: jobId,
      title: title,
    );
    return;
  }
  final ok = await ensureLocalDownloadForAudioActions(
    context,
    jobId: jobId,
    prefetchedDetail: prefetchedDetail,
  );
  if (!ok || !context.mounted) return;
  await shareSavedDownload(
    context: context,
    session: scope.session,
    jobId: jobId,
    title: title,
  );
}
