import "dart:math" as math;

import "package:flutter/material.dart";

import "../models/quick_edit_models.dart";
import "../../l10n/app_localizations.dart";

/// Resolved caption cue for preview overlays.
final class CaptionPreviewCue {
  const CaptionPreviewCue({this.text, required this.isSample});

  final String? text;
  final bool isSample;

  bool get hasText => text != null && text!.trim().isNotEmpty;
}

/// Layout mode for caption preview positioning.
enum CaptionPreviewLayout {
  standard,
  stage,
  fullscreen,
}

/// ASS / burn-in script margins (parity with backend `assSubtitles.service.ts`).
const double kCaptionAssMarginV = 96;
const double kCaptionAssMarginH = 52;
const double kCaptionAssPadX = 48;

/// ASS font sizes at PlayRes 960×540 (parity with backend `dimensions.ts` / `assSubtitles.service.ts`).
double captionPreviewFontSizeAss(QuickEditCaptionFontSize size) {
  return switch (size) {
    QuickEditCaptionFontSize.extraSmall => 16,
    QuickEditCaptionFontSize.small => 20,
    QuickEditCaptionFontSize.medium => 24,
    QuickEditCaptionFontSize.large => 30,
    QuickEditCaptionFontSize.xLarge => 36,
    QuickEditCaptionFontSize.xxLarge => 44,
  };
}

/// Scaled caption font size for a preview frame height.
double captionPreviewFontSizePx(QuickEditCaptionFontSize size, double frameHeight) {
  final sy = math.max(frameHeight, 1) / kCaptionAssPlayResY;
  return math.max(8.0, captionPreviewFontSizeAss(size) * sy);
}

/// Outline width in preview pixels (ASS outline widths × font scale).
double captionPreviewOutlineWidthPx(
  QuickEditCaptionOutlineWidth width,
  double fontPx,
) {
  final scale = fontPx / captionPreviewFontSizeAss(QuickEditCaptionFontSize.medium);
  return switch (width) {
    QuickEditCaptionOutlineWidth.thin => 2.0 * scale,
    QuickEditCaptionOutlineWidth.medium => 3.5 * scale,
    QuickEditCaptionOutlineWidth.thick => 5.5 * scale,
  };
}

/// Horizontal padding inside caption block (scaled margin H).
double captionPreviewHorizontalPadPx(double frameWidth) {
  final sx = math.max(frameWidth, 1) / kCaptionAssPlayResX;
  return math.max(8.0, kCaptionAssMarginH * sx);
}

/// True when caption text should render RTL (Hebrew / Arabic).
bool captionPreviewIsRtl(String text) {
  for (final rune in text.runes) {
    if (rune >= 0x0590 && rune <= 0x08FF) return true;
  }
  return false;
}

/// Display aspect ratio (width ÷ height) after clockwise [rotation].
double videoPreviewDisplayAspectRatio({
  required double sourceWidth,
  required double sourceHeight,
  required QuickEditRotation rotation,
}) {
  final w = sourceWidth;
  final h = sourceHeight;
  if (w <= 8 || h <= 8) return 16 / 9;
  final srcAr = w / h;
  return switch (rotation) {
    QuickEditRotation.deg0 || QuickEditRotation.deg180 => srcAr,
    QuickEditRotation.deg90 || QuickEditRotation.deg270 => 1 / srcAr,
  };
}

/// Letterboxed video rect for [BoxFit.contain] inside [containerSize].
Rect videoPreviewContainRect({
  required Size containerSize,
  required double displayAspectWidthOverHeight,
}) {
  final cw = math.max(containerSize.width, 1.0);
  final ch = math.max(containerSize.height, 1.0);
  final containerAr = cw / ch;
  final videoAr = math.max(displayAspectWidthOverHeight, 1e-6);

  if (videoAr > containerAr) {
    final videoW = cw;
    final videoH = cw / videoAr;
    final top = (ch - videoH) / 2;
    return Rect.fromLTWH(0, top, videoW, videoH);
  }
  final videoH = ch;
  final videoW = ch * videoAr;
  final left = (cw - videoW) / 2;
  return Rect.fromLTWH(left, 0, videoW, videoH);
}

/// Maps raw player position → caption draft/burn timeline (post trim + constant speed).
double captionPreviewPlaybackOnEditTimeline({
  required double sourcePlaybackSec,
  required double trimStartSec,
  required double trimEndSec,
  required double videoDurationSec,
  required QuickEditSpeedFactor speedFactor,
}) {
  final dur = videoDurationSec <= 0 ? 1.0 : videoDurationSec;
  final start = trimStartSec.clamp(0.0, dur);
  final end = trimEndSec.clamp(start + 0.05, dur);
  if (sourcePlaybackSec < start) return 0;
  if (sourcePlaybackSec >= end) {
    final span = end - start;
    final speed = speedFactor.apiFactor ?? 1.0;
    return span / speed;
  }
  final speed = speedFactor.apiFactor ?? 1.0;
  return (sourcePlaybackSec - start) / speed;
}

/// Active draft segment at [playbackSec] on the **edit** timeline, or null.
CaptionDraftSegment? captionPreviewActiveSegment({
  required List<CaptionDraftSegment>? draftSegments,
  required double playbackSec,
}) {
  if (draftSegments == null || draftSegments.isEmpty) return null;
  for (final seg in draftSegments) {
    if (playbackSec >= seg.startSec && playbackSec < seg.endSec) return seg;
  }
  return null;
}

/// Caption cue for preview — draft text on edit timeline; sample only when allowed.
CaptionPreviewCue resolveCaptionPreviewCue({
  required AppLocalizations l10n,
  required List<CaptionDraftSegment>? draftSegments,
  required double playbackSec,
  required bool allowSampleFallback,
}) {
  final active = captionPreviewActiveSegment(
    draftSegments: draftSegments,
    playbackSec: playbackSec,
  );
  if (active != null) {
    final t = active.text.trim();
    if (t.isNotEmpty) return CaptionPreviewCue(text: t, isSample: false);
    return const CaptionPreviewCue(text: null, isSample: false);
  }
  if (draftSegments != null && draftSegments.isNotEmpty) {
    return const CaptionPreviewCue(text: null, isSample: false);
  }
  if (allowSampleFallback) {
    return CaptionPreviewCue(text: l10n.editCaptionsSampleLabel, isSample: true);
  }
  return const CaptionPreviewCue(text: null, isSample: false);
}

/// @deprecated Use [resolveCaptionPreviewCue].
String captionPreviewDisplayText({
  required AppLocalizations l10n,
  required List<CaptionDraftSegment>? draftSegments,
  required double playbackSec,
  bool allowSampleFallback = true,
}) {
  return resolveCaptionPreviewCue(
    l10n: l10n,
    draftSegments: draftSegments,
    playbackSec: playbackSec,
    allowSampleFallback: allowSampleFallback,
  ).text ??
      l10n.editCaptionsSampleLabel;
}

/// Word index to highlight (whitespace tokens); `null` when none / between cues.
int? captionPreviewActiveWordIndex({
  required String text,
  required List<CaptionDraftSegment>? draftSegments,
  required double playbackSec,
}) {
  final active = captionPreviewActiveSegment(
    draftSegments: draftSegments,
    playbackSec: playbackSec,
  );
  if (active == null) return null;
  final words = active.words;
  if (words != null && words.isNotEmpty) {
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (playbackSec >= w.startSec && playbackSec < w.endSec) return i;
    }
  }
  if (text.trim().isEmpty) return null;
  final parts = text.trim().split(RegExp(r"\s+"));
  if (parts.isEmpty) return null;
  return parts.length - 1;
}

/// Split caption into before / highlight spans for word-highlight preview.
({String before, String highlight}) captionPreviewHighlightParts(
  String full, {
  int? highlightWordIndex,
}) {
  final trimmed = full.trim();
  final parts = trimmed.split(RegExp(r"\s+"));
  if (parts.isEmpty) return (before: "", highlight: "");
  if (parts.length == 1) return (before: "", highlight: parts.first);
  final idx = highlightWordIndex ?? parts.length - 1;
  final safe = idx.clamp(0, parts.length - 1);
  final highlight = parts[safe];
  final before = safe > 0 ? "${parts.sublist(0, safe).join(" ")} " : "";
  return (before: before, highlight: highlight);
}

/// ASS `\pos` anchor parity — offset from alignment point in preview pixels.
Offset computeCaptionPreviewTranslate({
  required double width,
  required double height,
  required CaptionPreviewLayout layout,
  required QuickEditCaptionPosition position,
  required int offsetXAss,
  required int offsetYAss,
}) {
  final w = math.max(width, 1.0);
  final h = math.max(height, 1.0);
  final sx = w / kCaptionAssPlayResX;
  final sy = h / kCaptionAssPlayResY;
  final halfW = kCaptionAssPlayResX / 2;
  var xAss = halfW + offsetXAss;
  xAss = xAss.clamp(kCaptionAssPadX, kCaptionAssPlayResX - kCaptionAssPadX);
  final dx = (xAss - halfW) * sx;

  final bottom = position == QuickEditCaptionPosition.bottom;
  if (bottom) {
    var yAss = kCaptionAssPlayResY - kCaptionAssMarginV + offsetYAss;
    final yLo = (kCaptionAssPlayResY * 0.54).ceil().toDouble();
    final yHi = kCaptionAssPlayResY - 38;
    yAss = yAss.clamp(yLo, yHi);
    final fromBottom = (kCaptionAssPlayResY - yAss) * sy;
    final stageLift = layout == CaptionPreviewLayout.stage ? 4.0 : 0.0;
    return Offset(dx, -fromBottom - stageLift);
  }

  var yAss = kCaptionAssMarginV + offsetYAss;
  final yLo = 38.0;
  final yHi = (kCaptionAssPlayResY * 0.46).floorToDouble();
  yAss = yAss.clamp(yLo, yHi);
  final stageDrop = layout == CaptionPreviewLayout.stage ? 2.0 : 0.0;
  return Offset(dx, yAss * sy + stageDrop);
}
