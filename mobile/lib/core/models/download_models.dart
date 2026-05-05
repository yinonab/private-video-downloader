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

class DownloadItem {
  DownloadItem({
    required this.id,
    required this.status,
    required this.title,
    required this.platform,
    this.thumbnail,
    required this.createdAt,
    required this.progress,
    this.speedText,
    this.etaText,
    this.error,
    this.file,
  });

  factory DownloadItem.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final date = DateTime.tryParse("${m["createdAt"] ?? ""}");
    DownloadFile? fileObj;
    if (m["file"] is Map) {
      fileObj = DownloadFile.fromJson(Map<String, dynamic>.from(m["file"] as Map));
    }
    final prog = m["progress"] is num ? (m["progress"] as num).round() : int.tryParse("${m["progress"] ?? ""}");

    final titleCandidate = "${m["title"] ?? ""}".trim();
    final platformCandidate = "${m["platform"] ?? ""}".trim();
    return DownloadItem(
      id: "${m["id"] ?? ""}",
      status: "${m["status"] ?? ""}".trim().isEmpty ? "unknown" : "${m["status"]}",
      title: titleCandidate,
      platform: platformCandidate,
      thumbnail: m["thumbnail"]?.toString(),
      createdAt: date ?? DateTime.fromMillisecondsSinceEpoch(0),
      progress: prog ?? 0,
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
  final int progress;
  final String? speedText;
  final String? etaText;
  final String? error;
  final DownloadFile? file;

  bool get active => {"queued", "analyzing", "running"}.contains(status);

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
  CreateDownloadRequest({required this.url, required this.format, required this.quality});

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
    return {"url": url.trim(), "format": f, "quality": q};
  }

  final String url;
  final String format;
  final String quality;
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
    required this.progress,
    this.speedText,
    this.etaText,
    this.title,
    this.thumbnail,
    this.error,
    this.file,
  });

  factory DownloadDetailResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final prog = (m["progress"] is num) ? (m["progress"] as num).round() : int.tryParse("${m["progress"] ?? 0}") ?? 0;
    DownloadFile? fileObj;
    if (m["file"] is Map) {
      fileObj = DownloadFile.fromJson(Map<String, dynamic>.from(m["file"] as Map));
    }
    return DownloadDetailResponse(
      id: "${m["id"] ?? ""}",
      status: "${m["status"] ?? ""}",
      progress: prog,
      speedText: m["speedText"]?.toString(),
      etaText: m["etaText"]?.toString(),
      title: m["title"]?.toString(),
      thumbnail: m["thumbnail"]?.toString(),
      error: m["error"]?.toString(),
      file: fileObj,
    );
  }

  bool get terminal => {"done", "failed", "canceled"}.contains(status);

  final String id;
  final String status;
  final int progress;
  final String? speedText;
  final String? etaText;
  final String? title;
  final String? thumbnail;
  final String? error;
  final DownloadFile? file;
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
