import "package:flutter/material.dart";

import "../models/quick_edit_models.dart";
import "../../l10n/app_localizations.dart";

Color captionColorToFlutter(QuickEditCaptionColor color) {
  return switch (color) {
    QuickEditCaptionColor.white => Colors.white,
    QuickEditCaptionColor.yellow => const Color(0xFFFFD966),
    QuickEditCaptionColor.purple => const Color(0xFF8B5CF6),
    QuickEditCaptionColor.pink => const Color(0xFFFF5C8A),
    QuickEditCaptionColor.mint => const Color(0xFF99D334),
    QuickEditCaptionColor.black => const Color(0xFF101010),
  };
}

String captionPresetTitle(AppLocalizations l10n, QuickEditCaptionPreset preset) {
  return switch (preset) {
    QuickEditCaptionPreset.minimal => l10n.editCaptionsPresetMinimal,
    QuickEditCaptionPreset.social => l10n.editCaptionsPresetSocial,
    QuickEditCaptionPreset.boldYellow => l10n.editCaptionsPresetBoldYellow,
    QuickEditCaptionPreset.darkBox => l10n.editCaptionsPresetDarkBox,
    QuickEditCaptionPreset.topClean => l10n.editCaptionsPresetTopClean,
    QuickEditCaptionPreset.creatorHighlight => l10n.editCaptionsV32PresetCreatorHighlight,
    QuickEditCaptionPreset.newsHeadline => l10n.editCaptionsV32PresetNewsHeadline,
    QuickEditCaptionPreset.pinkPop => l10n.editCaptionsV34PresetPinkPop,
    QuickEditCaptionPreset.yellowViral => l10n.editCaptionsV34PresetYellowViral,
    QuickEditCaptionPreset.cleanFocus => l10n.editCaptionsV34PresetCleanFocus,
    QuickEditCaptionPreset.custom => l10n.editCaptionsPresetManualBadge,
  };
}

String captionColorLabel(AppLocalizations l10n, QuickEditCaptionColor color) {
  return switch (color) {
    QuickEditCaptionColor.white => l10n.editCaptionsColorWhite,
    QuickEditCaptionColor.yellow => l10n.editCaptionsColorYellow,
    QuickEditCaptionColor.purple => l10n.editCaptionsV32ColorPurple,
    QuickEditCaptionColor.mint => l10n.editCaptionsV32ColorMint,
    QuickEditCaptionColor.pink => l10n.editCaptionsV34ColorPink,
    QuickEditCaptionColor.black => l10n.editCaptionsV34ColorBlack,
  };
}

String captionBoxShapeLabel(AppLocalizations l10n, QuickEditCaptionBoxShape shape) {
  return switch (shape) {
    QuickEditCaptionBoxShape.rectangle => l10n.editCaptionsV34BoxShapeRectangle,
    QuickEditCaptionBoxShape.rounded => l10n.editCaptionsV34BoxShapeRounded,
    QuickEditCaptionBoxShape.pill => l10n.editCaptionsV34BoxShapePill,
  };
}

String captionFontFamilyShortLabel(
  AppLocalizations l10n,
  QuickEditCaptionFontFamily family,
) {
  return switch (family) {
    QuickEditCaptionFontFamily.defaultFamily => l10n.editCaptionsV32FontDefault,
    QuickEditCaptionFontFamily.heebo => l10n.editCaptionsV32FontHeebo,
    QuickEditCaptionFontFamily.rubik => l10n.editCaptionsV32FontRubik,
    QuickEditCaptionFontFamily.assistant => l10n.editCaptionsV32FontAssistant,
    QuickEditCaptionFontFamily.notoSansHebrew => l10n.editCaptionsV32FontNotoSansHebrew,
  };
}

/// One-line summary for the main Captions Look card.
String buildCaptionLookSummaryLine(
  AppLocalizations l10n, {
  required QuickEditCaptionPreset effectivePreset,
  required QuickEditCaptionColor color,
  required QuickEditCaptionWordHighlight wordHighlight,
  required QuickEditCaptionFontFamily fontFamily,
  QuickEditCaptionColor? normalTextColor,
  QuickEditCaptionColor? boxColor,
  QuickEditCaptionBoxShape boxShape = QuickEditCaptionBoxShape.pill,
}) {
  final presetName = captionPresetTitle(l10n, effectivePreset);
  final font = captionFontFamilyShortLabel(l10n, fontFamily);
  final normal = effectiveCaptionNormalTextColor(
    color: color,
    normalTextColor: normalTextColor,
  );

  if (wordHighlight == QuickEditCaptionWordHighlight.box) {
    final box = effectiveCaptionBoxColor(
      color: color,
      wordHighlight: wordHighlight,
      boxColor: boxColor,
    );
    final shape = captionBoxShapeLabel(l10n, boxShape);
    final boxName = captionColorLabel(l10n, box);
    final textName = captionColorLabel(l10n, normal);
    return "$presetName · $shape $boxName · $textName · $font";
  }

  if (wordHighlight == QuickEditCaptionWordHighlight.color) {
    final textName = captionColorLabel(l10n, normal);
    return "$presetName · $textName · $font";
  }

  return "$presetName · $font";
}

/// Style-only detail line for the main Captions Look hero card (no preset name).
String buildCaptionLookStyleDetailLine(
  AppLocalizations l10n, {
  required QuickEditCaptionColor color,
  required QuickEditCaptionWordHighlight wordHighlight,
  required QuickEditCaptionFontFamily fontFamily,
  QuickEditCaptionColor? normalTextColor,
  QuickEditCaptionColor? boxColor,
  QuickEditCaptionBoxShape boxShape = QuickEditCaptionBoxShape.pill,
}) {
  final font = captionFontFamilyShortLabel(l10n, fontFamily);
  final normal = effectiveCaptionNormalTextColor(
    color: color,
    normalTextColor: normalTextColor,
  );

  if (wordHighlight == QuickEditCaptionWordHighlight.box) {
    final box = effectiveCaptionBoxColor(
      color: color,
      wordHighlight: wordHighlight,
      boxColor: boxColor,
    );
    final shape = captionBoxShapeLabel(l10n, boxShape);
    final boxName = captionColorLabel(l10n, box);
    final textName = captionColorLabel(l10n, normal);
    return "$shape $boxName · $textName · $font";
  }

  if (wordHighlight == QuickEditCaptionWordHighlight.color) {
    final textName = captionColorLabel(l10n, normal);
    return "$textName · $font";
  }

  final textName = captionColorLabel(l10n, normal);
  return "$textName · $font";
}

String captionFontSizeShortLabel(
  AppLocalizations l10n,
  QuickEditCaptionFontSize size,
) {
  return switch (size) {
    QuickEditCaptionFontSize.extraSmall => l10n.editCaptionsSizeExtraSmall,
    QuickEditCaptionFontSize.small => l10n.editCaptionsSizeSmall,
    QuickEditCaptionFontSize.medium => l10n.editCaptionsSizeMedium,
    QuickEditCaptionFontSize.large => l10n.editCaptionsSizeLarge,
    QuickEditCaptionFontSize.xLarge => l10n.editCaptionsV32SizeXL,
    QuickEditCaptionFontSize.xxLarge => l10n.editCaptionsV32SizeXXL,
  };
}

/// Two-line compact summary for preset cards (no large preview).
String captionPresetCompactSubtitle(
  AppLocalizations l10n,
  QuickEditCaptionPreset preset,
) {
  final r = captionPresetRecipe(preset);
  if (r == null) return "";
  final line1 = captionPresetTagLine(l10n, preset);
  final line2 =
      "${captionFontFamilyShortLabel(l10n, r.fontFamily)} · ${captionFontSizeShortLabel(l10n, r.fontSize)}";
  if (line1.isEmpty) return line2;
  return "$line1\n$line2";
}

String captionPresetTagLine(
  AppLocalizations l10n,
  QuickEditCaptionPreset preset,
) {
  final r = captionPresetRecipe(preset);
  if (r == null) return "";
  final parts = <String>[];
  if (r.wordHighlight == QuickEditCaptionWordHighlight.box) {
    final box = r.boxColor ??
        effectiveCaptionBoxColor(
          color: r.color,
          wordHighlight: r.wordHighlight,
          boxColor: r.boxColor,
        );
    parts.add(captionBoxShapeLabel(l10n, r.boxShape));
    parts.add(captionColorLabel(l10n, box));
  } else if (r.wordHighlight == QuickEditCaptionWordHighlight.color) {
    parts.add(l10n.editCaptionsV33WordHighlightColor);
  }
  parts.add(captionFontFamilyShortLabel(l10n, r.fontFamily));
  return parts.join(" · ");
}
