import "dart:io" show SocketException;

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "../models/api_error.dart";
import "../utils/url_utils.dart";

/// Default API host when neither `--dart-define=API_BASE_URL=…` nor a valid saved URL exists (fresh install).
const String kDefaultProductionApiBaseUrl = "https://api.linkclip.win";

/// Optional compile-time override:
/// `flutter build apk --release --dart-define=API_BASE_URL=https://your-service.onrender.com`
///
/// When empty, release builds still resolve to [kDefaultProductionApiBaseUrl] via [kEffectiveCompileDefaultApiBaseUrl].
const String kApiBaseUrlFromDefine = String.fromEnvironment("API_BASE_URL", defaultValue: "");

/// Normalized base URL for non-custom mode: `--dart-define` wins, otherwise packaged production default.
String get kEffectiveCompileDefaultApiBaseUrl {
  final baked = kApiBaseUrlFromDefine.trim();
  if (baked.isNotEmpty) {
    return UrlUtils.normalizeServerBase(baked);
  }
  return UrlUtils.normalizeServerBase(kDefaultProductionApiBaseUrl);
}

/// Enable verbose `### DOWNLOAD_DEBUG ###` logs (default off for production).
const bool kDownloadDebugLogs = bool.fromEnvironment("DOWNLOAD_DEBUG_LOGS", defaultValue: false);

void downloadDebugPrint(String message) {
  if (!kDownloadDebugLogs) return;
  debugPrint("### DOWNLOAD_DEBUG ### $message");
}

void downloadDebugStackTrace(String label, StackTrace stackTrace) {
  if (!kDownloadDebugLogs) return;
  debugPrint("### DOWNLOAD_DEBUG ### stackTrace ($label)\n$stackTrace");
}

void shareDebugPrint(String message) {
  debugPrint("### SHARE_DEBUG ### $message");
}

/// Temporary registration/bootstrap diagnostics (always on until removed).
void regDebugPrint(String message) {
  debugPrint("### REG_DEBUG ### $message");
}

void regDebugLogRegistrationFailure(Object e, StackTrace stackTrace) {
  regDebugPrint("register failed type=${e.runtimeType}");
  regDebugPrint("error message=$e");
  if (e is ApiError) {
    regDebugPrint(
      "ApiError code=${e.code} httpStatus=${e.httpStatus} details=${e.details}",
    );
  }
  if (e is DioException) {
    regDebugPrint("DioException type=${e.type}");
    regDebugPrint("DioException response status=${e.response?.statusCode}");
    regDebugPrint("DioException response body=${e.response?.data}");
    final cause = e.error;
    if (cause is SocketException) {
      regDebugPrint("SocketException=$cause");
    }
  }
  regDebugPrint("stack=$stackTrace");
}
