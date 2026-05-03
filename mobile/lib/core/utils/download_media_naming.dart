import "package:path/path.dart" as p;

import "../models/download_models.dart";

/// Filename extension + MIME helpers for saved downloads (Android share/open).
abstract final class DownloadMediaNaming {
  /// Infer preferred extension from backend filename / MIME (fallback `.mp4`).
  static String extensionForDetail(DownloadDetailResponse detail) {
    final f = detail.file;
    final fn = (f?.filename ?? "").trim();
    var ext = p.extension(fn).toLowerCase();
    if (ext.isNotEmpty && ext.length <= 10 && ext != ".") return ext;

    final mime = (f?.mimeType ?? "").toLowerCase();
    if (mime.contains("audio/mpeg") || mime.contains("mp3")) return ".mp3";
    if (mime.contains("audio/mp4") || mime.contains("m4a") || mime.contains("x-m4a")) return ".m4a";
    if (mime.contains("mpeg")) return ".mp3";
    if (mime.contains("video") || mime.contains("mp4")) return ".mp4";

    return ".mp4";
  }

  static String mimeFromExtension(String extDot) {
    switch (extDot.toLowerCase()) {
      case ".mp4":
        return "video/mp4";
      case ".mp3":
        return "audio/mpeg";
      case ".m4a":
        return "audio/mp4";
      default:
        return "application/octet-stream";
    }
  }

  static String fallbackBasename(String jobId, String extDot) {
    final e = extDot.startsWith(".") ? extDot : ".$extDot";
    return "$jobId$e";
  }
}
