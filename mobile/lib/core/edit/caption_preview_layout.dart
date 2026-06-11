import "dart:math" as math;

import "package:flutter/material.dart";

import "../models/quick_edit_models.dart";
import "../../l10n/app_localizations.dart";

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

/// Caption line shown in preview — draft cue at [playbackSec] or localized sample.
String captionPreviewDisplayText({
  required AppLocalizations l10n,
  required List<CaptionDraftSegment>? draftSegments,
  required double playbackSec,
}) {
  final fallback = l10n.editCaptionsSampleLabel;
  if (draftSegments == null || draftSegments.isEmpty) return fallback;
  for (final seg in draftSegments) {
    if (playbackSec >= seg.startSec && playbackSec < seg.endSec) {
      final t = seg.text.trim();
      if (t.isNotEmpty) return t;
    }
  }
  final first = draftSegments.first.text.trim();
  return first.isNotEmpty ? first : fallback;
}

/// Word index to highlight (whitespace tokens); `null` → last token.
int? captionPreviewActiveWordIndex({
  required String text,
  required List<CaptionDraftSegment>? draftSegments,
  required double playbackSec,
}) {
  if (draftSegments == null || draftSegments.isEmpty) return null;
  CaptionDraftSegment? active;
  for (final seg in draftSegments) {
    if (playbackSec >= seg.startSec && playbackSec < seg.endSec) {
      active = seg;
      break;
    }
  }
  active ??= draftSegments.first;
  final words = active.words;
  if (words != null && words.isNotEmpty) {
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (playbackSec >= w.startSec && playbackSec < w.endSec) return i;
    }
  }
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
