/// How the user chose a local video file for upload editing.
enum LocalVideoPickKind {
  mediaGallery,
  fileBrowser,
}

/// Metadata from [image_picker] / [file_picker] — no in-memory video bytes.
///
/// Readable disk paths are assigned by the picker helpers in `local_video_pickers.dart`.
final class SelectedLocalVideo {
  const SelectedLocalVideo({
    required this.pickKind,
    required this.displayName,
    this.mimeType,
    this.sizeBytes,
    this.filePath,
    this.localPreviewPath,
  });

  final LocalVideoPickKind pickKind;
  final String displayName;
  final String? mimeType;

  /// Length on disk when known (may be omitted by some pickers).
  final int? sizeBytes;

  /// Absolute path when the picker exposes one.
  final String? filePath;

  /// Preferred path for local preview (usually same as [filePath]).
  final String? localPreviewPath;
}
