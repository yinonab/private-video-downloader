import "download_models.dart";

bool _downloadFormatIsAudio(String? requestedFormat, String? mimeType) {
  final fmt = (requestedFormat ?? "").trim().toLowerCase();
  if (fmt == "audio_mp3" || fmt == "audio") return true;
  final mime = mimeType?.toLowerCase().trim() ?? "";
  return mime.startsWith("audio/");
}

/// Done download with audio-only media (e.g. MP3).
bool downloadItemIsAudioOnly(DownloadItem item) {
  if (item.status != "done") return false;
  if (item.file?.hasFileHint != true) return false;
  return _downloadFormatIsAudio(item.requestedFormat, item.file?.mimeType);
}

bool downloadDetailIsAudioOnly(DownloadDetailResponse d) {
  if (d.status != "done") return false;
  if (d.file?.hasFileHint != true) return false;
  return _downloadFormatIsAudio(d.requestedFormat, d.file?.mimeType);
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

/// Optional word-level timing on a draft/burn segment (V3.3).
final class CaptionDraftWord {
  const CaptionDraftWord({
    required this.startSec,
    required this.endSec,
    required this.text,
  });

  final double startSec;
  final double endSec;
  final String text;

  factory CaptionDraftWord.fromJson(Map<String, dynamic>? j) {
    final m = Map<String, dynamic>.from(j ?? {});
    double n(dynamic v) {
      final x = v is num ? v.toDouble() : double.tryParse("$v") ?? 0;
      return x;
    }

    return CaptionDraftWord(
      startSec: n(m["startSec"]),
      endSec: n(m["endSec"]),
      text: "${m["text"] ?? ""}".trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        "startSec": startSec,
        "endSec": endSec,
        "text": text,
      };
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
    this.words,
  });

  final String id;
  final double startSec;
  final double endSec;
  final String text;
  /// Whisper draft start before user timing edits (V2.4B reset).
  final double originalStartSec;
  /// Whisper draft end before user timing edits (V2.4B reset).
  final double originalEndSec;
  final List<CaptionDraftWord>? words;

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
    List<CaptionDraftWord>? words,
  }) =>
      CaptionDraftSegment(
        id: id ?? this.id,
        startSec: startSec ?? this.startSec,
        endSec: endSec ?? this.endSec,
        text: text ?? this.text,
        originalStartSec: originalStartSec ?? this.originalStartSec,
        originalEndSec: originalEndSec ?? this.originalEndSec,
        words: words ?? this.words,
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
    final wordsRaw = m["words"];
    final words = <CaptionDraftWord>[];
    if (wordsRaw is List) {
      for (final e in wordsRaw) {
        if (e is Map) {
          final w = CaptionDraftWord.fromJson(Map<String, dynamic>.from(e));
          if (w.text.isNotEmpty && w.endSec > w.startSec) {
            words.add(w);
          }
        }
      }
    }
    return CaptionDraftSegment(
      id: sid,
      startSec: start,
      endSec: end,
      text: "${m["text"] ?? ""}",
      originalStartSec: start,
      originalEndSec: end,
      words: words.isEmpty ? null : words,
    );
  }

  Map<String, dynamic> toCaptionsBurnJson() {
    final out = <String, dynamic>{
      "startSec": startSec,
      "endSec": endSec,
      "text": text.trim(),
    };
    final w = words;
    if (w != null && w.isNotEmpty) {
      out["words"] = w.map((e) => e.toJson()).toList();
    }
    return out;
  }
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

/// Captions styling **V1.5+ / V3.2** (backend `captions` op schema).
enum QuickEditCaptionsStylePreset {
  clean,
  bold,
  darkBox,
  cleanPro,
  boldSocial,
  yellowHeadline,
  darkBubble,
  highlightBox,
}

extension QuickEditCaptionsStylePresetApi on QuickEditCaptionsStylePreset {
  String get apiValue => switch (this) {
        QuickEditCaptionsStylePreset.clean => "clean",
        QuickEditCaptionsStylePreset.bold => "bold",
        QuickEditCaptionsStylePreset.darkBox => "dark_box",
        QuickEditCaptionsStylePreset.cleanPro => "clean_pro",
        QuickEditCaptionsStylePreset.boldSocial => "bold_social",
        QuickEditCaptionsStylePreset.yellowHeadline => "yellow_headline",
        QuickEditCaptionsStylePreset.darkBubble => "dark_bubble",
        QuickEditCaptionsStylePreset.highlightBox => "highlight_box",
      };
}

enum QuickEditCaptionFontSize {
  extraSmall,
  small,
  medium,
  large,
  xLarge,
  xxLarge,
}

extension QuickEditCaptionFontSizeApi on QuickEditCaptionFontSize {
  String get apiValue => switch (this) {
        QuickEditCaptionFontSize.extraSmall => "extra_small",
        QuickEditCaptionFontSize.small => "small",
        QuickEditCaptionFontSize.medium => "medium",
        QuickEditCaptionFontSize.large => "large",
        QuickEditCaptionFontSize.xLarge => "x_large",
        QuickEditCaptionFontSize.xxLarge => "xx_large",
      };
}

enum QuickEditCaptionPosition { top, bottom }

extension QuickEditCaptionPositionApi on QuickEditCaptionPosition {
  String get apiValue => switch (this) {
        QuickEditCaptionPosition.top => "top",
        QuickEditCaptionPosition.bottom => "bottom",
      };
}

enum QuickEditCaptionColor { white, yellow, purple, mint, pink, black }

extension QuickEditCaptionColorApi on QuickEditCaptionColor {
  String get apiValue => switch (this) {
        QuickEditCaptionColor.white => "white",
        QuickEditCaptionColor.yellow => "yellow",
        QuickEditCaptionColor.purple => "purple",
        QuickEditCaptionColor.mint => "mint",
        QuickEditCaptionColor.pink => "pink",
        QuickEditCaptionColor.black => "black",
      };
}

enum QuickEditCaptionBoxShape { rectangle, rounded, pill }

extension QuickEditCaptionBoxShapeApi on QuickEditCaptionBoxShape {
  String get apiValue => switch (this) {
        QuickEditCaptionBoxShape.rectangle => "rectangle",
        QuickEditCaptionBoxShape.rounded => "rounded",
        QuickEditCaptionBoxShape.pill => "pill",
      };
}

enum QuickEditCaptionFontFamily {
  defaultFamily,
  heebo,
  rubik,
  assistant,
  notoSansHebrew,
}

/// Current spoken-word highlight for burned captions (V3.3).
enum QuickEditCaptionWordHighlight {
  none,
  color,
  box,
}

extension QuickEditCaptionWordHighlightApi on QuickEditCaptionWordHighlight {
  String get apiValue => switch (this) {
        QuickEditCaptionWordHighlight.none => "none",
        QuickEditCaptionWordHighlight.color => "color",
        QuickEditCaptionWordHighlight.box => "box",
      };
}

extension QuickEditCaptionFontFamilyApi on QuickEditCaptionFontFamily {
  String get apiValue => switch (this) {
        QuickEditCaptionFontFamily.defaultFamily => "default",
        QuickEditCaptionFontFamily.heebo => "heebo",
        QuickEditCaptionFontFamily.rubik => "rubik",
        QuickEditCaptionFontFamily.assistant => "assistant",
        QuickEditCaptionFontFamily.notoSansHebrew => "noto_sans_hebrew",
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
  creatorHighlight,
  newsHeadline,
  pinkPop,
  yellowViral,
  cleanFocus,
}

/// Snapshot returned from [CaptionLookEditorScreen] (UI-only; same fields as edit state).
final class CaptionLookSnapshot {
  const CaptionLookSnapshot({
    required this.style,
    required this.fontSize,
    required this.fontFamily,
    required this.position,
    required this.color,
    required this.wordHighlight,
    required this.offsetX,
    required this.offsetY,
    this.normalTextColor,
    this.activeTextColor,
    this.boxColor,
    this.boxShape = QuickEditCaptionBoxShape.pill,
  });

  final QuickEditCaptionsStylePreset style;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionFontFamily fontFamily;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;
  final QuickEditCaptionWordHighlight wordHighlight;
  final int offsetX;
  final int offsetY;
  final QuickEditCaptionColor? normalTextColor;
  final QuickEditCaptionColor? activeTextColor;
  final QuickEditCaptionColor? boxColor;
  final QuickEditCaptionBoxShape boxShape;
}

/// Field snapshot applied when user picks a built-in preset.
final class CaptionPresetFields {
  const CaptionPresetFields({
    required this.fontSize,
    required this.fontFamily,
    required this.position,
    required this.color,
    required this.style,
    required this.wordHighlight,
    required this.offsetX,
    required this.offsetY,
    this.normalTextColor,
    this.activeTextColor,
    this.boxColor,
    this.boxShape = QuickEditCaptionBoxShape.pill,
  });

  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionFontFamily fontFamily;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;
  final QuickEditCaptionsStylePreset style;
  final QuickEditCaptionWordHighlight wordHighlight;
  final int offsetX;
  final int offsetY;
  final QuickEditCaptionColor? normalTextColor;
  final QuickEditCaptionColor? activeTextColor;
  final QuickEditCaptionColor? boxColor;
  final QuickEditCaptionBoxShape boxShape;

  bool matches({
    required QuickEditCaptionFontSize fontSize,
    required QuickEditCaptionFontFamily fontFamily,
    required QuickEditCaptionPosition position,
    required QuickEditCaptionColor color,
    required QuickEditCaptionsStylePreset style,
    required QuickEditCaptionWordHighlight wordHighlight,
    required int offsetX,
    required int offsetY,
    required QuickEditCaptionColor effectiveNormalTextColor,
    required QuickEditCaptionColor effectiveActiveTextColor,
    required QuickEditCaptionColor effectiveBoxColor,
    required QuickEditCaptionBoxShape boxShape,
  }) =>
      this.fontSize == fontSize &&
      this.fontFamily == fontFamily &&
      this.position == position &&
      this.color == color &&
      this.style == style &&
      this.wordHighlight == wordHighlight &&
      this.offsetX == offsetX &&
      this.offsetY == offsetY &&
      (normalTextColor ?? color) == effectiveNormalTextColor &&
      (activeTextColor ?? _defaultActiveForPreset(this)) == effectiveActiveTextColor &&
      (boxColor ?? _defaultBoxForPreset(this)) == effectiveBoxColor &&
      this.boxShape == boxShape;
}

QuickEditCaptionColor _defaultActiveForPreset(CaptionPresetFields p) {
  if (p.wordHighlight == QuickEditCaptionWordHighlight.box) {
    final box = p.boxColor ?? _defaultBoxForPreset(p);
    return switch (box) {
      QuickEditCaptionColor.yellow ||
      QuickEditCaptionColor.mint ||
      QuickEditCaptionColor.white ||
      QuickEditCaptionColor.pink =>
        QuickEditCaptionColor.black,
      _ => QuickEditCaptionColor.white,
    };
  }
  if (p.wordHighlight == QuickEditCaptionWordHighlight.color) {
    final normal = p.normalTextColor ?? p.color;
    return switch (normal) {
      QuickEditCaptionColor.yellow => QuickEditCaptionColor.purple,
      QuickEditCaptionColor.white => QuickEditCaptionColor.yellow,
      QuickEditCaptionColor.purple || QuickEditCaptionColor.pink => QuickEditCaptionColor.white,
      _ => QuickEditCaptionColor.yellow,
    };
  }
  return p.color;
}

QuickEditCaptionColor _defaultBoxForPreset(CaptionPresetFields p) {
  if (p.wordHighlight != QuickEditCaptionWordHighlight.box) {
    return QuickEditCaptionColor.yellow;
  }
  return switch (p.color) {
    QuickEditCaptionColor.pink => QuickEditCaptionColor.pink,
    QuickEditCaptionColor.purple => QuickEditCaptionColor.purple,
    QuickEditCaptionColor.mint => QuickEditCaptionColor.mint,
    _ => QuickEditCaptionColor.yellow,
  };
}

CaptionPresetFields? captionPresetRecipe(QuickEditCaptionPreset preset) {
  switch (preset) {
    case QuickEditCaptionPreset.custom:
      return null;
    case QuickEditCaptionPreset.minimal:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.extraSmall,
        fontFamily: QuickEditCaptionFontFamily.defaultFamily,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.cleanPro,
        wordHighlight: QuickEditCaptionWordHighlight.none,
        offsetX: 0,
        offsetY: 0,
      );
    case QuickEditCaptionPreset.social:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.small,
        fontFamily: QuickEditCaptionFontFamily.rubik,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.boldSocial,
        wordHighlight: QuickEditCaptionWordHighlight.color,
        normalTextColor: QuickEditCaptionColor.white,
        activeTextColor: QuickEditCaptionColor.pink,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.boldYellow:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.small,
        fontFamily: QuickEditCaptionFontFamily.rubik,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.yellow,
        style: QuickEditCaptionsStylePreset.boldSocial,
        wordHighlight: QuickEditCaptionWordHighlight.color,
        normalTextColor: QuickEditCaptionColor.white,
        activeTextColor: QuickEditCaptionColor.yellow,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.darkBox:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.small,
        fontFamily: QuickEditCaptionFontFamily.defaultFamily,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.darkBubble,
        wordHighlight: QuickEditCaptionWordHighlight.none,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.topClean:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.extraSmall,
        fontFamily: QuickEditCaptionFontFamily.defaultFamily,
        position: QuickEditCaptionPosition.top,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.cleanPro,
        wordHighlight: QuickEditCaptionWordHighlight.none,
        offsetX: 0,
        offsetY: 0,
      );
    case QuickEditCaptionPreset.creatorHighlight:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.xLarge,
        fontFamily: QuickEditCaptionFontFamily.rubik,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.highlightBox,
        wordHighlight: QuickEditCaptionWordHighlight.box,
        normalTextColor: QuickEditCaptionColor.white,
        activeTextColor: QuickEditCaptionColor.black,
        boxColor: QuickEditCaptionColor.pink,
        boxShape: QuickEditCaptionBoxShape.pill,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.newsHeadline:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.xLarge,
        fontFamily: QuickEditCaptionFontFamily.assistant,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.yellow,
        style: QuickEditCaptionsStylePreset.yellowHeadline,
        wordHighlight: QuickEditCaptionWordHighlight.box,
        normalTextColor: QuickEditCaptionColor.white,
        activeTextColor: QuickEditCaptionColor.black,
        boxColor: QuickEditCaptionColor.yellow,
        boxShape: QuickEditCaptionBoxShape.rectangle,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.pinkPop:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.xLarge,
        fontFamily: QuickEditCaptionFontFamily.rubik,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.highlightBox,
        wordHighlight: QuickEditCaptionWordHighlight.box,
        normalTextColor: QuickEditCaptionColor.white,
        activeTextColor: QuickEditCaptionColor.black,
        boxColor: QuickEditCaptionColor.pink,
        boxShape: QuickEditCaptionBoxShape.pill,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.yellowViral:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.xLarge,
        fontFamily: QuickEditCaptionFontFamily.rubik,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.highlightBox,
        wordHighlight: QuickEditCaptionWordHighlight.box,
        normalTextColor: QuickEditCaptionColor.white,
        activeTextColor: QuickEditCaptionColor.black,
        boxColor: QuickEditCaptionColor.yellow,
        boxShape: QuickEditCaptionBoxShape.rounded,
        offsetX: 0,
        offsetY: -20,
      );
    case QuickEditCaptionPreset.cleanFocus:
      return const CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.large,
        fontFamily: QuickEditCaptionFontFamily.heebo,
        position: QuickEditCaptionPosition.bottom,
        color: QuickEditCaptionColor.white,
        style: QuickEditCaptionsStylePreset.cleanPro,
        wordHighlight: QuickEditCaptionWordHighlight.color,
        normalTextColor: QuickEditCaptionColor.white,
        activeTextColor: QuickEditCaptionColor.mint,
        offsetX: 0,
        offsetY: -20,
      );
  }
}

const List<QuickEditCaptionPreset> kQuickEditCaptionBuiltInPresetsOrdered = [
  QuickEditCaptionPreset.minimal,
  QuickEditCaptionPreset.social,
  QuickEditCaptionPreset.boldYellow,
  QuickEditCaptionPreset.darkBox,
  QuickEditCaptionPreset.topClean,
  QuickEditCaptionPreset.creatorHighlight,
  QuickEditCaptionPreset.newsHeadline,
  QuickEditCaptionPreset.pinkPop,
  QuickEditCaptionPreset.yellowViral,
  QuickEditCaptionPreset.cleanFocus,
];

/// Presets shown as visual cards in the look editor (excludes [QuickEditCaptionPreset.custom]).
const List<QuickEditCaptionPreset> kCaptionLookEditorPresetsOrdered =
    kQuickEditCaptionBuiltInPresetsOrdered;

void applyCaptionPresetFields(
  CaptionPresetFields recipe, {
  required void Function(QuickEditCaptionFontSize) setFontSize,
  required void Function(QuickEditCaptionFontFamily) setFontFamily,
  required void Function(QuickEditCaptionPosition) setPosition,
  required void Function(QuickEditCaptionColor) setColor,
  required void Function(QuickEditCaptionsStylePreset) setStyle,
  required void Function(QuickEditCaptionWordHighlight) setWordHighlight,
  required void Function(int) setOffsetX,
  required void Function(int) setOffsetY,
  required void Function(QuickEditCaptionColor?) setNormalTextColor,
  required void Function(QuickEditCaptionColor?) setActiveTextColor,
  required void Function(QuickEditCaptionColor?) setBoxColor,
  required void Function(QuickEditCaptionBoxShape) setBoxShape,
}) {
  setFontSize(recipe.fontSize);
  setFontFamily(recipe.fontFamily);
  setPosition(recipe.position);
  setColor(recipe.color);
  setStyle(recipe.style);
  setWordHighlight(recipe.wordHighlight);
  setOffsetX(recipe.offsetX);
  setOffsetY(recipe.offsetY);
  setNormalTextColor(recipe.normalTextColor);
  setActiveTextColor(recipe.activeTextColor);
  setBoxColor(recipe.boxColor);
  setBoxShape(recipe.boxShape);
}

CaptionLookSnapshot captionLookSnapshotFrom({
  required QuickEditCaptionsStylePreset style,
  required QuickEditCaptionFontSize fontSize,
  required QuickEditCaptionFontFamily fontFamily,
  required QuickEditCaptionPosition position,
  required QuickEditCaptionColor color,
  required QuickEditCaptionWordHighlight wordHighlight,
  required int offsetX,
  required int offsetY,
  QuickEditCaptionColor? normalTextColor,
  QuickEditCaptionColor? activeTextColor,
  QuickEditCaptionColor? boxColor,
  QuickEditCaptionBoxShape boxShape = QuickEditCaptionBoxShape.pill,
}) =>
    CaptionLookSnapshot(
      style: style,
      fontSize: fontSize,
      fontFamily: fontFamily,
      position: position,
      color: color,
      wordHighlight: wordHighlight,
      offsetX: offsetX,
      offsetY: offsetY,
      normalTextColor: normalTextColor,
      activeTextColor: activeTextColor,
      boxColor: boxColor,
      boxShape: boxShape,
    );

/// Effective normal text color for highlight burn (falls back to accent [color]).
QuickEditCaptionColor effectiveCaptionNormalTextColor({
  required QuickEditCaptionColor color,
  QuickEditCaptionColor? normalTextColor,
}) =>
    normalTextColor ?? color;

QuickEditCaptionColor effectiveCaptionActiveTextColor({
  required QuickEditCaptionColor color,
  required QuickEditCaptionWordHighlight wordHighlight,
  QuickEditCaptionColor? normalTextColor,
  QuickEditCaptionColor? activeTextColor,
  QuickEditCaptionColor? boxColor,
}) {
  if (activeTextColor != null) return activeTextColor;
  final normal = effectiveCaptionNormalTextColor(
    color: color,
    normalTextColor: normalTextColor,
  );
  final box = effectiveCaptionBoxColor(
    color: color,
    wordHighlight: wordHighlight,
    boxColor: boxColor,
  );
  if (wordHighlight == QuickEditCaptionWordHighlight.box) {
    return switch (box) {
      QuickEditCaptionColor.yellow ||
      QuickEditCaptionColor.mint ||
      QuickEditCaptionColor.white ||
      QuickEditCaptionColor.pink =>
        QuickEditCaptionColor.black,
      _ => QuickEditCaptionColor.white,
    };
  }
  if (wordHighlight == QuickEditCaptionWordHighlight.color) {
    return switch (normal) {
      QuickEditCaptionColor.yellow => QuickEditCaptionColor.purple,
      QuickEditCaptionColor.white => QuickEditCaptionColor.yellow,
      QuickEditCaptionColor.purple || QuickEditCaptionColor.pink => QuickEditCaptionColor.white,
      _ => QuickEditCaptionColor.yellow,
    };
  }
  return normal;
}

QuickEditCaptionColor effectiveCaptionBoxColor({
  required QuickEditCaptionColor color,
  required QuickEditCaptionWordHighlight wordHighlight,
  QuickEditCaptionColor? boxColor,
}) {
  if (boxColor != null) return boxColor;
  if (wordHighlight != QuickEditCaptionWordHighlight.box) {
    return QuickEditCaptionColor.yellow;
  }
  return switch (color) {
    QuickEditCaptionColor.pink => QuickEditCaptionColor.pink,
    QuickEditCaptionColor.purple => QuickEditCaptionColor.purple,
    QuickEditCaptionColor.mint => QuickEditCaptionColor.mint,
    _ => QuickEditCaptionColor.yellow,
  };
}

void applyCaptionHighlightFieldsToJson(
  Map<String, dynamic> op, {
  required QuickEditCaptionWordHighlight wordHighlight,
  required QuickEditCaptionColor color,
  QuickEditCaptionColor? normalTextColor,
  QuickEditCaptionColor? activeTextColor,
  QuickEditCaptionColor? boxColor,
  QuickEditCaptionBoxShape boxShape = QuickEditCaptionBoxShape.pill,
}) {
  if (wordHighlight == QuickEditCaptionWordHighlight.none) return;
  final normal = effectiveCaptionNormalTextColor(
    color: color,
    normalTextColor: normalTextColor,
  );
  op["normalTextColor"] = normal.apiValue;
  op["activeTextColor"] = effectiveCaptionActiveTextColor(
    color: color,
    wordHighlight: wordHighlight,
    normalTextColor: normalTextColor,
    activeTextColor: activeTextColor,
    boxColor: boxColor,
  ).apiValue;
  if (wordHighlight == QuickEditCaptionWordHighlight.box) {
    op["boxColor"] = effectiveCaptionBoxColor(
      color: color,
      wordHighlight: wordHighlight,
      boxColor: boxColor,
    ).apiValue;
    op["boxShape"] = boxShape.apiValue;
  }
}

/// Which named preset matches the current controls, or [QuickEditCaptionPreset.custom].
QuickEditCaptionPreset inferQuickEditCaptionPreset({
  required QuickEditCaptionFontSize fontSize,
  required QuickEditCaptionFontFamily fontFamily,
  required QuickEditCaptionPosition position,
  required QuickEditCaptionColor color,
  required QuickEditCaptionsStylePreset style,
  required QuickEditCaptionWordHighlight wordHighlight,
  required int offsetX,
  required int offsetY,
  QuickEditCaptionColor? normalTextColor,
  QuickEditCaptionColor? activeTextColor,
  QuickEditCaptionColor? boxColor,
  QuickEditCaptionBoxShape boxShape = QuickEditCaptionBoxShape.pill,
}) {
  final effNormal = effectiveCaptionNormalTextColor(
    color: color,
    normalTextColor: normalTextColor,
  );
  final effActive = effectiveCaptionActiveTextColor(
    color: color,
    wordHighlight: wordHighlight,
    normalTextColor: normalTextColor,
    activeTextColor: activeTextColor,
    boxColor: boxColor,
  );
  final effBox = effectiveCaptionBoxColor(
    color: color,
    wordHighlight: wordHighlight,
    boxColor: boxColor,
  );
  for (final p in kQuickEditCaptionBuiltInPresetsOrdered) {
    final r = captionPresetRecipe(p)!;
    if (r.matches(
      fontSize: fontSize,
      fontFamily: fontFamily,
      position: position,
      color: color,
      style: style,
      wordHighlight: wordHighlight,
      offsetX: offsetX,
      offsetY: offsetY,
      effectiveNormalTextColor: effNormal,
      effectiveActiveTextColor: effActive,
      effectiveBoxColor: effBox,
      boxShape: boxShape,
    )) {
      return p;
    }
  }
  return QuickEditCaptionPreset.custom;
}

/// Whether the list screen row may offer video Quick Edit.
bool downloadItemEligibleForVideoEdit(DownloadItem item) {
  if (item.status != "done") return false;
  if (item.file?.hasFileHint != true) return false;
  if (downloadItemIsAudioOnly(item)) return false;
  return true;
}

/// @deprecated Use [downloadItemEligibleForVideoEdit].
bool downloadItemEligibleForQuickEdit(DownloadItem item) =>
    downloadItemEligibleForVideoEdit(item);

/// Done MP3/audio download eligible for server audio edit.
bool downloadItemEligibleForAudioEdit(DownloadItem item) {
  if (item.status != "done") return false;
  if (item.file?.hasFileHint != true) return false;
  return downloadItemIsAudioOnly(item);
}

/// @deprecated Use [downloadItemEligibleForAudioEdit].
bool downloadItemEligibleForAudioActions(DownloadItem item) =>
    downloadItemEligibleForAudioEdit(item);

bool downloadDetailEligibleForVideoEdit(DownloadDetailResponse d) {
  if (d.status != "done") return false;
  if (d.file?.hasFileHint != true) return false;
  if (downloadDetailIsAudioOnly(d)) return false;
  return true;
}

/// @deprecated Use [downloadDetailEligibleForVideoEdit].
bool downloadDetailEligibleForQuickEdit(DownloadDetailResponse d) =>
    downloadDetailEligibleForVideoEdit(d);

bool downloadDetailEligibleForAudioEdit(DownloadDetailResponse d) {
  if (d.status != "done") return false;
  if (d.file?.hasFileHint != true) return false;
  return downloadDetailIsAudioOnly(d);
}

/// @deprecated Use [downloadDetailEligibleForAudioEdit].
bool downloadDetailEligibleForAudioActions(DownloadDetailResponse d) =>
    downloadDetailEligibleForAudioEdit(d);

/// Audio export quality for `audioQuality` operation.
enum AudioEditQuality {
  standard,
  high,
  best;

  String get apiPreset => switch (this) {
        AudioEditQuality.standard => "standard",
        AudioEditQuality.high => "high",
        AudioEditQuality.best => "best",
      };
}

/// Constant speed factors for audio-only edits.
enum AudioEditSpeedFactor {
  x075(0.75),
  x1(1.0),
  x125(1.25),
  x15(1.5),
  x2(2.0);

  const AudioEditSpeedFactor(this.factor);
  final double factor;

  double? get apiFactor => factor == 1.0 ? null : factor;
}

const double kAudioEditMinTrimSpanSec = 1.0;
const double kAudioEditTrimNudgeSec = 0.5;
const AudioEditQuality kAudioEditDefaultQuality = AudioEditQuality.high;

bool audioEditHasChanges({
  required double durationSec,
  required double trimStartSec,
  required double trimEndSec,
  required AudioEditSpeedFactor speed,
  required AudioEditQuality quality,
}) {
  const eps = 0.05;
  final dur = durationSec <= 0 ? 1.0 : durationSec;
  final trimChanged = trimStartSec > eps || trimEndSec < dur - eps;
  final speedChanged = speed != AudioEditSpeedFactor.x1;
  final qualityChanged = quality != kAudioEditDefaultQuality;
  return trimChanged || speedChanged || qualityChanged;
}

/// Builds POST `/edits` operations for audio-only sources.
List<Map<String, dynamic>> buildAudioEditOperations({
  required double durationSec,
  required double trimStartSec,
  required double trimEndSec,
  required AudioEditSpeedFactor speed,
  required AudioEditQuality quality,
}) {
  final dur = durationSec <= 0 ? 1.0 : durationSec;
  const eps = 0.05;
  final ops = <Map<String, dynamic>>[];

  if (trimStartSec > eps || trimEndSec < dur - eps) {
    final start = trimStartSec.clamp(0.0, dur - eps);
    var end = trimEndSec.clamp(start + kAudioEditMinTrimSpanSec, dur);
    ops.add({
      "type": "trim",
      "startSec": start,
      "endSec": end,
    });
  }

  final sp = speed.apiFactor;
  if (sp != null) {
    ops.add({
      "type": "speed",
      "factor": sp,
    });
  }

  if (quality != kAudioEditDefaultQuality) {
    ops.add({
      "type": "audioQuality",
      "preset": quality.apiPreset,
    });
  }

  return ops;
}

String formatAudioEditTimeSec(double sec) {
  final s = sec.clamp(0.0, 86400.0);
  final whole = s.floor();
  final frac = ((s - whole) * 10).round();
  final mm = whole ~/ 60;
  final ss = whole % 60;
  return "${mm.toString().padLeft(2, "0")}:${ss.toString().padLeft(2, "0")}.${frac % 10}";
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
  required QuickEditCaptionFontFamily fontFamily,
  required QuickEditCaptionPosition position,
  required QuickEditCaptionColor color,
  required QuickEditCaptionWordHighlight wordHighlight,
  required int captionsOffsetX,
  required int captionsOffsetY,
  QuickEditCaptionColor? normalTextColor,
  QuickEditCaptionColor? activeTextColor,
  QuickEditCaptionColor? boxColor,
  QuickEditCaptionBoxShape boxShape = QuickEditCaptionBoxShape.pill,
}) {
  final op = <String, dynamic>{
    "type": "captions",
    "mode": "auto",
    "language": "auto",
    "burnIn": true,
    "style": style.apiValue,
    "fontSize": fontSize.apiValue,
    "fontFamily": fontFamily.apiValue,
    "position": position.apiValue,
    "color": color.apiValue,
    "wordHighlight": wordHighlight.apiValue,
    "offsetX": clampQuickEditCaptionOffsetX(captionsOffsetX),
    "offsetY": clampQuickEditCaptionOffsetY(captionsOffsetY),
  };
  applyCaptionHighlightFieldsToJson(
    op,
    wordHighlight: wordHighlight,
    color: color,
    normalTextColor: normalTextColor,
    activeTextColor: activeTextColor,
    boxColor: boxColor,
    boxShape: boxShape,
  );
  return op;
}

/// `captions.mode=segments` — server skips OpenAI transcription (V2.4A).
Map<String, dynamic> quickEditCaptionsSegmentsV24Operation({
  required List<CaptionDraftSegment> segments,
  required QuickEditCaptionsStylePreset style,
  required QuickEditCaptionFontSize fontSize,
  required QuickEditCaptionFontFamily fontFamily,
  required QuickEditCaptionPosition position,
  required QuickEditCaptionColor color,
  required QuickEditCaptionWordHighlight wordHighlight,
  required int captionsOffsetX,
  required int captionsOffsetY,
  QuickEditCaptionColor? normalTextColor,
  QuickEditCaptionColor? activeTextColor,
  QuickEditCaptionColor? boxColor,
  QuickEditCaptionBoxShape boxShape = QuickEditCaptionBoxShape.pill,
}) {
  final op = <String, dynamic>{
    "type": "captions",
    "mode": "segments",
    "language": "auto",
    "burnIn": true,
    "style": style.apiValue,
    "fontSize": fontSize.apiValue,
    "fontFamily": fontFamily.apiValue,
    "position": position.apiValue,
    "color": color.apiValue,
    "wordHighlight": wordHighlight.apiValue,
    "offsetX": clampQuickEditCaptionOffsetX(captionsOffsetX),
    "offsetY": clampQuickEditCaptionOffsetY(captionsOffsetY),
    "segments": segments.map((s) => s.toCaptionsBurnJson()).toList(),
  };
  applyCaptionHighlightFieldsToJson(
    op,
    wordHighlight: wordHighlight,
    color: color,
    normalTextColor: normalTextColor,
    activeTextColor: activeTextColor,
    boxColor: boxColor,
    boxShape: boxShape,
  );
  return op;
}

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
  QuickEditCaptionsStylePreset captionsStyle = QuickEditCaptionsStylePreset.cleanPro,
  QuickEditCaptionFontSize captionsFontSize = QuickEditCaptionFontSize.medium,
  QuickEditCaptionFontFamily captionsFontFamily = QuickEditCaptionFontFamily.defaultFamily,
  QuickEditCaptionPosition captionsPosition = QuickEditCaptionPosition.bottom,
  QuickEditCaptionColor captionsColor = QuickEditCaptionColor.white,
  QuickEditCaptionWordHighlight captionsWordHighlight = QuickEditCaptionWordHighlight.none,
  int captionsOffsetX = 0,
  int captionsOffsetY = 0,
  QuickEditCaptionColor? captionsNormalTextColor,
  QuickEditCaptionColor? captionsActiveTextColor,
  QuickEditCaptionColor? captionsBoxColor,
  QuickEditCaptionBoxShape captionsBoxShape = QuickEditCaptionBoxShape.pill,
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
        fontFamily: captionsFontFamily,
        position: captionsPosition,
        color: captionsColor,
        wordHighlight: captionsWordHighlight,
        captionsOffsetX: captionsOffsetX,
        captionsOffsetY: captionsOffsetY,
        normalTextColor: captionsNormalTextColor,
        activeTextColor: captionsActiveTextColor,
        boxColor: captionsBoxColor,
        boxShape: captionsBoxShape,
      ));
    } else {
      ops.add(quickEditCaptionsV22Operation(
        style: captionsStyle,
        fontSize: captionsFontSize,
        fontFamily: captionsFontFamily,
        position: captionsPosition,
        color: captionsColor,
        wordHighlight: captionsWordHighlight,
        captionsOffsetX: captionsOffsetX,
        captionsOffsetY: captionsOffsetY,
        normalTextColor: captionsNormalTextColor,
        activeTextColor: captionsActiveTextColor,
        boxColor: captionsBoxColor,
        boxShape: captionsBoxShape,
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
  QuickEditCaptionsStylePreset captionsStyle = QuickEditCaptionsStylePreset.cleanPro,
  QuickEditCaptionFontSize captionsFontSize = QuickEditCaptionFontSize.medium,
  QuickEditCaptionFontFamily captionsFontFamily = QuickEditCaptionFontFamily.defaultFamily,
  QuickEditCaptionPosition captionsPosition = QuickEditCaptionPosition.bottom,
  QuickEditCaptionColor captionsColor = QuickEditCaptionColor.white,
  QuickEditCaptionWordHighlight captionsWordHighlight = QuickEditCaptionWordHighlight.none,
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
    captionsFontFamily: captionsFontFamily,
    captionsPosition: captionsPosition,
    captionsColor: captionsColor,
    captionsWordHighlight: captionsWordHighlight,
    captionsOffsetX: captionsOffsetX,
    captionsOffsetY: captionsOffsetY,
    captionsDraftForBurn: null,
    mute: mute,
    compressPreset: compressPreset,
  );
  return ops.isNotEmpty;
}
