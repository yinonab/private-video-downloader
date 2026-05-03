import "package:path/path.dart" as p;

/// Safe filename for Android storage.
abstract final class FileUtils {
  static String sanitizeFileName(String raw) {
    var s = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), "_").trim();
    if (s.isEmpty) return "download.bin";
    if (s.length > 160) {
      final ext = p.extension(s);
      final base = p.basenameWithoutExtension(s);
      s = "${base.substring(0, 120)}$ext";
    }
    return s;
  }

  /// Build next non-colliding filename in [directory] (caller checks existence with dart:io).
  static String nextCandidate(String directory, String sanitizedName, int attempt) {
    if (attempt <= 0) return p.join(directory, sanitizedName);
    final ext = p.extension(sanitizedName);
    final base = p.basenameWithoutExtension(sanitizedName);
    final name = ext.isEmpty ? "${base}_$attempt" : "${base}_$attempt$ext";
    return p.join(directory, name);
  }
}
