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
  bool? cacheValid,
  bool? cacheHit,
  int? formatCount,
  int? qualityCount,
  bool? thumbnailPresent,
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
  if (cacheValid != null) parts.add("cacheValid=$cacheValid");
  if (cacheHit != null) parts.add("cacheHit=$cacheHit");
  if (formatCount != null) parts.add("formatCount=$formatCount");
  if (qualityCount != null) parts.add("qualityCount=$qualityCount");
  if (thumbnailPresent != null) parts.add("thumbnailPresent=$thumbnailPresent");
  debugPrint(parts.join(" "));
}

double? approxMbps({required int bytes, required int durationMs}) {
  if (durationMs <= 0 || bytes <= 0) return null;
  return (bytes * 8) / (durationMs / 1000) / 1e6;
}
