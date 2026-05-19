import "../models/api_error.dart";

/// True when the backend binary (download job file, edit output file, etc.) is gone or unknown server-side.
///
/// Call sites decide UX: completed download jobs → redownload sheet; edit outputs → unavailable copy only.
bool isMissingBackendBinaryError(ApiError e) {
  switch (e.code) {
    case "FILE_NOT_FOUND":
    case "JOB_NOT_FOUND":
      return true;
    case "DEVICE_FILE_DOWNLOAD":
      final h = e.httpStatus;
      return h == 404 || h == 410;
    default:
      return false;
  }
}

/// Upload-based Quick Edit source disappeared on the server (user must pick/upload again).
bool isMissingUploadEditSourceError(ApiError e) {
  switch (e.code) {
    case "UPLOAD_NOT_FOUND":
    case "EDIT_UPLOAD_NOT_FOUND":
    case "EDIT_SOURCE_FILE_MISSING":
      return true;
    default:
      return false;
  }
}
