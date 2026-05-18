/// Identifies how [EditVideoPreview] resolves input bytes (local session file vs network).
sealed class EditVideoPreviewSource {
  const EditVideoPreviewSource();

  /// Bumps when preview must re-initialize the player (new job/upload or local path).
  String get identityTag;
}

final class EditVideoPreviewDownloadSource extends EditVideoPreviewSource {
  const EditVideoPreviewDownloadSource({required this.jobId});

  final String jobId;

  @override
  String get identityTag => "dl:${jobId.trim()}";
}

final class EditVideoPreviewUploadSource extends EditVideoPreviewSource {
  const EditVideoPreviewUploadSource({
    required this.uploadId,
    this.localPreviewPath,
  });

  final String uploadId;
  final String? localPreviewPath;

  @override
  String get identityTag {
    final id = uploadId.trim();
    final lp = localPreviewPath?.trim() ?? "";
    return "up:$id:$lp";
  }
}
