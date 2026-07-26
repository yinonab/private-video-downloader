import "package:flutter/foundation.dart";

/// Grep-friendly mobile download timing (safe fields only — no URLs/tokens/paths).
void logMobileDownloadPerf({
  required String stage,
  required int durationMs,
  String? jobId,
  String? platform,
  String? quality,
  String? result,
  int? bytes,
  int? contentLength,
  double? mbps,
}) {
  if (!kDebugMode) return;
  final parts = <String>[
    "[Perf][MobileDownload] stage=$stage",
    "durationMs=$durationMs",
  ];
  if (jobId != null && jobId.isNotEmpty) parts.add("jobId=$jobId");
  if (platform != null && platform.isNotEmpty) parts.add("platform=$platform");
  if (quality != null && quality.isNotEmpty) parts.add("quality=$quality");
  if (result != null) parts.add("result=$result");
  if (bytes != null) parts.add("bytes=$bytes");
  if (contentLength != null) parts.add("contentLength=$contentLength");
  if (mbps != null) parts.add("mbps=${mbps.toStringAsFixed(2)}");
  debugPrint(parts.join(" "));
}

double? approxMbps({required int bytes, required int durationMs}) {
  if (durationMs <= 0 || bytes <= 0) return null;
  return (bytes * 8) / (durationMs / 1000) / 1e6;
}
