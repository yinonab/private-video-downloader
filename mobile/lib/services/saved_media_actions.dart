import "dart:developer" as dev;
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:open_filex/open_filex.dart";
import "package:share_plus/share_plus.dart";

import "../core/storage/local_session.dart";
import "../core/utils/download_perf_log.dart";
import "../l10n/app_localizations.dart";

Future<bool> validateSavedDownload(LocalSession session, String jobId) async {
  final desc = await session.savedDownloadForJob(jobId);
  if (desc == null || desc.internalPath.trim().isEmpty) {
    debugPrint("[FinalFile] validate jobId=$jobId descriptorFound=false");
    dev.log("saved_media: missing descriptor jobId=$jobId");
    return false;
  }
  final path = desc.internalPath.trim();
  if (path.startsWith("content:")) {
    debugPrint("[FinalFile] validate jobId=$jobId descriptorFound=true pathType=contentUri (rejected)");
    dev.log("saved_media: unexpected content internal ref jobId=$jobId");
    return false;
  }
  final f = File(path);
  final exists = await f.exists();
  final len = exists ? await f.length() : 0;
  debugPrint(
    "[FinalFile] validate jobId=$jobId descriptorFound=true exists=$exists size=$len "
    "mediaStoreUri=${desc.publicUri != null && desc.publicUri!.trim().isNotEmpty}",
  );
  dev.log(
    "saved_media: validate internal exists=$exists size=$len storedSize=${desc.fileSizeBytes} jobId=$jobId path=$path",
  );
  if (!exists || len <= 0) return false;
  if (desc.fileSizeBytes > 0 && len != desc.fileSizeBytes) {
    dev.log(
      "saved_media: size mismatch (still allowing open/share) expected=${desc.fileSizeBytes} actual=$len",
    );
  }
  return true;
}

Future<void> openSavedDownload({
  required BuildContext context,
  required LocalSession session,
  required String jobId,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final desc = await session.savedDownloadForJob(jobId);
  if (desc == null || desc.internalPath.isEmpty) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.savedMustDownloadFirst)));
    return;
  }
  final localPath = desc.internalPath.trim();
  dev.log(
    "saved_media open: internal=$localPath publicUri=${desc.publicUri} name=${desc.shareFileName} mime=${desc.mimeType}",
  );
  if (!await validateSavedDownload(session, jobId)) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
    return;
  }
  try {
    final r = await OpenFilex.open(localPath);
    dev.log("saved_media open: OpenFilex result type=${r.type} message=${r.message}");
    if (r.type != ResultType.done) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
    }
  } catch (e, st) {
    dev.log("saved_media open: exception", error: e, stackTrace: st);
    messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
  }
}

Future<void> shareSavedDownload({
  required BuildContext context,
  required LocalSession session,
  required String jobId,
  String? title,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  debugPrint("[FinalFile] share requested jobId=$jobId");

  logMobileDownloadPerf(
    stage: "share_validate_cache_start",
    durationMs: 0,
    jobId: jobId,
  );
  final validateSw = Stopwatch()..start();
  final desc = await session.savedDownloadForJob(jobId);
  if (desc == null || desc.internalPath.isEmpty) {
    validateSw.stop();
    logMobileDownloadPerf(
      stage: "share_validate_cache_done",
      durationMs: validateSw.elapsedMilliseconds,
      jobId: jobId,
      cacheValid: false,
      result: "missing_descriptor",
    );
    debugPrint("[FinalFile] share abort — no descriptor jobId=$jobId");
    messenger.showSnackBar(SnackBar(content: Text(l10n.savedMustDownloadFirst)));
    return;
  }
  final localPath = desc.internalPath.trim();
  final hasMediaStore =
      desc.publicUri != null && desc.publicUri!.trim().isNotEmpty;
  debugPrint(
    "[FinalFile] share descriptorFound=true mediaStore=$hasMediaStore "
    "shareUsing=pathType=cache",
  );
  dev.log(
    "saved_media share: internal=$localPath name=${desc.shareFileName} mime=${desc.mimeType}",
  );
  final ok = await validateSavedDownload(session, jobId);
  validateSw.stop();
  var sizeBytes = 0;
  if (ok) {
    try {
      sizeBytes = await File(localPath).length();
    } catch (_) {
      sizeBytes = desc.fileSizeBytes;
    }
  }
  logMobileDownloadPerf(
    stage: "share_validate_cache_done",
    durationMs: validateSw.elapsedMilliseconds,
    jobId: jobId,
    cacheValid: ok,
    bytes: sizeBytes > 0 ? sizeBytes : null,
    result: ok ? "shared_cache" : "validate_failed",
  );
  if (!ok) {
    debugPrint("[FinalFile] share abort — validate failed jobId=$jobId");
    messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotShareFile)));
    return;
  }
  final shareText = (title != null && title.trim().isNotEmpty) ? title.trim() : null;
  try {
    debugPrint(
      "[FinalFile] share opening system sheet via XFile(cache) jobId=$jobId "
      "(no MediaStore publish)",
    );
    logMobileDownloadPerf(
      stage: "share_prepare_xfile_start",
      durationMs: 0,
      jobId: jobId,
    );
    final prepareSw = Stopwatch()..start();
    final xf = XFile(
      localPath,
      mimeType: desc.mimeType,
      name: desc.shareFileName,
    );
    prepareSw.stop();
    logMobileDownloadPerf(
      stage: "share_prepare_xfile_done",
      durationMs: prepareSw.elapsedMilliseconds,
      jobId: jobId,
      bytes: sizeBytes > 0 ? sizeBytes : null,
    );

    logMobileDownloadPerf(
      stage: "share_native_call_start",
      durationMs: 0,
      jobId: jobId,
      result: "awaiting_share_sheet",
    );
    final nativeSw = Stopwatch()..start();
    final result = await Share.shareXFiles([xf], text: shareText);
    nativeSw.stop();
    logMobileDownloadPerf(
      stage: "share_native_call_return",
      durationMs: nativeSw.elapsedMilliseconds,
      jobId: jobId,
      result: "share_sheet_returned",
    );
    dev.log("saved_media share: ShareResult status=${result.status} raw=$result");
    if (result.status == ShareResultStatus.unavailable) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.savedShareFailedHint)),
      );
    }
  } on PlatformException catch (e, st) {
    dev.log("saved_media share: PlatformException", error: e, stackTrace: st);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.savedShareFailedHint)),
    );
  } catch (e, st) {
    dev.log("saved_media share: failed", error: e, stackTrace: st);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.savedShareFailedHint)),
    );
  }
}
