/// Client-side limits aligned with backend (`MAX_LOCAL_VIDEO_UPLOAD_MB`, duration cap).
/// Used from Phase C3+ (picker / pre-checks); not wired to UI in C1.
abstract final class LocalVideoUploadLimits {
  static const int maxLocalVideoUploadMb = 175;
  static const int maxLocalVideoUploadBytes = maxLocalVideoUploadMb * 1024 * 1024;
  static const int maxLocalVideoDurationSeconds = 420;
}
