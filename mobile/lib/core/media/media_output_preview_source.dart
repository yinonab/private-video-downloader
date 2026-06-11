import "dart:io";

/// Resolved visual for a saved/exported media item (outside the in-editor preview).
///
/// Priority: output thumbnail JPEG → frame from local output video → source URL → placeholder.
enum MediaOutputPreviewKind {
  localThumbnail,
  localVideoFrame,
  remoteUrl,
  placeholder,
}

final class ResolvedMediaOutputPreview {
  const ResolvedMediaOutputPreview({
    required this.kind,
    this.localThumbnailPath,
    this.localVideoPath,
    this.remoteThumbnailUrl,
  });

  final MediaOutputPreviewKind kind;
  final String? localThumbnailPath;
  final String? localVideoPath;
  final String? remoteThumbnailUrl;

  bool get hasLocalThumbnail =>
      localThumbnailPath != null && localThumbnailPath!.trim().isNotEmpty;

  bool get hasLocalVideo =>
      localVideoPath != null && localVideoPath!.trim().isNotEmpty;

  bool get hasRemoteUrl =>
      remoteThumbnailUrl != null && remoteThumbnailUrl!.trim().isNotEmpty;
}

/// Picks the best preview source for a completed edit/download output.
Future<ResolvedMediaOutputPreview> resolveMediaOutputPreview({
  String? outputThumbnailPath,
  String? outputVideoPath,
  String? sourceThumbnailUrl,
}) async {
  final thumb = outputThumbnailPath?.trim();
  if (thumb != null && thumb.isNotEmpty && await File(thumb).exists()) {
    return ResolvedMediaOutputPreview(
      kind: MediaOutputPreviewKind.localThumbnail,
      localThumbnailPath: thumb,
    );
  }

  final video = outputVideoPath?.trim();
  if (video != null &&
      video.isNotEmpty &&
      !video.toLowerCase().endsWith(".mp3") &&
      await File(video).exists()) {
    return ResolvedMediaOutputPreview(
      kind: MediaOutputPreviewKind.localVideoFrame,
      localVideoPath: video,
    );
  }

  final remote = sourceThumbnailUrl?.trim();
  if (remote != null && remote.isNotEmpty) {
    return ResolvedMediaOutputPreview(
      kind: MediaOutputPreviewKind.remoteUrl,
      remoteThumbnailUrl: remote,
    );
  }

  return const ResolvedMediaOutputPreview(kind: MediaOutputPreviewKind.placeholder);
}
