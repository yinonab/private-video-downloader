import "../models/quick_edit_models.dart";

/// Tool-strip tab indices on [EditVideoScreen] (Trim → Speed → Format → Captions → Audio → Quality).
abstract final class EditVideoPreviewTabs {
  static const int trim = 0;
  static const int speed = 1;
  static const int format = 2;
  static const int captions = 3;
  static const int audio = 4;
  static const int quality = 5;
}

/// How closely an edit feature is reflected in the in-editor preview.
enum EditPreviewCapability {
  /// Matches export behavior closely in the preview player / overlay.
  livePreview,

  /// Visible approximation; final MP4 may differ (fonts, ASS burn, ffmpeg).
  approximatePreview,

  /// Applied only when user creates the edit (`POST /edits`).
  exportOnly,

  /// Not available in product yet.
  notSupported,
}

/// Passive preview snapshot derived from editor state + current playback time.
///
/// Read-only: does not call backend, mutate [VideoPlayerController], or build export ops.
final class EditPreviewState {
  const EditPreviewState({
    required this.playbackSpeed,
    required this.muted,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.rotation,
    required this.formatMode,
    required this.cropAspect,
    required this.showCropOverlay,
    this.captionOnVideo,
  });

  /// Player `setPlaybackSpeed` factor (1.0 = normal).
  final double playbackSpeed;

  /// When true, preview volume is 0.
  final bool muted;

  final double trimStartSec;
  final double trimEndSec;
  final QuickEditRotation rotation;
  final QuickEditFormatMode formatMode;
  final QuickEditCropAspect cropAspect;

  /// Format-tab crop guide when Fill + non-original aspect.
  final bool showCropOverlay;

  /// Caption overlay on the real video preview, or null when captions are off / not shown.
  final CaptionPreviewState? captionOnVideo;
}

/// Caption cue + style for preview overlays (video or isolated stage card).
final class CaptionPreviewState {
  const CaptionPreviewState({
    required this.enabled,
    required this.showOnVideoPreview,
    required this.allowSampleFallback,
    required this.style,
    this.activeText,
    this.activeWordIndex,
  });

  final bool enabled;
  final bool showOnVideoPreview;
  final bool allowSampleFallback;
  final CaptionLookSnapshot style;
  final String? activeText;
  final int? activeWordIndex;

  bool get hasDisplayText =>
      activeText != null && activeText!.trim().isNotEmpty;
}

extension QuickEditSpeedFactorPreview on QuickEditSpeedFactor {
  /// Maps editor speed chip → `VideoPlayerController.setPlaybackSpeed` factor.
  double get previewPlaybackFactor => apiFactor ?? 1.0;
}

/// Derives unified preview state from current editor fields.
EditPreviewState buildEditVideoPreviewState({
  required double playbackSec,
  required int activeToolTabIndex,
  required double trimStartSec,
  required double trimEndSec,
  required QuickEditRotation rotation,
  required QuickEditFormatMode formatMode,
  required QuickEditCropAspect cropAspect,
  required QuickEditSpeedFactor speedFactor,
  required bool muted,
  required bool captionsAutoEnabled,
  required List<CaptionDraftSegment>? captionDraftSegments,
  required CaptionLookSnapshot captionStyle,
}) {
  final showCaptionsOnVideo = activeToolTabIndex == EditVideoPreviewTabs.captions &&
      captionsAutoEnabled;

  return EditPreviewState(
    playbackSpeed: speedFactor.previewPlaybackFactor,
    muted: muted,
    trimStartSec: trimStartSec,
    trimEndSec: trimEndSec,
    rotation: rotation,
    formatMode: formatMode,
    cropAspect: cropAspect,
    showCropOverlay: activeToolTabIndex == EditVideoPreviewTabs.format &&
        cropAspect != QuickEditCropAspect.original &&
        formatMode == QuickEditFormatMode.fill,
    captionOnVideo: buildCaptionPreviewState(
      captionsAutoEnabled: captionsAutoEnabled,
      showOnVideoPreview: showCaptionsOnVideo,
      draftSegments: captionDraftSegments,
      playbackSec: playbackSec,
      style: captionStyle,
      allowSampleFallback: false,
    ),
  );
}

/// Resolves caption preview cue + style from draft segments at [playbackSec].
///
/// Uses the same playback clock as the editor (`_playbackSec` / trim window).
/// Does not remap trim/speed onto the draft timeline.
CaptionPreviewState? buildCaptionPreviewState({
  required bool captionsAutoEnabled,
  required bool showOnVideoPreview,
  required List<CaptionDraftSegment>? draftSegments,
  required double playbackSec,
  required CaptionLookSnapshot style,
  bool allowSampleFallback = false,
}) {
  if (!captionsAutoEnabled) return null;

  if (!showOnVideoPreview) {
    return CaptionPreviewState(
      enabled: true,
      showOnVideoPreview: false,
      allowSampleFallback: allowSampleFallback,
      style: style,
    );
  }

  final segments = draftSegments;
  if (segments == null || segments.isEmpty) {
    return null;
  }

  final active = _activeDraftSegment(segments, playbackSec);
  final trimmed = active?.text.trim();
  final text = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  final wordIdx = active != null && text != null
      ? _activeWordIndex(active, playbackSec, text)
      : null;

  return CaptionPreviewState(
    enabled: true,
    showOnVideoPreview: true,
    allowSampleFallback: allowSampleFallback,
    style: style,
    activeText: text,
    activeWordIndex: wordIdx,
  );
}

CaptionDraftSegment? _activeDraftSegment(
  List<CaptionDraftSegment> segments,
  double playbackSec,
) {
  for (final seg in segments) {
    if (playbackSec >= seg.startSec && playbackSec < seg.endSec) return seg;
  }
  return null;
}

int? _activeWordIndex(
  CaptionDraftSegment segment,
  double playbackSec,
  String text,
) {
  final words = segment.words;
  if (words != null && words.isNotEmpty) {
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (playbackSec >= w.startSec && playbackSec < w.endSec) return i;
    }
    return null;
  }
  if (text.trim().isEmpty) return null;
  final parts = text.trim().split(RegExp(r"\s+"));
  if (parts.isEmpty) return null;
  return parts.length - 1;
}

/// Capability matrix for Quick Edit in-editor preview (see `docs/EDIT_PREVIEW_CAPABILITY_MATRIX.md`).
const Map<String, EditPreviewCapability> kEditPreviewCapabilityMatrix = {
  "trim": EditPreviewCapability.livePreview,
  "speed": EditPreviewCapability.livePreview,
  "mute": EditPreviewCapability.livePreview,
  "rotate": EditPreviewCapability.approximatePreview,
  "crop_format_fill": EditPreviewCapability.approximatePreview,
  "crop_format_fit_blur": EditPreviewCapability.exportOnly,
  "compression": EditPreviewCapability.exportOnly,
  "captions_text": EditPreviewCapability.approximatePreview,
  "captions_style": EditPreviewCapability.approximatePreview,
  "captions_position": EditPreviewCapability.approximatePreview,
  "captions_outline": EditPreviewCapability.approximatePreview,
  "captions_word_highlight": EditPreviewCapability.approximatePreview,
  "audio_edit": EditPreviewCapability.notSupported,
};
