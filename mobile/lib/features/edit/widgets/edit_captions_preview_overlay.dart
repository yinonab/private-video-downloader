import "dart:math" as math;

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

/// Approximate captions on the editor video frame (upright; not rotated with preview).
/// Rough ASS PlayRes parity via [kCaptionAssPlayResX] / [kCaptionAssPlayResY].
class EditCaptionsPreviewOverlay extends StatelessWidget {
  const EditCaptionsPreviewOverlay({
    super.key,
    required this.l10n,
    required this.stylePreset,
    required this.fontSize,
    required this.fontFamily,
    required this.position,
    required this.color,
    required this.wordHighlight,
    this.normalTextColor,
    this.activeTextColor,
    this.boxColor,
    this.boxShape = QuickEditCaptionBoxShape.pill,
    required this.offsetXAss,
    required this.offsetYAss,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionsStylePreset stylePreset;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionFontFamily fontFamily;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;
  final QuickEditCaptionWordHighlight wordHighlight;
  final QuickEditCaptionColor? normalTextColor;
  final QuickEditCaptionColor? activeTextColor;
  final QuickEditCaptionColor? boxColor;
  final QuickEditCaptionBoxShape boxShape;
  final int offsetXAss;
  final int offsetYAss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColor(color);
    final normal = _accentColor(
      effectiveCaptionNormalTextColor(
        color: color,
        normalTextColor: normalTextColor,
      ),
    );
    final active = _accentColor(
      effectiveCaptionActiveTextColor(
        color: color,
        wordHighlight: wordHighlight,
        normalTextColor: normalTextColor,
        activeTextColor: activeTextColor,
        boxColor: boxColor,
      ),
    );
    final boxFill = _accentColor(
      effectiveCaptionBoxColor(
        color: color,
        wordHighlight: wordHighlight,
        boxColor: boxColor,
      ),
    );
    final fz = switch (fontSize) {
      QuickEditCaptionFontSize.extraSmall => 9.6,
      QuickEditCaptionFontSize.small => 10.8,
      QuickEditCaptionFontSize.medium => 12.6,
      QuickEditCaptionFontSize.large => 14.8,
      QuickEditCaptionFontSize.xLarge => 17.2,
      QuickEditCaptionFontSize.xxLarge => 20.0,
    };

    final boldStyle = switch (stylePreset) {
      QuickEditCaptionsStylePreset.bold ||
      QuickEditCaptionsStylePreset.boldSocial ||
      QuickEditCaptionsStylePreset.yellowHeadline ||
      QuickEditCaptionsStylePreset.highlightBox =>
        FontWeight.w700,
      _ => FontWeight.w500,
    };

    TextStyle baseStyle({Color? textColor, FontWeight? weight}) {
      final style = TextStyle(
        color: textColor ?? accent,
        fontSize: fz,
        fontWeight: weight ?? boldStyle,
        height: 1.15,
      );
      return _applyPreviewFont(fontFamily, style);
    }

    final sampleFull = l10n.editCaptionsSampleLabel;
    final sampleParts = _sampleHighlightParts(sampleFull);

    Widget sampleText({Color? textColor, List<Shadow>? shadows, FontWeight? weight}) {
      if (wordHighlight == QuickEditCaptionWordHighlight.none) {
        return Text(
          sampleFull,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: baseStyle(textColor: textColor, weight: weight).copyWith(shadows: shadows),
        );
      }

      final normalStyle = baseStyle(textColor: normal, weight: weight).copyWith(shadows: shadows);
      final hiStyle = switch (wordHighlight) {
        QuickEditCaptionWordHighlight.color => normalStyle.copyWith(color: active),
        QuickEditCaptionWordHighlight.box => normalStyle.copyWith(
            color: active,
            backgroundColor: boxFill.withValues(alpha: 0.92),
          ).copyWith(
            // Approximate box shape via padding + radius on highlight span only.
          ),
        QuickEditCaptionWordHighlight.none => normalStyle,
      };

      final highlightSpan = wordHighlight == QuickEditCaptionWordHighlight.box
          ? WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: boxFill.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(
                    switch (boxShape) {
                      QuickEditCaptionBoxShape.pill => 999,
                      QuickEditCaptionBoxShape.rounded => 8,
                      QuickEditCaptionBoxShape.rectangle => 2,
                    },
                  ),
                ),
                child: Text(
                  sampleParts.highlight,
                  style: hiStyle.copyWith(backgroundColor: Colors.transparent),
                ),
              ),
            )
          : TextSpan(text: sampleParts.highlight, style: hiStyle);

      return RichText(
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            if (sampleParts.before.isNotEmpty)
              TextSpan(text: sampleParts.before, style: normalStyle),
            highlightSpan,
          ],
        ),
      );
    }

    late final Widget captionBody;
    switch (stylePreset) {
      case QuickEditCaptionsStylePreset.darkBox:
      case QuickEditCaptionsStylePreset.darkBubble:
        captionBody = DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: stylePreset == QuickEditCaptionsStylePreset.darkBubble ? 0.72 : 0.78,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: sampleText(textColor: Colors.white),
          ),
        );
        break;
      case QuickEditCaptionsStylePreset.highlightBox:
        captionBody = DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: sampleText(
              textColor: _highlightBoxTextColor(color),
              weight: FontWeight.w700,
            ),
          ),
        );
        break;
      case QuickEditCaptionsStylePreset.yellowHeadline:
        captionBody = sampleText(
          textColor: const Color(0xFFFFD966),
          shadows: _strongShadows(),
        );
        break;
      case QuickEditCaptionsStylePreset.bold:
      case QuickEditCaptionsStylePreset.boldSocial:
        captionBody = sampleText(shadows: _strongShadows());
        break;
      case QuickEditCaptionsStylePreset.cleanPro:
        captionBody = sampleText(
          shadows: [
            Shadow(
              blurRadius: 9,
              color: Colors.black.withValues(alpha: 0.84),
            ),
            Shadow(
              blurRadius: 0,
              offset: const Offset(0, 0.5),
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ],
        );
        break;
      case QuickEditCaptionsStylePreset.clean:
        captionBody = sampleText(
          shadows: [
            Shadow(
              blurRadius: 8,
              color: Colors.black.withValues(alpha: 0.82),
            ),
          ],
        );
    }

    final previewLabel = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        child: Text(
          l10n.editCaptionsV3PreviewLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
            fontSize: 9.5,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final w = math.max(c.maxWidth, 1.0);
        final h = math.max(c.maxHeight, 1.0);
        final sx = w / kCaptionAssPlayResX;
        final sy = h / kCaptionAssPlayResY;
        final dx = offsetXAss * sx;
        final dy = offsetYAss * sy;
        final bottom = position == QuickEditCaptionPosition.bottom;
        final baseY = bottom ? (-h * 0.068) : (h * 0.068);
        final fx = dx.clamp(-w * 0.36, w * 0.36).toDouble();
        final fy = (baseY + dy)
            .clamp(
              bottom ? -h * 0.34 : -h * 0.05,
              bottom ? h * 0.05 : h * 0.34,
            )
            .toDouble();

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Align(
              alignment:
                  bottom ? Alignment.bottomCenter : Alignment.topCenter,
              child: Transform.translate(
                offset: Offset(fx, fy),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!bottom) ...[
                        previewLabel,
                        const SizedBox(height: 4),
                      ],
                      captionBody,
                      if (bottom) ...[
                        const SizedBox(height: 4),
                        previewLabel,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

({String before, String highlight}) _sampleHighlightParts(String full) {
  final trimmed = full.trim();
  final parts = trimmed.split(RegExp(r"\s+"));
  if (parts.length < 2) {
    return (before: "", highlight: trimmed);
  }
  final highlight = parts.last;
  final before = "${parts.sublist(0, parts.length - 1).join(" ")} ";
  return (before: before, highlight: highlight);
}

Color _accentColor(QuickEditCaptionColor color) {
  return switch (color) {
    QuickEditCaptionColor.white => Colors.white,
    QuickEditCaptionColor.yellow => const Color(0xFFFFD966),
    QuickEditCaptionColor.purple => const Color(0xFF8B5CF6),
    QuickEditCaptionColor.pink => const Color(0xFFFF5C8A),
    QuickEditCaptionColor.mint => const Color(0xFF99D334),
    QuickEditCaptionColor.black => const Color(0xFF101010),
  };
}

Color _highlightBoxTextColor(QuickEditCaptionColor color) {
  return switch (color) {
    QuickEditCaptionColor.yellow ||
    QuickEditCaptionColor.mint ||
    QuickEditCaptionColor.white ||
    QuickEditCaptionColor.pink =>
      const Color(0xFF101010),
    QuickEditCaptionColor.purple || QuickEditCaptionColor.black => Colors.white,
  };
}

List<Shadow> _strongShadows() => [
      Shadow(
        blurRadius: 10,
        color: Colors.black.withValues(alpha: 0.9),
      ),
      Shadow(
        blurRadius: 0,
        offset: const Offset(0, 1),
        color: Colors.black.withValues(alpha: 0.88),
      ),
    ];

TextStyle _applyPreviewFont(QuickEditCaptionFontFamily family, TextStyle base) {
  return switch (family) {
    QuickEditCaptionFontFamily.heebo => GoogleFonts.heebo(textStyle: base),
    QuickEditCaptionFontFamily.rubik => GoogleFonts.rubik(textStyle: base),
    QuickEditCaptionFontFamily.assistant => GoogleFonts.assistant(textStyle: base),
    QuickEditCaptionFontFamily.notoSansHebrew =>
      GoogleFonts.notoSansHebrew(textStyle: base),
    QuickEditCaptionFontFamily.defaultFamily =>
      GoogleFonts.notoSansHebrew(textStyle: base),
  };
}
