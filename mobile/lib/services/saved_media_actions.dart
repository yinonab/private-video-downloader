import "dart:developer" as dev;
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:open_filex/open_filex.dart";
import "package:share_plus/share_plus.dart";

import "../core/storage/local_session.dart";

Future<bool> validateSavedDownload(LocalSession session, String jobId) async {
  final desc = await session.savedDownloadForJob(jobId);
  if (desc == null || desc.internalPath.trim().isEmpty) {
    dev.log("saved_media: missing descriptor jobId=$jobId");
    return false;
  }
  final path = desc.internalPath.trim();
  if (path.startsWith("content:")) {
    dev.log("saved_media: unexpected content internal ref jobId=$jobId");
    return false;
  }
  final f = File(path);
  final exists = await f.exists();
  final len = exists ? await f.length() : 0;
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
  final messenger = ScaffoldMessenger.of(context);
  final desc = await session.savedDownloadForJob(jobId);
  if (desc == null || desc.internalPath.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text("יש להוריד את הקובץ תחילה")));
    return;
  }
  final localPath = desc.internalPath.trim();
  dev.log(
    "saved_media open: internal=$localPath publicUri=${desc.publicUri} name=${desc.shareFileName} mime=${desc.mimeType}",
  );
  if (!await validateSavedDownload(session, jobId)) {
    messenger.showSnackBar(const SnackBar(content: Text("לא ניתן לפתוח את הקובץ")));
    return;
  }
  try {
    final r = await OpenFilex.open(localPath);
    dev.log("saved_media open: OpenFilex result type=${r.type} message=${r.message}");
    if (r.type != ResultType.done) {
      messenger.showSnackBar(const SnackBar(content: Text("לא ניתן לפתוח את הקובץ")));
    }
  } catch (e, st) {
    dev.log("saved_media open: exception", error: e, stackTrace: st);
    messenger.showSnackBar(const SnackBar(content: Text("לא ניתן לפתוח את הקובץ")));
  }
}

Future<void> shareSavedDownload({
  required BuildContext context,
  required LocalSession session,
  required String jobId,
  String? title,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final desc = await session.savedDownloadForJob(jobId);
  if (desc == null || desc.internalPath.isEmpty) {
    messenger.showSnackBar(const SnackBar(content: Text("יש להוריד את הקובץ תחילה")));
    return;
  }
  final localPath = desc.internalPath.trim();
  dev.log(
    "saved_media share: internal=$localPath name=${desc.shareFileName} mime=${desc.mimeType}",
  );
  if (!await validateSavedDownload(session, jobId)) {
    messenger.showSnackBar(const SnackBar(content: Text("לא ניתן לשתף את הקובץ")));
    return;
  }
  final shareText = (title != null && title.trim().isNotEmpty) ? title.trim() : null;
  try {
    final xf = XFile(
      localPath,
      mimeType: desc.mimeType,
      name: desc.shareFileName,
    );
    final result = await Share.shareXFiles([xf], text: shareText);
    dev.log("saved_media share: ShareResult status=${result.status} raw=$result");
    if (result.status == ShareResultStatus.unavailable) {
      messenger.showSnackBar(
        const SnackBar(content: Text("השיתוף נכשל. נסה לפתוח את הקובץ או לשתף מאפליקציית הקבצים.")),
      );
    }
  } on PlatformException catch (e, st) {
    dev.log("saved_media share: PlatformException", error: e, stackTrace: st);
    messenger.showSnackBar(
      const SnackBar(content: Text("השיתוף נכשל. נסה לפתוח את הקובץ או לשתף מאפליקציית הקבצים.")),
    );
  } catch (e, st) {
    dev.log("saved_media share: failed", error: e, stackTrace: st);
    messenger.showSnackBar(
      const SnackBar(content: Text("השיתוף נכשל. נסה לפתוח את הקובץ או לשתף מאפליקציית הקבצים.")),
    );
  }
}
