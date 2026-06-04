/// Persisted metadata for an edited MP4 saved on-device (app documents `edits/`).
/// Does not duplicate video bytes — references [localFilePath] only.
final class LocalEditHistoryItem {
  const LocalEditHistoryItem({
    required this.editJobId,
    required this.localFilePath,
    required this.title,
    required this.sourceKind,
    required this.savedAt,
    this.completedAtIso,
    this.sizeBytes,
    this.durationSeconds,
    this.width,
    this.height,
    this.originalSourceTitle,
    this.sourceDisplayFilename,
    this.platform,
    this.thumbnailPath,
    this.publishedToPublicDownloads = false,
    this.outputMediaKind,
  });

  factory LocalEditHistoryItem.fromJson(Map<String, dynamic> m) {
    final savedRaw = m["savedAtMillis"];
    final savedMillis = savedRaw is num ? savedRaw.round() : int.tryParse("$savedRaw") ?? 0;
    return LocalEditHistoryItem(
      editJobId: "${m["editJobId"] ?? ""}",
      localFilePath: "${m["localFilePath"] ?? ""}",
      title: "${m["title"] ?? ""}",
      sourceKind: "${m["sourceKind"] ?? "unknown"}",
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedMillis, isUtc: false),
      completedAtIso: m["completedAtIso"]?.toString(),
      sizeBytes: _parseInt(m["sizeBytes"]),
      durationSeconds: _parseInt(m["durationSeconds"]),
      width: _parseInt(m["width"]),
      height: _parseInt(m["height"]),
      originalSourceTitle: m["originalSourceTitle"]?.toString(),
      sourceDisplayFilename: m["sourceDisplayFilename"]?.toString(),
      platform: m["platform"]?.toString(),
      thumbnailPath: m["thumbnailPath"]?.toString(),
      publishedToPublicDownloads: m["publishedToPublicDownloads"] == true,
      outputMediaKind: m["outputMediaKind"]?.toString(),
    );
  }

  final String editJobId;
  final String localFilePath;

  /// Basename or similar reference for the edited output file (may be a UUID).
  final String title;

  /// `"download"` | `"upload"` | `"unknown"`
  final String sourceKind;
  final DateTime savedAt;
  final String? completedAtIso;
  final int? sizeBytes;
  final int? durationSeconds;
  final int? width;
  final int? height;

  /// Download / link title when editing from a completed download.
  final String? originalSourceTitle;

  /// Original picked/upload filename when editing from device upload.
  final String? sourceDisplayFilename;
  final String? platform;

  /// Cached JPEG under app support (`edit_thumbnails/`), if generated.
  final String? thumbnailPath;

  /// User ran Save to public Downloads from the edit done screen.
  final bool publishedToPublicDownloads;

  /// `"audio"` for MP3 edits; `"video"` or null for MP4.
  final String? outputMediaKind;

  bool get isAudioOutput =>
      outputMediaKind == "audio" ||
      localFilePath.toLowerCase().endsWith(".mp3") ||
      title.toLowerCase().endsWith(".mp3");

  Map<String, dynamic> toJson() => {
        "editJobId": editJobId,
        "localFilePath": localFilePath,
        "title": title,
        "sourceKind": sourceKind,
        "savedAtMillis": savedAt.millisecondsSinceEpoch,
        if (completedAtIso != null) "completedAtIso": completedAtIso,
        if (sizeBytes != null) "sizeBytes": sizeBytes,
        if (durationSeconds != null) "durationSeconds": durationSeconds,
        if (width != null) "width": width,
        if (height != null) "height": height,
        if (originalSourceTitle != null) "originalSourceTitle": originalSourceTitle,
        if (sourceDisplayFilename != null) "sourceDisplayFilename": sourceDisplayFilename,
        if (platform != null) "platform": platform,
        if (thumbnailPath != null) "thumbnailPath": thumbnailPath,
        "publishedToPublicDownloads": publishedToPublicDownloads,
        if (outputMediaKind != null) "outputMediaKind": outputMediaKind,
      };

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }
}
