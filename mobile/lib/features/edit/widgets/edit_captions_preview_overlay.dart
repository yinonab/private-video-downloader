import "dart:math" as math;

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../core/edit/caption_preview_layout.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

export "../../../core/edit/caption_preview_layout.dart" show CaptionPreviewLayout;

/// Caption overlay aligned to ASS burn-in anchors (PlayRes 960×540 scaled to frame).
class EditCaptionsPreviewOverlay extends StatelessWidget {
  const EditCaptionsPreviewOverlay({
    super.key,
    required this.l10n,
    this.layout = CaptionPreviewLayout.standard,
    this.showPreviewLabel = true,
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
    this.outlineEnabled = false,
    this.outlineColor,
    this.outlineWidth = QuickEditCaptionOutlineWidth.medium,
    required this.offsetXAss,
    required this.offsetYAss,
    this.sampleText,
    this.highlightWordIndex,
    this.animateMotion = false,
    this.motionDuration = const Duration(milliseconds: 180),
  });

  final AppLocalizations l10n;
  final CaptionPreviewLayout layout;
  final bool showPreviewLabel;
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
  final bool outlineEnabled;
  final QuickEditCaptionColor? outlineColor;
  final QuickEditCaptionOutlineWidth outlineWidth;
  final int offsetXAss;
  final int offsetYAss;
  final String? sampleText;
  final int? highlightWordIndex;
  final bool animateMotion;
  final Duration motionDuration;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = math.max(c.maxWidth, 1.0);
        final h = math.max(c.maxHeight, 1.0);
        final fz = captionPreviewFontSizePx(fontSize, h);
        final hPad = captionPreviewHorizontalPadPx(w);
        final displayText = sampleText ?? l10n.editCaptionsSampleLabel;
        final rtl = captionPreviewIsRtl(displayText);
        final parts = captionPreviewHighlightParts(
          displayText,
          highlightWordIndex: highlightWordIndex,
        );

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

        final boldStyle = switch (stylePreset) {
          QuickEditCaptionsStylePreset.bold ||
          QuickEditCaptionsStylePreset.boldSocial ||
          QuickEditCaptionsStylePreset.yellowHeadline ||
          QuickEditCaptionsStylePreset.highlightBox =>
            FontWeight.w700,
          _ => FontWeight.w600,
        };

        final useShadows = !outlineEnabled &&
            stylePreset != QuickEditCaptionsStylePreset.darkBox &&
            stylePreset != QuickEditCaptionsStylePreset.darkBubble &&
            stylePreset != QuickEditCaptionsStylePreset.highlightBox;

        TextStyle baseStyle({
          Color? textColor,
          FontWeight? weight,
          bool stroke = false,
        }) {
          final style = TextStyle(
            color: stroke ? null : (textColor ?? normal),
            fontSize: fz,
            fontWeight: weight ?? boldStyle,
            height: 1.12,
          );
          final withFont = _applyPreviewFont(fontFamily, style);
          if (!stroke || !outlineEnabled) return withFont;
          final strokeColor = _accentColor(outlineColor ?? QuickEditCaptionColor.white);
          return withFont.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = captionPreviewOutlineWidthPx(outlineWidth, fz)
              ..color = strokeColor,
          );
        }

        List<Shadow>? shadowsForPreset() {
          if (!useShadows) return null;
          return switch (stylePreset) {
            QuickEditCaptionsStylePreset.yellowHeadline ||
            QuickEditCaptionsStylePreset.bold ||
            QuickEditCaptionsStylePreset.boldSocial =>
              _strongShadows(fz),
            QuickEditCaptionsStylePreset.cleanPro => [
              Shadow(blurRadius: fz * 0.38, color: Colors.black.withValues(alpha: 0.84)),
              Shadow(
                blurRadius: 0,
                offset: Offset(0, fz * 0.02),
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ],
            QuickEditCaptionsStylePreset.clean => [
              Shadow(blurRadius: fz * 0.34, color: Colors.black.withValues(alpha: 0.82)),
            ],
            _ => null,
          };
        }

        Widget withOutlineLayer(
          Widget child,
          Widget Function({required bool stroke}) buildLayer,
        ) {
          if (!outlineEnabled) return child;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              buildLayer(stroke: true),
              buildLayer(stroke: false),
            ],
          );
        }

        final boxPadH = math.max(4.0, fz * 0.28);
        final boxPadV = math.max(2.0, fz * 0.16);
        final boxRadius = switch (boxShape) {
          QuickEditCaptionBoxShape.pill => 999.0,
          QuickEditCaptionBoxShape.rounded => math.min(12.0, fz * 0.35),
          QuickEditCaptionBoxShape.rectangle => 2.0,
        };

        Widget captionTextWidget({
          Color? textColor,
          List<Shadow>? shadows,
          FontWeight? weight,
        }) {
          if (wordHighlight == QuickEditCaptionWordHighlight.none ||
              parts.highlight.isEmpty) {
            return withOutlineLayer(
              Text(
                displayText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: baseStyle(textColor: textColor, weight: weight)
                    .copyWith(shadows: shadows),
              ),
              ({required bool stroke}) => Text(
                displayText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: baseStyle(textColor: textColor, weight: weight, stroke: stroke)
                    .copyWith(shadows: stroke ? null : shadows),
              ),
            );
          }

          final normalStyle =
              baseStyle(textColor: normal, weight: weight).copyWith(shadows: shadows);
          final hiStyle = switch (wordHighlight) {
            QuickEditCaptionWordHighlight.color => normalStyle.copyWith(color: active),
            QuickEditCaptionWordHighlight.box => normalStyle.copyWith(color: active),
            QuickEditCaptionWordHighlight.none => normalStyle,
          };

          final highlightSpan = wordHighlight == QuickEditCaptionWordHighlight.box
              ? WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: boxPadH, vertical: boxPadV),
                    decoration: BoxDecoration(
                      color: boxFill.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(boxRadius),
                    ),
                    child: Text(
                      parts.highlight,
                      style: hiStyle.copyWith(backgroundColor: Colors.transparent),
                    ),
                  ),
                )
              : TextSpan(text: parts.highlight, style: hiStyle);

          return withOutlineLayer(
            RichText(
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  if (parts.before.isNotEmpty)
                    TextSpan(text: parts.before, style: normalStyle),
                  highlightSpan,
                ],
              ),
            ),
            ({required bool stroke}) {
              final layerNormal = baseStyle(textColor: normal, weight: weight, stroke: stroke)
                  .copyWith(shadows: stroke ? null : shadows);
              final layerHi = switch (wordHighlight) {
                QuickEditCaptionWordHighlight.color =>
                  layerNormal.copyWith(color: stroke ? null : active),
                QuickEditCaptionWordHighlight.box => layerNormal.copyWith(color: stroke ? null : active),
                QuickEditCaptionWordHighlight.none => layerNormal,
              };
              final layerHighlightSpan = wordHighlight == QuickEditCaptionWordHighlight.box
                  ? WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: boxPadH, vertical: boxPadV),
                        decoration: BoxDecoration(
                          color: stroke ? Colors.transparent : boxFill.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(boxRadius),
                        ),
                        child: Text(
                          parts.highlight,
                          style: layerHi.copyWith(backgroundColor: Colors.transparent),
                        ),
                      ),
                    )
                  : TextSpan(text: parts.highlight, style: layerHi);
              return RichText(
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    if (parts.before.isNotEmpty)
                      TextSpan(text: parts.before, style: layerNormal),
                    layerHighlightSpan,
                  ],
                ),
              );
            },
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
                borderRadius: BorderRadius.circular(math.max(4, fz * 0.22)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: fz * 0.42, vertical: fz * 0.2),
                child: captionTextWidget(textColor: Colors.white),
              ),
            );
            break;
          case QuickEditCaptionsStylePreset.highlightBox:
            captionBody = DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(math.max(4, fz * 0.22)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: fz * 0.42, vertical: fz * 0.2),
                child: captionTextWidget(
                  textColor: _highlightBoxTextColor(color),
                  weight: FontWeight.w700,
                ),
              ),
            );
            break;
          case QuickEditCaptionsStylePreset.yellowHeadline:
            captionBody = captionTextWidget(
              textColor: const Color(0xFFFFD966),
              shadows: shadowsForPreset(),
            );
            break;
          case QuickEditCaptionsStylePreset.bold:
          case QuickEditCaptionsStylePreset.boldSocial:
          case QuickEditCaptionsStylePreset.cleanPro:
          case QuickEditCaptionsStylePreset.clean:
            captionBody = captionTextWidget(shadows: shadowsForPreset());
        }

        final previewLabel = showPreviewLabel && layout == CaptionPreviewLayout.standard
            ? DecoratedBox(
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
              )
            : null;

        final isStage = layout == CaptionPreviewLayout.stage;
        final styleKey = ValueKey<Object>(
          (
            stylePreset,
            fontSize,
            fontFamily,
            color,
            wordHighlight,
            normalTextColor,
            activeTextColor,
            boxColor,
            boxShape,
            outlineEnabled,
            outlineColor,
            outlineWidth,
            sampleText,
            highlightWordIndex,
            offsetXAss,
            offsetYAss,
          ),
        );

        final captionColumn = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (previewLabel != null && position != QuickEditCaptionPosition.bottom) ...[
              previewLabel,
              const SizedBox(height: 4),
            ],
            isStage && animateMotion
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: KeyedSubtree(key: styleKey, child: captionBody),
                  )
                : captionBody,
            if (previewLabel != null && position == QuickEditCaptionPosition.bottom) ...[
              const SizedBox(height: 4),
              previewLabel,
            ],
          ],
        );

        final translate = computeCaptionPreviewTranslate(
          width: w,
          height: h,
          layout: layout,
          position: position,
          offsetXAss: offsetXAss,
          offsetYAss: offsetYAss,
        );
        final bottom = position == QuickEditCaptionPosition.bottom;

        final positioned = Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: captionColumn,
          ),
        );

        final aligned = Align(
          alignment: bottom ? Alignment.bottomCenter : Alignment.topCenter,
          child: isStage && animateMotion
              ? _AnimatedCaptionTranslate(
                  target: translate,
                  duration: motionDuration,
                  child: positioned,
                )
              : Transform.translate(offset: translate, child: positioned),
        );

        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [aligned],
        );
      },
    );
  }
}

class _AnimatedCaptionTranslate extends StatefulWidget {
  const _AnimatedCaptionTranslate({
    required this.target,
    required this.duration,
    required this.child,
  });

  final Offset target;
  final Duration duration;
  final Widget child;

  @override
  State<_AnimatedCaptionTranslate> createState() => _AnimatedCaptionTranslateState();
}

class _AnimatedCaptionTranslateState extends State<_AnimatedCaptionTranslate>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;
  Offset _current = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = AlwaysStoppedAnimation(widget.target);
    _current = widget.target;
    _ctrl.addListener(() {
      setState(() => _current = _anim.value);
    });
  }

  @override
  void didUpdateWidget(_AnimatedCaptionTranslate old) {
    super.didUpdateWidget(old);
    if (old.target == widget.target && old.duration == widget.duration) return;
    _anim = Tween<Offset>(begin: _current, end: widget.target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.duration = widget.duration;
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(offset: _current, child: widget.child);
  }
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

List<Shadow> _strongShadows(double fz) => [
      Shadow(
        blurRadius: fz * 0.42,
        color: Colors.black.withValues(alpha: 0.9),
      ),
      Shadow(
        blurRadius: 0,
        offset: Offset(0, fz * 0.04),
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
