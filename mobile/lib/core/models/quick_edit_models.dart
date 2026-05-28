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
  CreateEditJobRequest._({
    required this.operations,
    this.sourceDownloadJobId,
    this.sourceUploadId,
  }) : assert(
          (sourceDownloadJobId != null) ^ (sourceUploadId != null),
          "Exactly one of sourceDownloadJobId or sourceUploadId must be set",
        );

  factory CreateEditJobRequest.download({
    required String sourceDownloadJobId,
    required List<Map<String, dynamic>> operations,
  }) =>
      CreateEditJobRequest._(
        operations: operations,
        sourceDownloadJobId: sourceDownloadJobId,
      );

  factory CreateEditJobRequest.upload({
    required String sourceUploadId,
    required List<Map<String, dynamic>> operations,
  }) =>
      CreateEditJobRequest._(
        operations: operations,
        sourceUploadId: sourceUploadId,
      );

  final String? sourceDownloadJobId;
  final String? sourceUploadId;
  final List<Map<String, dynamic>> operations;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{"operations": operations};
    final dl = sourceDownloadJobId?.trim();
    final up = sourceUploadId?.trim();
    if (dl != null && dl.isNotEmpty) {
      map["sourceDownloadJobId"] = dl;
    }
    if (up != null && up.isNotEmpty) {
      map["sourceUploadId"] = up;
    }
    return map;
  }
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

/// Single editable captions draft cue from `POST /edits/captions/draft` (V2.4A+).
final class CaptionDraftSegment {
  CaptionDraftSegment({
    required this.id,
    required this.startSec,
    required this.endSec,
    required this.text,
    required this.originalStartSec,
    required this.originalEndSec,
  });

  final String id;
  final double startSec;
  final double endSec;
  final String text;
  /// Whisper draft start before user timing edits (V2.4B reset).
  final double originalStartSec;
  /// Whisper draft end before user timing edits (V2.4B reset).
  final double originalEndSec;

  bool get hasTimingAdjustment =>
      (startSec - originalStartSec).abs() > 1e-6 ||
      (endSec - originalEndSec).abs() > 1e-6;

  CaptionDraftSegment copyWith({
    String? id,
    double? startSec,
    double? endSec,
    String? text,
    double? originalStartSec,
    double? originalEndSec,
  }) =>
      CaptionDraftSegment(
        id: id ?? this.id,
        startSec: startSec ?? this.startSec,
        endSec: endSec ?? this.endSec,
        text: text ?? this.text,
        originalStartSec: originalStartSec ?? this.originalStartSec,
        originalEndSec: originalEndSec ?? this.originalEndSec,
      );

  factory CaptionDraftSegment.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    var sid = "${m["id"] ?? ""}".trim();
    if (sid.isEmpty) sid = "seg";
    double n(dynamic v) {
      final x = v is num ? v.toDouble() : double.tryParse("$v") ?? 0;
      return x;
    }

    final start = n(m["startSec"]);
    final end = n(m["endSec"]);
    return CaptionDraftSegment(
      id: sid,
      startSec: start,
      endSec: end,
      text: "${m["text"] ?? ""}",
      originalStartSec: start,
      originalEndSec: end,
    );
  }

  Map<String, dynamic> toCaptionsBurnJson() => {
        "startSec": startSec,
        "endSec": endSec,
        "text": text.trim(),
      };
}

final class CaptionDraftResponse {
  CaptionDraftResponse({
    required this.segments,
    required this.durationSec,
    required this.language,
  });

  factory CaptionDraftResponse.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    final raw = m["segments"];
    final items = <CaptionDraftSegment>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          items.add(CaptionDraftSegment.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    final ds = (m["durationSec"] is num)
        ? (m["durationSec"] as num).toDouble()
        : double.tryParse("${m["durationSec"]}") ?? 0;

    return CaptionDraftResponse(
      segments: items,
      durationSec: ds,
      language: "${m["language"] ?? "auto"}",
    );
  }

  final List<CaptionDraftSegment> segments;
  final double durationSec;
  final String language;
}

final class GenerateCaptionsDraftRequest {
  GenerateCaptionsDraftRequest._({
    required this.operations,
    this.sourceDownloadJobId,
    this.sourceUploadId,
  }) : assert(
          (sourceDownloadJobId != null) ^ (sourceUploadId != null),
          "Exactly one of sourceDownloadJobId or sourceUploadId must be set",
        );

  factory GenerateCaptionsDraftRequest.download({
    required String sourceDownloadJobId,
    required List<Map<String, dynamic>> operations,
  }) =>
      GenerateCaptionsDraftRequest._(
        operations: operations,
        sourceDownloadJobId: sourceDownloadJobId.trim(),
      );

  factory GenerateCaptionsDraftRequest.upload({
    required String sourceUploadId,
    required List<Map<String, dynamic>> operations,
  }) =>
      GenerateCaptionsDraftRequest._(
        operations: operations,
        sourceUploadId: sourceUploadId.trim(),
      );

  final String? sourceDownloadJobId;
  final String? sourceUploadId;
  final List<Map<String, dynamic>> operations;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{"operations": operations};
    final dl = sourceDownloadJobId?.trim();
    final up = sourceUploadId?.trim();
    if (dl != null && dl.isNotEmpty) map["sourceDownloadJobId"] = dl;
    if (up != null && up.isNotEmpty) map["sourceUploadId"] = up;
    return map;
  }
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
    this.sourceUploadId,
    this.sourceKind,
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
      sourceUploadId: m["sourceUploadId"]?.toString(),
      sourceKind: m["sourceKind"]?.toString(),
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

  /// Present when the edit source is device-uploaded media (`UploadedMedia`).
  final String? sourceUploadId;

  /// Backend hint: `"download"` | `"upload"` when provided (Phase B+).
  final String? sourceKind;

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

enum QuickEditFormatMode {
  fill,
  fitBlur;

  /// Backend `mode` (`format` operation).
  String get apiMode => switch (this) {
        QuickEditFormatMode.fill => "fill",
        QuickEditFormatMode.fitBlur => "fit_blur",
      };
}

/// Clockwise rotation; **0°** omits the `rotate` operation in the edit payload.
enum QuickEditRotation {
  deg0,
  deg90,
  deg180,
  deg270;

  /// Labels like **0°** — same EN/HE.
  String get chipLabel => switch (this) {
        QuickEditRotation.deg0 => "0°",
        QuickEditRotation.deg90 => "90°",
        QuickEditRotation.deg180 => "180°",
        QuickEditRotation.deg270 => "270°",
      };

  int? get apiDegrees => switch (this) {
        QuickEditRotation.deg0 => null,
        QuickEditRotation.deg90 => 90,
        QuickEditRotation.deg180 => 180,
        QuickEditRotation.deg270 => 270,
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

enum QuickEditSpeedFactor {
  x05,
  x1,
  x125,
  x15,
  x2;

  /// Labels like **0.5x** — same in EN/HE per product spec.
  String get chipLabel => switch (this) {
        QuickEditSpeedFactor.x05 => "0.5x",
        QuickEditSpeedFactor.x1 => "1x",
        QuickEditSpeedFactor.x125 => "1.25x",
        QuickEditSpeedFactor.x15 => "1.5x",
        QuickEditSpeedFactor.x2 => "2x",
      };

  /// Omit from API when **1×** (no ffmpeg speed op).
  double? get apiFactor => switch (this) {
        QuickEditSpeedFactor.x1 => null,
        QuickEditSpeedFactor.x05 => 0.5,
        QuickEditSpeedFactor.x125 => 1.25,
        QuickEditSpeedFactor.x15 => 1.5,
        QuickEditSpeedFactor.x2 => 2.0,
      };
}

/// Captions styling **V1.5** (backend `captions` op schema).
enum QuickEditCaptionsStylePreset { clean, bold, darkBox }

extension QuickEditCaptionsStylePresetApi on QuickEditCaptionsStylePreset {
  String get apiValue => switch (this) {
        QuickEditCaptionsStylePreset.clean => "clean",
        QuickEditCaptionsStylePreset.bold => "bold",
        QuickEditCaptionsStylePreset.darkBox => "dark_box",
      };
}

enum QuickEditCaptionFontSize { extraSmall, small, medium, large }

extension QuickEditCaptionFontSizeApi on QuickEditCaptionFontSize {
  String get apiValue => switch (this) {
        QuickEditCaptionFontSize.extraSmall => "extra_small",
        QuickEditCaptionFontSize.small => "small",
        QuickEditCaptionFontSize.medium => "medium",
        QuickEditCaptionFontSize.large => "large",
      };
}

enum QuickEditCaptionPosition { top, bottom }

extension QuickEditCaptionPositionApi on QuickEditCaptionPosition {
  String get apiValue => switch (this) {
        QuickEditCaptionPosition.top => "top",
        QuickEditCaptionPosition.bottom => "bottom",
      };
}

enum QuickEditCaptionColor { white, yellow }

extension QuickEditCaptionColorApi on QuickEditCaptionColor {
  String get apiValue => switch (this) {
        QuickEditCaptionColor.white => "white",
        QuickEditCaptionColor.yellow => "yellow",
      };
}

/// Ready-made captions look (**V2.3**) — UX only; API still sends concrete style/size/position/color/offsets.
///
/// **`custom`** means the current combo does not match any built-in preset.
enum QuickEditCaptionPreset {
  custom,
  minimal,
  social,
  boldYellow,
  darkBox,
  topClean,
}

/// Field snapshot applied when user picks a built-in preset.
final class CaptionPresetFields {
  const CaptionPresetFields({
    required this.fontSize,
    required this.position,
    required this.color,
    required this.style,
    required this.offsetX,
    required this.offsetY,
  });

  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;
  final QuickEditCaptionsStylePreset style;
  final int offsetX;
  final int offsetY;

  bool matches({
    required QuickEditCaptionFontSize fontSize,
    required QuickEditCaptionPosition position,
    required QuickEditCaptionColor color,
    required QuickEditCaptionsStylePreset style,
    required int offsetX,
    required int offsetY,
  }) =>
      this.fontSize == fontSize &&
      this.position == position &&
      this.color == color &&
      this.style == style &&
      this.offsetX == offsetX &&
      this.offsetY == offsetY;
}

CaptionPresetFields? captionPresetRecipe(QuickEditCaptionPreset preset) {
  switch (preset) {
    case QuickEditCaptionPreset.custom:
      return null;
    case QuickEditCaptionPreset.minimal:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.extraSmall,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.clean,
        offsetX: 0,
        offsetY: 0,
      );
    case QuickEditCaptionPreset.social:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.small,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.bold,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.boldYellow:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.small,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.yellow,
        style: QuickEditCaptionsStylePreset.bold,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.darkBox:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.small,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.darkBox,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.topClean:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.extraSmall,
        position: QuickEditCaptionPosition.top,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.clean,
        offsetX: 0,
        offsetY: 0,
      );
  }
}

const List<QuickEditCaptionPreset> kQuickEditCaptionBuiltInPresetsOrdered = [
  QuickEditCaptionPreset.minimal,
  QuickEditCaptionPreset.social,
  QuickEditCaptionPreset.boldYellow,
  QuickEditCaptionPreset.darkBox,
  QuickEditCaptionPreset.topClean,
];

/// Which named preset matches the current controls, or [QuickEditCaptionPreset.custom].
QuickEditCaptionPreset inferQuickEditCaptionPreset({
  required QuickEditCaptionFontSize fontSize,
  required QuickEditCaptionPosition position,
  required QuickEditCaptionColor color,
  required QuickEditCaptionsStylePreset style,
  required int offsetX,
  required int offsetY,
}) {
  for (final p in kQuickEditCaptionBuiltInPresetsOrdered) {
    final r = captionPresetRecipe(p)!;
    if (r.matches(
      fontSize: fontSize,
      position: position,
      color: color,
      style: style,
      offsetX: offsetX,
      offsetY: offsetY,
    )) {
      return p;
    }
  }
  return QuickEditCaptionPreset.custom;
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

/// Captions fine-position step and API clamp (ASS PlayRes units — see backend `assSubtitles.service.ts`).
const int kQuickEditCaptionsOffsetFineStep = 20;
const int kQuickEditCaptionsOffsetXMin = -240;
const int kQuickEditCaptionsOffsetXMax = 240;
const int kQuickEditCaptionsOffsetYMin = -180;
const int kQuickEditCaptionsOffsetYMax = 180;

/// Same PlayRes dimensions as ASS burn-in normalization (Flutter preview scales from these).
const double kCaptionAssPlayResX = 960;
const double kCaptionAssPlayResY = 540;

/// Trim + speed only — mirrors final caption timeline basis for draft transcription.
List<Map<String, dynamic>> buildCaptionsDraftRequestOperations({
  required double videoDurationSec,
  required double trimStartSec,
  required double trimEndSec,
  required QuickEditSpeedFactor speedFactor,
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

  final sp = speedFactor.apiFactor;
  if (sp != null) {
    ops.add({
      "type": "speed",
      "factor": sp,
    });
  }

  return ops;
}

int clampQuickEditCaptionOffsetX(int v) =>
    v.clamp(kQuickEditCaptionsOffsetXMin, kQuickEditCaptionsOffsetXMax).toInt();
int clampQuickEditCaptionOffsetY(int v) =>
    v.clamp(kQuickEditCaptionsOffsetYMin, kQuickEditCaptionsOffsetYMax).toInt();

/// Maps UI selections → `captions` operation (must match backend [edit.schemas]).
Map<String, dynamic> quickEditCaptionsV22Operation({
  required QuickEditCaptionsStylePreset style,
  required QuickEditCaptionFontSize fontSize,
  required QuickEditCaptionPosition position,
  required QuickEditCaptionColor color,
  required int captionsOffsetX,
  required int captionsOffsetY,
}) =>
    {
      "type": "captions",
      "mode": "auto",
      "language": "auto",
      "burnIn": true,
      "style": style.apiValue,
      "fontSize": fontSize.apiValue,
      "position": position.apiValue,
      "color": color.apiValue,
      "offsetX": clampQuickEditCaptionOffsetX(captionsOffsetX),
      "offsetY": clampQuickEditCaptionOffsetY(captionsOffsetY),
    };

/// `captions.mode=segments` — server skips OpenAI transcription (V2.4A).
Map<String, dynamic> quickEditCaptionsSegmentsV24Operation({
  required List<CaptionDraftSegment> segments,
  required QuickEditCaptionsStylePreset style,
  required QuickEditCaptionFontSize fontSize,
  required QuickEditCaptionPosition position,
  required QuickEditCaptionColor color,
  required int captionsOffsetX,
  required int captionsOffsetY,
}) =>
    {
      "type": "captions",
      "mode": "segments",
      "language": "auto",
      "burnIn": true,
      "style": style.apiValue,
      "fontSize": fontSize.apiValue,
      "position": position.apiValue,
      "color": color.apiValue,
      "offsetX": clampQuickEditCaptionOffsetX(captionsOffsetX),
      "offsetY": clampQuickEditCaptionOffsetY(captionsOffsetY),
      "segments": segments.map((s) => s.toCaptionsBurnJson()).toList(),
    };

/// Builds POST `/edits` operations array; empty if nothing changed from defaults.
List<Map<String, dynamic>> buildQuickEditOperations({
  required double videoDurationSec,
  required double trimStartSec,
  required double trimEndSec,
  required QuickEditCropAspect cropAspect,
  required QuickEditFormatMode formatFitMode,
  required QuickEditRotation rotation,
  required QuickEditSpeedFactor speedFactor,
  required bool captionsAutoEnabled,
  QuickEditCaptionsStylePreset captionsStyle = QuickEditCaptionsStylePreset.clean,
  QuickEditCaptionFontSize captionsFontSize = QuickEditCaptionFontSize.medium,
  QuickEditCaptionPosition captionsPosition = QuickEditCaptionPosition.bottom,
  QuickEditCaptionColor captionsColor = QuickEditCaptionColor.white,
  int captionsOffsetX = 0,
  int captionsOffsetY = 0,
  List<CaptionDraftSegment>? captionsDraftForBurn,
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

  final rotDeg = rotation.apiDegrees;
  if (rotDeg != null) {
    ops.add({
      "type": "rotate",
      "degrees": rotDeg,
    });
  }

  if (cropAspect != QuickEditCropAspect.original) {
    ops.add({
      "type": "format",
      "aspectRatio": cropAspect.apiValue,
      "mode": formatFitMode.apiMode,
    });
  }

  final sp = speedFactor.apiFactor;
  if (sp != null) {
    ops.add({
      "type": "speed",
      "factor": sp,
    });
  }

  if (captionsAutoEnabled) {
    if (captionsDraftForBurn != null && captionsDraftForBurn.isNotEmpty) {
      ops.add(quickEditCaptionsSegmentsV24Operation(
        segments: captionsDraftForBurn,
        style: captionsStyle,
        fontSize: captionsFontSize,
        position: captionsPosition,
        color: captionsColor,
        captionsOffsetX: captionsOffsetX,
        captionsOffsetY: captionsOffsetY,
      ));
    } else {
      ops.add(quickEditCaptionsV22Operation(
        style: captionsStyle,
        fontSize: captionsFontSize,
        position: captionsPosition,
        color: captionsColor,
        captionsOffsetX: captionsOffsetX,
        captionsOffsetY: captionsOffsetY,
      ));
    }
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
  required QuickEditFormatMode formatFitMode,
  required QuickEditRotation rotation,
  required QuickEditSpeedFactor speedFactor,
  required bool captionsAutoEnabled,
  QuickEditCaptionsStylePreset captionsStyle = QuickEditCaptionsStylePreset.clean,
  QuickEditCaptionFontSize captionsFontSize = QuickEditCaptionFontSize.medium,
  QuickEditCaptionPosition captionsPosition = QuickEditCaptionPosition.bottom,
  QuickEditCaptionColor captionsColor = QuickEditCaptionColor.white,
  int captionsOffsetX = 0,
  int captionsOffsetY = 0,
  required bool mute,
  required QuickEditCompressPreset compressPreset,
}) {
  final ops = buildQuickEditOperations(
    videoDurationSec: videoDurationSec,
    trimStartSec: trimStartSec,
    trimEndSec: trimEndSec,
    cropAspect: cropAspect,
    formatFitMode: formatFitMode,
    rotation: rotation,
    speedFactor: speedFactor,
    captionsAutoEnabled: captionsAutoEnabled,
    captionsStyle: captionsStyle,
    captionsFontSize: captionsFontSize,
    captionsPosition: captionsPosition,
    captionsColor: captionsColor,
    captionsOffsetX: captionsOffsetX,
    captionsOffsetY: captionsOffsetY,
    captionsDraftForBurn: null,
    mute: mute,
    compressPreset: compressPreset,
  );
  return ops.isNotEmpty;
}
