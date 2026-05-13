class DownloadFile {
  DownloadFile({required this.filename, this.mimeType, this.sizeBytes, this.downloadRelativePath});

  factory DownloadFile.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    int? bytes;
    if (m["sizeBytes"] is num) bytes = (m["sizeBytes"] as num).round();
    return DownloadFile(
      filename: "${m["filename"] ?? ""}",
      mimeType: m["mimeType"]?.toString(),
      sizeBytes: bytes,
      downloadRelativePath: m["downloadUrl"]?.toString(),
    );
  }

  bool get hasFileHint => filename.isNotEmpty || (downloadRelativePath != null && downloadRelativePath!.trim().isNotEmpty);

  final String filename;
  final String? mimeType;
  final int? sizeBytes;

  /// Relative path `/downloads/id/file` fragment from backend.
  final String? downloadRelativePath;
}

String? _coerceSourceUrl(Map<String, dynamic> m) {
  for (final key in ["sourceUrl", "originalUrl", "inputUrl"]) {
    final v = m[key]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  return null;
}

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.status,
    required this.title,
    required this.platform,
    this.thumbnail,
    required this.createdAt,
    this.processingStage,
    this.progressPercent,
    this.requestedFormat,
    this.requestedQuality,
    this.sourceUrl,
    this.speedText,
    this.etaText,
    this.error,
    this.file,
  });

  static int? _parseOptionalPercent(Map<String, dynamic> m) {
    final raw = m["progressPercent"] ?? m["progress"];
    if (raw == null) return null;
    if (raw is num) return raw.round().clamp(0, 100);
    final p = int.tryParse("$raw");
    return p?.clamp(0, 100);
  }

  factory DownloadItem.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final date = DateTime.tryParse("${m["createdAt"] ?? ""}");
    DownloadFile? fileObj;
    if (m["file"] is Map) {
      fileObj = DownloadFile.fromJson(Map<String, dynamic>.from(m["file"] as Map));
    }
    var prog = _parseOptionalPercent(m);

    final titleCandidate = "${m["title"] ?? ""}".trim();
    final platformCandidate = "${m["platform"] ?? ""}".trim();
    final st = "${m["status"] ?? ""}".trim().isEmpty ? "unknown" : "${m["status"]}";
    final terminal = {"done", "failed", "canceled"}.contains(st);
    if (!terminal && prog != null && prog <= 0) prog = null;
    final stageTrimmed = m["processingStage"]?.toString().trim() ?? "";
    final fmtTrimmed = m["format"]?.toString().trim() ?? "";
    final qualTrimmed = m["quality"]?.toString().trim() ?? "";

    return DownloadItem(
      id: "${m["id"] ?? ""}",
      status: st,
      title: titleCandidate,
      platform: platformCandidate,
      thumbnail: m["thumbnail"]?.toString(),
      createdAt: date ?? DateTime.fromMillisecondsSinceEpoch(0),
      processingStage: stageTrimmed.isEmpty ? null : stageTrimmed,
      progressPercent: prog,
      requestedFormat: fmtTrimmed.isEmpty ? null : fmtTrimmed,
      requestedQuality: qualTrimmed.isEmpty ? null : qualTrimmed,
      sourceUrl: _coerceSourceUrl(m),
      speedText: m["speedText"]?.toString(),
      etaText: m["etaText"]?.toString(),
      error: m["error"]?.toString(),
      file: fileObj,
    );
  }

  final String id;
  final String status;
  final String title;
  final String platform;
  final String? thumbnail;
  final DateTime createdAt;
  final String? processingStage;

  /// Server-reported 0–100, or null when unknown / not meaningful.
  final int? progressPercent;

  /// Canonical download format id (`tiktok_ready`, `best`, …).
  final String? requestedFormat;

  /// Normalized quality token from the server, when provided.
  final String? requestedQuality;

  /// Original submitted URL for this job when returned by the API.
  final String? sourceUrl;
  final String? speedText;
  final String? etaText;
  final String? error;
  final DownloadFile? file;

  bool get active => !{"done", "failed", "canceled"}.contains(status);

  DownloadStatusParsed get statusParsed => DownloadStatusParsed.fromRaw(status);
}

enum DownloadUiStatusLabel { queued, running, done, failed, canceled, unknown }

class DownloadStatusParsed {
  DownloadStatusParsed._(this.label, this.hebrew);

  factory DownloadStatusParsed.fromRaw(String s) {
    switch (s) {
      case "queued":
        return DownloadStatusParsed._(DownloadUiStatusLabel.queued, "בתור");
      case "running":
      case "analyzing":
        return DownloadStatusParsed._(DownloadUiStatusLabel.running, "מוריד…");
      case "done":
        return DownloadStatusParsed._(DownloadUiStatusLabel.done, "ההורדה הושלמה");
      case "failed":
        return DownloadStatusParsed._(DownloadUiStatusLabel.failed, "נכשל");
      case "canceled":
        return DownloadStatusParsed._(DownloadUiStatusLabel.canceled, "בוטל");
      default:
        return DownloadStatusParsed._(DownloadUiStatusLabel.unknown, s.isEmpty ? "לא ידוע" : s);
    }
  }

  final DownloadUiStatusLabel label;
  final String hebrew;
}

class CreateDownloadRequest {
  CreateDownloadRequest({
    required this.url,
    required this.format,
    required this.quality,
    this.forceNew = false,
  });

  /// Removes bidi marks; normalizes case (matches backend [sanitizeQualityToken]).
  static String sanitizeQualityId(String raw) {
    var s = raw.replaceAll(RegExp(r"[\u200e\u200f\u202a-\u202e\u2066-\u2069]"), "");
    s = s.trim().toLowerCase();
    return s;
  }

  Map<String, dynamic> toJson() {
    final f = sanitizeQualityId(format);
    final qRaw = quality.trim().isEmpty ? format : quality;
    final q = sanitizeQualityId(qRaw);
    final map = <String, dynamic>{
      "url": url.trim(),
      "format": f,
      "quality": q,
    };
    if (forceNew) {
      map["forceNew"] = true;
    }
    return map;
  }

  /// For prefs storage — never persists [forceNew].
  CreateDownloadRequest copyWithoutForceNew() =>
      CreateDownloadRequest(url: url, format: format, quality: quality);

  final String url;
  final String format;
  final String quality;
  final bool forceNew;
}

class CreateDownloadResponse {
  CreateDownloadResponse({required this.jobId, required this.status, required this.cached});

  factory CreateDownloadResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final id = "${m["jobId"] ?? m["id"] ?? ""}";
    return CreateDownloadResponse(
      jobId: id,
      status: "${m["status"] ?? ""}",
      cached: m["cached"] == true,
    );
  }

  final String jobId;
  final String status;
  final bool cached;
}

class DownloadDetailResponse {
  DownloadDetailResponse({
    required this.id,
    required this.status,
    this.processingStage,
    this.progressPercent,
    this.requestedFormat,
    this.requestedQuality,
    this.sourceUrl,
    this.speedText,
    this.etaText,
    this.title,
    this.thumbnail,
    this.platform,
    this.error,
    this.file,
    this.createdAt,
  });

  factory DownloadDetailResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final progRaw = m["progressPercent"] ?? m["progress"];
    int? prog;
    if (progRaw != null) {
      if (progRaw is num) {
        prog = progRaw.round().clamp(0, 100);
      } else {
        prog = int.tryParse("$progRaw")?.clamp(0, 100);
      }
    }
    final statusStr = "${m["status"] ?? ""}";
    final terminal = {"done", "failed", "canceled"}.contains(statusStr);
    if (!terminal && prog != null && prog <= 0) prog = null;
    final stageTrimmed = m["processingStage"]?.toString().trim() ?? "";
    final fmtTrimmed = m["format"]?.toString().trim() ?? "";
    final qualTrimmed = m["quality"]?.toString().trim() ?? "";
    DownloadFile? fileObj;
    if (m["file"] is Map) {
      fileObj = DownloadFile.fromJson(Map<String, dynamic>.from(m["file"] as Map));
    }
    final platTrimmed = m["platform"]?.toString().trim() ?? "";
    return DownloadDetailResponse(
      id: "${m["id"] ?? ""}",
      status: "${m["status"] ?? ""}",
      processingStage: stageTrimmed.isEmpty ? null : stageTrimmed,
      progressPercent: prog,
      requestedFormat: fmtTrimmed.isEmpty ? null : fmtTrimmed,
      requestedQuality: qualTrimmed.isEmpty ? null : qualTrimmed,
      sourceUrl: _coerceSourceUrl(m),
      speedText: m["speedText"]?.toString(),
      etaText: m["etaText"]?.toString(),
      title: m["title"]?.toString(),
      thumbnail: m["thumbnail"]?.toString(),
      platform: platTrimmed.isEmpty ? null : platTrimmed,
      error: m["error"]?.toString(),
      file: fileObj,
      createdAt: DateTime.tryParse("${m["createdAt"] ?? ""}"),
    );
  }

  bool get terminal => {"done", "failed", "canceled"}.contains(status);

  final String id;
  final String status;
  final String? processingStage;

  /// Server-reported 0–100, or null when unknown / not meaningful.
  final int? progressPercent;

  /// Canonical download format id (`tiktok_ready`, `best`, …).
  final String? requestedFormat;

  /// Same semantics as [DownloadItem.requestedQuality].
  final String? requestedQuality;

  /// Original submitted URL when returned by the API.
  final String? sourceUrl;
  final String? speedText;
  final String? etaText;
  final String? title;
  final String? thumbnail;

  /// Platform / extractor hint from the server (optional).
  final String? platform;
  final String? error;
  final DownloadFile? file;

  /// Job creation time from server (`createdAt`), when provided — used for Quick Edit retention heuristic.
  final DateTime? createdAt;
}

class DownloadsListResponse {
  DownloadsListResponse({required this.items, required this.total, required this.page, required this.limit});

  factory DownloadsListResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final list = <DownloadItem>[];
    if (m["items"] is List) {
      for (final e in m["items"] as List) {
        if (e is Map) list.add(DownloadItem.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return DownloadsListResponse(
      items: list,
      total: (m["total"] is num) ? (m["total"] as num).round() : int.tryParse("${m["total"] ?? 0}") ?? 0,
      page: (m["page"] is num) ? (m["page"] as num).round() : int.tryParse("${m["page"] ?? 1}") ?? 1,
      limit: (m["limit"] is num) ? (m["limit"] as num).round() : int.tryParse("${m["limit"] ?? 30}") ?? 30,
    );
  }

  final List<DownloadItem> items;
  final int total;
  final int page;
  final int limit;
}
