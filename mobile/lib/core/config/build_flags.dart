import "dart:io" show SocketException;

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";

import "../models/api_error.dart";

/// Production API URL baked into release APK via:
/// `flutter build apk --release --dart-define=API_BASE_URL=https://your-service.onrender.com`
const String kApiBaseUrlFromDefine = String.fromEnvironment("API_BASE_URL", defaultValue: "");

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
