import "dart:developer" as dev;
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:media_store_plus/media_store_plus.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "../core/config/build_flags.dart";
import "../core/models/api_error.dart";
import "../core/models/download_models.dart";
import "../core/network/api_client.dart";
import "../core/storage/local_session.dart";
import "../core/utils/download_media_naming.dart";
import "../core/utils/download_perf_log.dart";
import "../core/utils/file_utils.dart";

void _downloadDebugPrint(String msg) => downloadDebugPrint(msg);

void _downloadDebugCatch(String context, Object e, StackTrace? st) {
  downloadDebugPrint("catch context=$context type=${e.runtimeType} message=$e");
  if (e is DioException) {
    downloadDebugPrint(
      "DioException dioType=${e.type} responseStatus=${e.response?.statusCode} "
      "cancelTokenCancelled=${e.requestOptions.cancelToken?.isCancelled}",
    );
  }
  if (e is ApiError) {
    downloadDebugPrint(
      "ApiError code=${e.code} httpStatus=${e.httpStatus} localized=${e.localized}",
    );
  }
  if (st != null) {
    downloadDebugStackTrace(context, st);
  }
}

/// Result of saving media locally + optional Android Downloads publish.
final class DownloadSaveOutcome {
  const DownloadSaveOutcome({
    required this.internalPath,
    this.publicUri,
    required this.mediaStorePublished,
  });

  final String internalPath;
  final String? publicUri;
  final bool mediaStorePublished;
}

final class FileDownloadService {
  FileDownloadService({required ApiClient api, required LocalSession session}) : _api = api, _session = session;

  final ApiClient _api;
  final LocalSession _session;

  static const String _downloadFailedHebrew = "הורדת הקובץ למכשיר נכשלה. נסה שוב.";

  Future<String?> cachedPath(String jobId) => _session.localPathForJob(jobId);

  /// In-flight [ensureLocalJobMedia] futures keyed by jobId (dedupe concurrent Save/Share/Open).
  final Map<String, Future<DownloadSaveOutcome>> _ensureInFlight = {};

  /// Returns a valid local final file in **app cache** for [jobId].
  ///
  /// Cache-only: never publishes to MediaStore / public Downloads.
  /// Concurrent callers for the same job share one in-flight transfer.
  Future<DownloadSaveOutcome> ensureLocalJobMedia({
    required String jobId,
    required DownloadDetailResponse detail,
    void Function(int received, int total)? onProgress,
  }) {
    final id = jobId.trim();
    final existing = _ensureInFlight[id];
    if (existing != null) {
      _downloadDebugPrint("ensureLocalJobMedia join in-flight jobId=$id");
      debugPrint("[FinalFile] ensureLocalJobMedia join in-flight jobId=$id");
      return existing;
    }

    final future = _ensureLocalJobMediaBody(
      jobId: id,
      detail: detail,
      onProgress: onProgress,
    );
    _ensureInFlight[id] = future;
    future.whenComplete(() {
      if (identical(_ensureInFlight[id], future)) {
        _ensureInFlight.remove(id);
      }
    });
    return future;
  }

  Future<DownloadSaveOutcome> _ensureLocalJobMediaBody({
    required String jobId,
    required DownloadDetailResponse detail,
    void Function(int received, int total)? onProgress,
  }) async {
    final desc = await _session.savedDownloadForJob(jobId);
    if (desc != null && desc.internalPath.trim().isNotEmpty) {
      final path = desc.internalPath.trim();
      if (!path.startsWith("content:")) {
        final f = File(path);
        if (await f.exists()) {
          final len = await f.length();
          if (len > 0) {
            final published =
                desc.publicUri != null && desc.publicUri!.trim().isNotEmpty;
            debugPrint(
              "[FinalFile] ensureLocalJobMedia result=reused_cache jobId=$jobId "
              "size=$len mediaStorePublished=$published",
            );
            logMobileDownloadPerf(
              stage: "cache_finalize",
              durationMs: 0,
              jobId: jobId,
              bytes: len,
              result: "reused_cache",
            );
            return DownloadSaveOutcome(
              internalPath: path,
              publicUri: desc.publicUri,
              mediaStorePublished: published,
            );
          }
        }
      }
    }

    debugPrint(
      "[FinalFile] ensureLocalJobMedia result=downloaded_to_cache START jobId=$jobId",
    );
    final sw = Stopwatch()..start();
    final outcome = await downloadJobMedia(
      jobId: jobId,
      detail: detail,
      onProgress: onProgress,
    );
    sw.stop();
    var outBytes = 0;
    try {
      outBytes = await File(outcome.internalPath).length();
    } catch (_) {
      outBytes = 0;
    }
    logMobileDownloadPerf(
      stage: "cache_finalize",
      durationMs: sw.elapsedMilliseconds,
      jobId: jobId,
      bytes: outBytes,
      result: "downloaded_to_cache",
      mbps: approxMbps(bytes: outBytes, durationMs: sw.elapsedMilliseconds),
    );
    debugPrint(
      "[FinalFile] ensureLocalJobMedia result=downloaded_to_cache DONE jobId=$jobId "
      "mediaStorePublished=${outcome.mediaStorePublished}",
    );
    return outcome;
  }

  /// Publishes an already-local final file to Android Downloads (MediaStore).
  /// No HTTP transfer. Call only from explicit **Save to device**.
  Future<DownloadSaveOutcome?> publishLocalJobMediaToDevice({required String jobId}) async {
    final sw = Stopwatch()..start();
    final desc = await _session.savedDownloadForJob(jobId);
    if (desc == null) return null;
    final path = desc.internalPath.trim();
    if (path.isEmpty || path.startsWith("content:")) return null;
    final internalFile = File(path);
    if (!await internalFile.exists()) return null;
    final internalLen = await internalFile.length();
    if (internalLen <= 0) return null;

    if (!Platform.isAndroid) {
      return DownloadSaveOutcome(
        internalPath: path,
        publicUri: desc.publicUri,
        mediaStorePublished:
            desc.publicUri != null && desc.publicUri!.trim().isNotEmpty,
      );
    }

    if (desc.publicUri != null && desc.publicUri!.trim().isNotEmpty) {
      debugPrint(
        "[FinalFile] save result=already_published_to_device jobId=$jobId",
      );
      sw.stop();
      logMobileDownloadPerf(
        stage: "save_to_device",
        durationMs: sw.elapsedMilliseconds,
        jobId: jobId,
        bytes: internalLen,
        result: "already_published",
      );
      return DownloadSaveOutcome(
        internalPath: path,
        publicUri: desc.publicUri,
        mediaStorePublished: true,
      );
    }

    final shareName = desc.shareFileName.trim().isNotEmpty
        ? desc.shareFileName.trim()
        : p.basename(path);
    final mime = desc.mimeType.trim().isNotEmpty
        ? desc.mimeType.trim()
        : "application/octet-stream";

    final tmpRoot = await getTemporaryDirectory();
    final exportTmpPath = p.join(tmpRoot.path, shareName);
    await _tryDelete(exportTmpPath);

    try {
      await internalFile.copy(exportTmpPath);
      final exportLen = await File(exportTmpPath).length();
      if (exportLen <= 0 || exportLen != internalLen) {
        await _tryDelete(exportTmpPath);
        _downloadDebugPrint(
          "publishLocalJobMediaToDevice skip invalid export jobId=$jobId",
        );
        return DownloadSaveOutcome(
          internalPath: path,
          publicUri: null,
          mediaStorePublished: false,
        );
      }

      SaveInfo? info;
      try {
        info = await MediaStore().saveFile(
          tempFilePath: exportTmpPath,
          dirType: DirType.download,
          dirName: DirName.download,
        );
      } catch (e, st) {
        _downloadDebugCatch("publishLocalJobMediaToDevice.MediaStore", e, st);
        info = null;
      } finally {
        await _tryDelete(exportTmpPath);
      }

      final uriStr = info?.uri.toString();
      if (info != null && uriStr != null && uriStr.isNotEmpty) {
        final displayName =
            info.name.trim().isNotEmpty ? info.name.trim() : shareName;
        await _session.rememberSavedDownload(
          jobId: jobId,
          internalPath: path,
          publicUri: uriStr,
          shareFileName: displayName,
          mimeType: mime,
          fileSizeBytes: internalLen,
        );
        _downloadDebugPrint(
          "publishLocalJobMediaToDevice success jobId=$jobId (no HTTP re-download)",
        );
        debugPrint(
          "[FinalFile] save result=published_to_device jobId=$jobId",
        );
        sw.stop();
        logMobileDownloadPerf(
          stage: "save_to_device",
          durationMs: sw.elapsedMilliseconds,
          jobId: jobId,
          bytes: internalLen,
          result: "published_to_device",
        );
        return DownloadSaveOutcome(
          internalPath: path,
          publicUri: uriStr,
          mediaStorePublished: true,
        );
      }
    } catch (e, st) {
      _downloadDebugCatch("publishLocalJobMediaToDevice", e, st);
    }

    return DownloadSaveOutcome(
      internalPath: path,
      publicUri: null,
      mediaStorePublished: false,
    );
  }

  Future<void> _tryDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e, st) {
      dev.log("file_download: delete failed path=$path", error: e);
      _downloadDebugCatch("tryDelete path=$path", e, st);
    }
  }

  Future<DownloadSaveOutcome> downloadJobMedia({
    required String jobId,
    required DownloadDetailResponse detail,
    void Function(int received, int total)? onProgress,
  }) async {
    final ext = DownloadMediaNaming.extensionForDetail(detail);
    final rawName = detail.file?.filename.trim();

    String baseDisplay;
    if (rawName != null && rawName.isNotEmpty) {
      var sanitized = FileUtils.sanitizeFileName(rawName);
      if (p.extension(sanitized).isEmpty) {
        sanitized = FileUtils.sanitizeFileName("${p.basenameWithoutExtension(sanitized)}$ext");
      }
      baseDisplay = sanitized;
    } else {
      baseDisplay = FileUtils.sanitizeFileName(DownloadMediaNaming.fallbackBasename(jobId, ext));
    }

    if (!baseDisplay.toLowerCase().endsWith(ext.toLowerCase())) {
      baseDisplay = FileUtils.sanitizeFileName("${p.basenameWithoutExtension(baseDisplay)}$ext");
    }

    final docs = await getApplicationDocumentsDirectory();
    final dirPath = p.join(docs.path, "downloads");
    final tmpDir = p.join(dirPath, "tmp");
    await Directory(dirPath).create(recursive: true);
    await Directory(tmpDir).create(recursive: true);

    var attempt = 0;
    late String targetPath;
    while (true) {
      targetPath = FileUtils.nextCandidate(dirPath, baseDisplay, attempt);
      if (!await File(targetPath).exists()) break;
      attempt++;
      if (attempt > 2000) {
        throw ApiError(
          code: "IO",
          message: "collision",
          hebrewSummary: "לא ניתן לשמור את הקובץ",
        );
      }
    }

    final partPath = p.join(tmpDir, "$jobId.part");
    await _tryDelete(partPath);

    final url = _api.downloadFileUrl(jobId);
    dev.log(
      "file_download: start url=$url jobId=$jobId tempPart=$partPath finalTarget=$targetPath",
    );
    final tokenExists = _session.deviceToken.trim().isNotEmpty;
    _downloadDebugPrint(
      "downloadJobMedia jobId=$jobId baseUrl=${_session.serverUrl.trim()} finalFileUrl=$url "
      "tokenExists=$tokenExists tempPartPath=$partPath finalInternalPath=$targetPath",
    );

    JobFileDownloadResult httpMeta;
    try {
      _downloadDebugPrint("before downloadJobFileToPath jobId=$jobId");
      httpMeta = await _api.downloadJobFileToPath(
        jobId: jobId,
        absolutePath: partPath,
        onReceiveProgress: (received, total) {
          dev.log("file_download: progress received=$received total=$total jobId=$jobId");
          _downloadDebugPrint("progress received=$received total=$total jobId=$jobId");
          onProgress?.call(received, total);
        },
      );
    } catch (e, st) {
      await _tryDelete(partPath);
      dev.log("file_download: download threw jobId=$jobId", error: e);
      _downloadDebugCatch("downloadJobMedia.http jobId=$jobId", e, st);
      rethrow;
    }

    dev.log(
      "file_download: http done status=${httpMeta.statusCode} contentLengthHeader=${httpMeta.contentLength} url=${httpMeta.url}",
    );
    _downloadDebugPrint(
      "HTTP file GET completed (service) status=${httpMeta.statusCode} contentLengthHeader=${httpMeta.contentLength}",
    );

    if (httpMeta.statusCode != 200) {
      await _tryDelete(partPath);
      throw ApiError(
        code: "DEVICE_FILE_DOWNLOAD",
        message: "HTTP ${httpMeta.statusCode}",
        hebrewSummary: _downloadFailedHebrew,
        httpStatus: httpMeta.statusCode,
      );
    }

    final partFile = File(partPath);
    final partExists = await partFile.exists();
    final partLen = partExists ? await partFile.length() : 0;
    dev.log("file_download: temp exists=$partExists bytes=$partLen path=$partPath");
    _downloadDebugPrint("temp exists=$partExists tempSize=$partLen tempPath=$partPath");

    if (!partExists || partLen <= 0) {
      await _tryDelete(partPath);
      throw ApiError(code: "DEVICE_FILE_DOWNLOAD", message: "empty_part", hebrewSummary: _downloadFailedHebrew);
    }

    final expected = httpMeta.contentLength;
    if (expected != null && expected > 0 && partLen != expected) {
      await _tryDelete(partPath);
      dev.log("file_download: size mismatch expected=$expected actual=$partLen");
      throw ApiError(code: "DEVICE_FILE_DOWNLOAD", message: "length_mismatch", hebrewSummary: _downloadFailedHebrew);
    }

    try {
      try {
        await partFile.rename(targetPath);
      } catch (e, st) {
        dev.log("file_download: rename failed, copy instead", error: e);
        _downloadDebugCatch("partFile.rename fallback to copy", e, st);
        await partFile.copy(targetPath);
        await partFile.delete();
      }
    } catch (e, st) {
      await _tryDelete(partPath);
      await _tryDelete(targetPath);
      dev.log("file_download: finalize move failed", error: e);
      _downloadDebugCatch("finalizeMove jobId=$jobId", e, st);
      throw ApiError(code: "DEVICE_FILE_DOWNLOAD", message: "move_failed", hebrewSummary: _downloadFailedHebrew);
    }

    final internalFile = File(targetPath);
    final internalExists = await internalFile.exists();
    final internalLen = internalExists ? await internalFile.length() : 0;
    dev.log(
      "file_download: final internal exists=$internalExists bytes=$internalLen path=$targetPath",
    );
    _downloadDebugPrint(
      "final internalPath=$targetPath exists=$internalExists finalSize=$internalLen",
    );

    if (!internalExists || internalLen <= 0) {
      await _tryDelete(targetPath);
      throw ApiError(code: "IO", message: "empty_final", hebrewSummary: _downloadFailedHebrew);
    }

    if (expected != null && expected > 0 && internalLen != expected) {
      await _tryDelete(targetPath);
      dev.log("file_download: final size mismatch expected=$expected actual=$internalLen");
      throw ApiError(code: "DEVICE_FILE_DOWNLOAD", message: "final_length_mismatch", hebrewSummary: _downloadFailedHebrew);
    }

    final mime = DownloadMediaNaming.mimeFromExtension(ext);
    final shareName = p.basename(targetPath);

    // Cache-only: never publish to MediaStore here. Explicit Save uses
    // [publishLocalJobMediaToDevice].
    await _session.rememberSavedDownload(
      jobId: jobId,
      internalPath: targetPath,
      publicUri: null,
      shareFileName: shareName,
      mimeType: mime,
      fileSizeBytes: internalLen,
    );
    debugPrint(
      "[FinalFile] downloadJobMedia result=downloaded_to_cache jobId=$jobId size=$internalLen",
    );
    _downloadDebugPrint(
      "descriptor stored cache-only jobId=$jobId internalPath=$targetPath "
      "shareFileName=$shareName mimeType=$mime fileSizeBytes=$internalLen",
    );
    return DownloadSaveOutcome(
      internalPath: targetPath,
      publicUri: null,
      mediaStorePublished: false,
    );
  }

  /// Downloads edited MP4 into app documents (`edits/`). Does not register a download-job descriptor.
  Future<String> downloadEditedOutput({
    required String editJobId,
    String? suggestedBasename,
    void Function(int received, int total)? onProgress,
  }) async {
    var base = suggestedBasename?.trim();
    if (base == null || base.isEmpty) {
      base = "edit_$editJobId.mp4";
    }
    base = FileUtils.sanitizeFileName(base);
    final lower = base.toLowerCase();
    final String ext;
    if (lower.endsWith(".mp3")) {
      ext = ".mp3";
    } else if (lower.endsWith(".mp4")) {
      ext = ".mp4";
    } else if (lower.endsWith(".m4a")) {
      ext = ".m4a";
    } else {
      ext = ".mp4";
    }
    if (!lower.endsWith(ext)) {
      base = FileUtils.sanitizeFileName("${p.basenameWithoutExtension(base)}$ext");
    }

    final docs = await getApplicationDocumentsDirectory();
    final dirPath = p.join(docs.path, "edits");
    final tmpDir = p.join(dirPath, "tmp");
    await Directory(dirPath).create(recursive: true);
    await Directory(tmpDir).create(recursive: true);

    var attempt = 0;
    late String targetPath;
    while (true) {
      targetPath = FileUtils.nextCandidate(dirPath, base, attempt);
      if (!await File(targetPath).exists()) break;
      attempt++;
      if (attempt > 2000) {
        throw ApiError(code: "IO", message: "collision", hebrewSummary: "לא ניתן לשמור את הקובץ");
      }
    }

    final partPath = p.join(tmpDir, "$editJobId.part");
    await _tryDelete(partPath);

    JobFileDownloadResult httpMeta;
    try {
      httpMeta = await _api.downloadEditFileToPath(
        editJobId: editJobId,
        absolutePath: partPath,
        onReceiveProgress: onProgress,
      );
    } catch (e, st) {
      await _tryDelete(partPath);
      dev.log("file_download: edit download threw editJobId=$editJobId", error: e);
      _downloadDebugCatch("downloadEditedOutput.http editJobId=$editJobId", e, st);
      rethrow;
    }

    if (httpMeta.statusCode != 200) {
      await _tryDelete(partPath);
      throw ApiError(
        code: "DEVICE_FILE_DOWNLOAD",
        message: "HTTP ${httpMeta.statusCode}",
        hebrewSummary: _downloadFailedHebrew,
        httpStatus: httpMeta.statusCode,
      );
    }

    final partFile = File(partPath);
    final partLen = await partFile.exists() ? await partFile.length() : 0;
    if (partLen <= 0) {
      await _tryDelete(partPath);
      throw ApiError(code: "DEVICE_FILE_DOWNLOAD", message: "empty_part", hebrewSummary: _downloadFailedHebrew);
    }

    final expected = httpMeta.contentLength;
    if (expected != null && expected > 0 && partLen != expected) {
      await _tryDelete(partPath);
      throw ApiError(code: "DEVICE_FILE_DOWNLOAD", message: "length_mismatch", hebrewSummary: _downloadFailedHebrew);
    }

    try {
      try {
        await partFile.rename(targetPath);
      } catch (e, st) {
        dev.log("file_download: edit rename failed, copy instead", error: e);
        _downloadDebugCatch("edit partFile.rename", e, st);
        await partFile.copy(targetPath);
        await partFile.delete();
      }
    } catch (e, st) {
      await _tryDelete(partPath);
      await _tryDelete(targetPath);
      dev.log("file_download: edit finalize failed", error: e);
      _downloadDebugCatch("downloadEditedOutput.finalize editJobId=$editJobId", e, st);
      throw ApiError(code: "DEVICE_FILE_DOWNLOAD", message: "move_failed", hebrewSummary: _downloadFailedHebrew);
    }

    final internalLen = await File(targetPath).length();
    if (internalLen <= 0) {
      await _tryDelete(targetPath);
      throw ApiError(code: "IO", message: "empty_final", hebrewSummary: _downloadFailedHebrew);
    }

    return targetPath;
  }

  /// Publishes an existing MP4 on disk to Android public Downloads via MediaStore (no session descriptor).
  Future<bool> publishMp4ToAndroidDownloads({
    required String internalAbsolutePath,
    required String shareDisplayName,
  }) async {
    if (!Platform.isAndroid) return false;

    final internalFile = File(internalAbsolutePath);
    final internalExists = await internalFile.exists();
    final internalLen = internalExists ? await internalFile.length() : 0;
    if (!internalExists || internalLen <= 0) return false;

    final shareName = FileUtils.sanitizeFileName(shareDisplayName.trim().isEmpty ? p.basename(internalAbsolutePath) : shareDisplayName.trim());

    final tmpRoot = await getTemporaryDirectory();
    final exportTmpPath = p.join(tmpRoot.path, shareName);
    await _tryDelete(exportTmpPath);

    final bytes = await internalFile.readAsBytes();
    if (bytes.isEmpty || bytes.length != internalLen) return false;

    final exportFile = File(exportTmpPath);
    await exportFile.writeAsBytes(bytes, flush: true);
    final exportLen = await exportFile.length();
    if (exportLen <= 0 || exportLen != bytes.length) {
      await _tryDelete(exportTmpPath);
      return false;
    }

    SaveInfo? info;
    try {
      info = await MediaStore().saveFile(
        tempFilePath: exportTmpPath,
        dirType: DirType.download,
        dirName: DirName.download,
      );
    } catch (e, st) {
      dev.log("file_download: edit MediaStore.saveFile error", error: e, stackTrace: st);
      _downloadDebugCatch("publishMp4ToAndroidDownloads.saveFile", e, st);
      info = null;
    }

    try {
      await exportFile.delete();
    } catch (e, st) {
      _downloadDebugCatch("publishMp4ToAndroidDownloads cleanup tmp", e, st);
    }

    final uriStr = info?.uri.toString();
    return info != null && uriStr != null && uriStr.isNotEmpty;
  }

  Future<void> deleteCached(String jobId) async {
    final desc = await _session.savedDownloadForJob(jobId);
    if (desc == null) return;

    try {
      final ip = desc.internalPath.trim();
      if (ip.isNotEmpty && !ip.startsWith("content:")) {
        final f = File(ip);
        if (await f.exists()) await f.delete();
      }
      final pu = desc.publicUri?.trim();
      if (Platform.isAndroid && pu != null && pu.isNotEmpty && pu.startsWith("content:")) {
        await MediaStore().deleteFileUsingUri(uriString: pu);
      }
    } catch (e, st) {
      dev.log("file_download: deleteCached error jobId=$jobId", error: e);
      _downloadDebugCatch("deleteCached jobId=$jobId", e, st);
    }
    await _session.forgetDownloadPath(jobId);
  }
}
