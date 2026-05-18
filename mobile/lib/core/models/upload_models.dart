// API models for `POST /uploads/videos` (Phase A backend).

int? _parseSizeBytes(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s);
}

int? _parseNullableInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  return int.tryParse(raw.toString());
}

final class UploadVideoResponse {
  const UploadVideoResponse({
    required this.uploadId,
    this.kind,
    this.filename,
    this.mimeType,
    this.sizeBytes,
    this.durationSeconds,
    this.width,
    this.height,
    this.thumbnailUrl,
  });

  factory UploadVideoResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    return UploadVideoResponse(
      uploadId: "${m["uploadId"] ?? ""}",
      kind: m["kind"]?.toString(),
      filename: m["filename"]?.toString(),
      mimeType: m["mimeType"]?.toString(),
      sizeBytes: _parseSizeBytes(m["sizeBytes"]),
      durationSeconds: _parseNullableInt(m["durationSeconds"]),
      width: _parseNullableInt(m["width"]),
      height: _parseNullableInt(m["height"]),
      thumbnailUrl: m["thumbnailUrl"]?.toString(),
    );
  }

  final String uploadId;
  final String? kind;
  final String? filename;
  final String? mimeType;

  /// Parsed from JSON number or numeric string.
  final int? sizeBytes;

  final int? durationSeconds;
  final int? width;
  final int? height;

  /// Relative path e.g. `/uploads/<id>/thumbnail`.
  final String? thumbnailUrl;
}
