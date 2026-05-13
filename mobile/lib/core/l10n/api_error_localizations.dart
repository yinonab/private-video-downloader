import "../../l10n/app_localizations.dart";
import "../models/api_error.dart";

/// Maps backend error codes to localized UX strings for snackbars and full-screen errors.
String localizedApiErrorMessage(AppLocalizations l10n, ApiError e) {
  switch (e.code) {
    case "MISSING_LINK":
      return l10n.analyzeMissingLink;
    case "UNSUPPORTED_QUALITY":
      return l10n.errorUnsupportedQuality;
    case "BAD_REQUEST":
    case "INVITE_CODE_INVALID":
    case "INVITE_CODE_EXPIRED":
      return l10n.errorBadRequest;
    case "NETWORK":
      return l10n.errorNetwork;
    case "INVALID_URL":
      return l10n.errorInvalidUrl;
    case "UNAUTHORIZED":
    case "DEVICE_NOT_REGISTERED":
      return l10n.errorUnauthorized;
    case "DEVICE_BLOCKED":
      return l10n.errorUnexpected;
    case "RATE_LIMITED":
      return l10n.errorRateLimited;
    case "CONFLICT":
      return l10n.errorConflict;
    case "JOB_NOT_FOUND":
      return l10n.errorJobNotFound;
    case "FILE_NOT_FOUND":
      return l10n.errorFileNotFound;
    case "ANALYZE_FAILED":
      return l10n.errorAnalyzeFailed;
    case "LINKCLIP_ERR_THREADS_UNSUPPORTED":
      return l10n.errorThreadsUnsupported;
    case "LINKCLIP_ERR_PLATFORM_UNSUPPORTED":
      return l10n.errorPlatformUnsupported;
    case "LINKCLIP_ERR_ANALYZE_METADATA_UNAVAILABLE":
      return l10n.errorAnalyzeMetadataUnavailable;
    case "EDIT_JOB_NOT_FOUND":
      return l10n.errorEditJobNotFound;
    case "EDIT_INVALID_SOURCE":
      return l10n.errorEditInvalidSource;
    case "EDIT_FAILED":
      return l10n.errorEditFailed;
    case "DOWNLOAD_FAILED":
      return l10n.downloadJobErrorGeneric;
    case "UNKNOWN":
    case "ERROR":
      return l10n.errorUnexpected;
    default:
      return l10n.errorUnexpected;
  }
}
