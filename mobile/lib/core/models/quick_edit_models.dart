import "download_models.dart";

/// Quick Edit from download **detail** (status screen) — same rules as [downloadItemEligibleForQuickEdit].
bool downloadDetailEligibleForQuickEdit(DownloadDetailResponse d) {
  if (d.status != "done") return false;
  if (d.file?.hasFileHint != true) return false;
  final fmt = (d.requestedFormat ?? "").trim().toLowerCase();
  if (fmt == "audio_mp3") return false;
  final mime = d.file?.mimeType?.toLowerCase().trim() ?? "";
  if (mime.startsWith("audio/")) return false;
  return true;
}
// --- API payloads (match backend/src/modules/edit/edit.schemas.ts) ---

final class CreateEditJobRequest {
  CreateEditJobRequest({
    required this.sourceDownloadJobId,
    required this.operations,
  });

  final String sourceDownloadJobId;
  final List<Map<String, dynamic>> operations;

  Map<String, dynamic> toJson() => {
        "sourceDownloadJobId": sourceDownloadJobId,
        "operations": operations,
      };
}

final class CreateEditJobResponse {
  CreateEditJobResponse({required this.editJobId, required this.status});

  factory CreateEditJobResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    return CreateEditJobResponse(
      editJobId: "${m["editJobId"] ?? m["id"] ?? ""}",
      status: "${m["status"] ?? ""}",
    );
  }

  final String editJobId;
  final String status;
}

final class RetryEditJobResponse {
  RetryEditJobResponse({required this.editJobId, required this.status});

  factory RetryEditJobResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    return RetryEditJobResponse(
      editJobId: "${m["editJobId"] ?? ""}",
      status: "${m["status"] ?? ""}",
    );
  }

  final String editJobId;
  final String status;
}

final class EditJobDetailResponse {
  EditJobDetailResponse({
    required this.id,
    required this.status,
    this.stage,
    this.progressPercent,
    this.sourceDownloadJobId,
    this.outputReady,
    this.outputFilename,
    this.outputMimeType,
    this.outputSizeBytes,
    this.errorCode,
    this.errorMessage,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.fileUrl,
  });

  factory EditJobDetailResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    int? pct;
    final rawP = m["progressPercent"];
    if (rawP is num) pct = rawP.round().clamp(0, 100);
    int? outSz;
    final rawSz = m["outputSizeBytes"];
    if (rawSz is num) outSz = rawSz.round();
    return EditJobDetailResponse(
      id: "${m["id"] ?? ""}",
      status: "${m["status"] ?? ""}",
      stage: m["stage"]?.toString(),
      progressPercent: pct,
      sourceDownloadJobId: m["sourceDownloadJobId"]?.toString(),
      outputReady: m["outputReady"] == true,
      outputFilename: m["outputFilename"]?.toString(),
      outputMimeType: m["outputMimeType"]?.toString(),
      outputSizeBytes: outSz,
      errorCode: m["errorCode"]?.toString(),
      errorMessage: m["errorMessage"]?.toString(),
      createdAt: m["createdAt"]?.toString(),
      updatedAt: m["updatedAt"]?.toString(),
      completedAt: m["completedAt"]?.toString(),
      fileUrl: m["fileUrl"]?.toString(),
    );
  }

  final String id;
  final String status;
  final String? stage;
  final int? progressPercent;
  final String? sourceDownloadJobId;
  final bool? outputReady;
  final String? outputFilename;
  final String? outputMimeType;
  final int? outputSizeBytes;
  final String? errorCode;
  final String? errorMessage;
  final String? createdAt;
  final String? updatedAt;
  final String? completedAt;

  /// Relative `/edits/:id/file` when server sets it.
  final String? fileUrl;

  bool get isTerminalDone => status == "done";
  bool get isTerminalFailed => status == "failed";
}

// --- UI enums → API ---

enum QuickEditCropAspect {
  original,
  nineSixteen,
  oneOne,
  sixteenNine,
  fourFive,
}

extension QuickEditCropAspectApi on QuickEditCropAspect {
  /// Backend `aspectRatio` string (omit operation when original).
  String get apiValue => switch (this) {
        QuickEditCropAspect.original => "original",
        QuickEditCropAspect.nineSixteen => "9:16",
        QuickEditCropAspect.oneOne => "1:1",
        QuickEditCropAspect.sixteenNine => "16:9",
        QuickEditCropAspect.fourFive => "4:5",
      };
}

enum QuickEditCompressPreset {
  original,
  social,
  small,
}

extension QuickEditCompressPresetApi on QuickEditCompressPreset {
  String get apiValue => switch (this) {
        QuickEditCompressPreset.original => "original",
        QuickEditCompressPreset.social => "social",
        QuickEditCompressPreset.small => "small",
      };
}

/// Whether the list screen row may offer Quick Edit (server-side source exists).
bool downloadItemEligibleForQuickEdit(DownloadItem item) {
  if (item.status != "done") return false;
  if (item.file?.hasFileHint != true) return false;
  final fmt = (item.requestedFormat ?? "").trim().toLowerCase();
  if (fmt == "audio_mp3") return false;
  final mime = item.file?.mimeType?.toLowerCase().trim() ?? "";
  if (mime.startsWith("audio/")) return false;
  return true;
}

/// Builds POST `/edits` operations array; empty if nothing changed from defaults.
List<Map<String, dynamic>> buildQuickEditOperations({
  required double videoDurationSec,
  required double trimStartSec,
  required double trimEndSec,
  required QuickEditCropAspect cropAspect,
  required bool mute,
  required QuickEditCompressPreset compressPreset,
}) {
  final dur = videoDurationSec <= 0 ? 1.0 : videoDurationSec;
  const eps = 0.05;
  final ops = <Map<String, dynamic>>[];

  if (trimStartSec > eps || trimEndSec < dur - eps) {
    final start = trimStartSec.clamp(0.0, dur - eps);
    var end = trimEndSec.clamp(start + eps, dur);
    ops.add({
      "type": "trim",
      "startSec": start,
      "endSec": end,
    });
  }

  if (cropAspect != QuickEditCropAspect.original) {
    ops.add({
      "type": "crop",
      "aspectRatio": cropAspect.apiValue,
      "mode": "centerCrop",
    });
  }

  if (mute) {
    ops.add({"type": "mute"});
  }

  if (compressPreset != QuickEditCompressPreset.original) {
    ops.add({
      "type": "compress",
      "preset": compressPreset.apiValue,
    });
  }

  return ops;
}

bool quickEditHasChanges({
  required double videoDurationSec,
  required double trimStartSec,
  required double trimEndSec,
  required QuickEditCropAspect cropAspect,
  required bool mute,
  required QuickEditCompressPreset compressPreset,
}) {
  final ops = buildQuickEditOperations(
    videoDurationSec: videoDurationSec,
    trimStartSec: trimStartSec,
    trimEndSec: trimEndSec,
    cropAspect: cropAspect,
    mute: mute,
    compressPreset: compressPreset,
  );
  return ops.isNotEmpty;
}
