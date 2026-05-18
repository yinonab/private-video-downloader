/// Identifies where Quick Edit reads source video from: a completed download job or uploaded media.
///
/// Phase C3 will construct [EditVideoSourceRef.upload] after picker + [ApiClient.uploadVideo].
/// Phase C2 keeps only programmatic entry; no home/picker wiring yet.
enum EditVideoSourceKind {
  download,
  upload,
}

/// Exactly one of [sourceDownloadJobId] or [sourceUploadId] is non-null, matching backend XOR rule.
final class EditVideoSourceRef {
  EditVideoSourceRef._({
    required this.kind,
    this.sourceDownloadJobId,
    this.sourceUploadId,
    this.localPreviewPath,
    this.title,
    this.thumbnailUrl,
    this.durationSeconds,
    this.width,
    this.height,
    this.videoDurationSec,
  }) : assert(
          ((sourceDownloadJobId != null &&
                      sourceDownloadJobId.trim().isNotEmpty) ^
              (sourceUploadId != null &&
                  sourceUploadId.trim().isNotEmpty)),
          "Exactly one source id must be set",
        );

  factory EditVideoSourceRef.download({
    required String sourceDownloadJobId,
    double? videoDurationSec,
    String? title,
    String? thumbnailUrl,
  }) {
    return EditVideoSourceRef._(
      kind: EditVideoSourceKind.download,
      sourceDownloadJobId: sourceDownloadJobId.trim(),
      title: title,
      thumbnailUrl: thumbnailUrl,
      videoDurationSec: videoDurationSec,
    );
  }

  factory EditVideoSourceRef.upload({
    required String sourceUploadId,
    String? localPreviewPath,
    String? title,
    String? thumbnailUrl,
    int? durationSeconds,
    int? width,
    int? height,
    double? videoDurationSec,
  }) {
    final lp = localPreviewPath?.trim();
    return EditVideoSourceRef._(
      kind: EditVideoSourceKind.upload,
      sourceUploadId: sourceUploadId.trim(),
      localPreviewPath: (lp == null || lp.isEmpty) ? null : lp,
      title: title,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      width: width,
      height: height,
      videoDurationSec: videoDurationSec,
    );
  }

  final EditVideoSourceKind kind;

  final String? sourceDownloadJobId;
  final String? sourceUploadId;

  final String? localPreviewPath;
  final String? title;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final int? width;
  final int? height;

  /// Hint duration (seconds) from caller or metadata.
  final double? videoDurationSec;

  /// Value for [Widget.key] on preview subtree when the backing media identity changes.
  String get previewIdentityKey => switch (kind) {
        EditVideoSourceKind.download => "dl:${sourceDownloadJobId!}",
        EditVideoSourceKind.upload =>
          "up:${sourceUploadId!}:${localPreviewPath ?? ""}",
      };
}
