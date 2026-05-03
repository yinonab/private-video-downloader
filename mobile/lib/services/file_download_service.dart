import "dart:io";

import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "../core/models/api_error.dart";
import "../core/models/download_models.dart";
import "../core/network/api_client.dart";
import "../core/storage/local_session.dart";
import "../core/utils/file_utils.dart";

final class FileDownloadService {
  FileDownloadService({required ApiClient api, required LocalSession session}) : _api = api, _session = session;

  final ApiClient _api;
  final LocalSession _session;

  Future<String?> cachedPath(String jobId) => _session.localPathForJob(jobId);

  Future<String> downloadJobMedia({
    required String jobId,
    required DownloadDetailResponse detail,
    void Function(int received, int total)? onProgress,
  }) async {
    final rawName = detail.file?.filename.trim();
    final baseName = FileUtils.sanitizeFileName(
      (rawName == null || rawName.isEmpty) ? "$jobId-media" : rawName,
    );

    final docs = await getApplicationDocumentsDirectory();
    final dirPath = p.join(docs.path, "downloads");
    await Directory(dirPath).create(recursive: true);

    var attempt = 0;
    late String targetPath;
    while (true) {
      targetPath = FileUtils.nextCandidate(dirPath, baseName, attempt);
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

    await _api.downloadFileToDisk(jobId: jobId, absolutePath: targetPath, onProgress: onProgress);
    await _session.rememberDownloadPath(jobId: jobId, absolutePath: targetPath);
    return targetPath;
  }

  Future<void> deleteCached(String jobId) async {
    final path = await _session.localPathForJob(jobId);
    if (path == null || path.isEmpty) return;
    try {
      await File(path).delete();
    } catch (_) {}
    await _session.forgetDownloadPath(jobId);
  }
}
