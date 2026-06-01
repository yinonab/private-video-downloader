import "package:flutter/material.dart";

import "../../../core/edit/caption_draft_summary.dart";
import "../../../core/theme/linkclip_palette.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

/// Quick Edit — captions auto burn-in + styling + **V2.2** offsets + **V2.3** presets + **V3** UX refresh.
class CaptionsEditorPanel extends StatefulWidget {
  const CaptionsEditorPanel({
    super.key,
    required this.autoCaptionsEnabled,
    required this.stylePreset,
    required this.fontSize,
    required this.fontFamily,
    required this.position,
    required this.color,
    required this.wordHighlight,
    required this.offsetX,
    required this.offsetY,
    required this.onAutoCaptionsChanged,
    required this.onStyleChanged,
    required this.onFontSizeChanged,
    required this.onFontFamilyChanged,
    required this.onPositionChanged,
    required this.onColorChanged,
    required this.onWordHighlightChanged,
    required this.onOffsetReset,
    required this.onOffsetNudgeAss,
    required this.effectiveCaptionPreset,
    required this.onCaptionBuiltInPresetSelected,
    required this.onGenerateCaptionsDraft,
    required this.onRegenerateCaptionsDraftRequested,
    this.captionDraftSegments,
    required this.onEditCaptionsDraft,
    required this.isCaptionDraftGenerating,
    required this.showCaptionDraftTimingStaleHint,
  });

  final bool autoCaptionsEnabled;
  final QuickEditCaptionsStylePreset stylePreset;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionFontFamily fontFamily;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;
  final QuickEditCaptionWordHighlight wordHighlight;
  final int offsetX;
  final int offsetY;

  /// Inferred from current size/position/color/style/offsets ([QuickEditCaptionPreset.custom] if no match).
  final QuickEditCaptionPreset effectiveCaptionPreset;

  /// User picked a named preset (**not** [QuickEditCaptionPreset.custom]).
  final ValueChanged<QuickEditCaptionPreset> onCaptionBuiltInPresetSelected;

  /// V2.4A captions draft (`POST /edits/captions/draft`).
  final VoidCallback onGenerateCaptionsDraft;
  /// When a draft is already loaded; parent shows confirm then re-requests draft API.
  final VoidCallback onRegenerateCaptionsDraftRequested;
  final List<CaptionDraftSegment>? captionDraftSegments;
  final VoidCallback onEditCaptionsDraft;
  final bool isCaptionDraftGenerating;
  /// After trim/speed/source identity changed post-draft.
  final bool showCaptionDraftTimingStaleHint;

  final ValueChanged<bool> onAutoCaptionsChanged;
  final ValueChanged<QuickEditCaptionsStylePreset> onStyleChanged;
  final ValueChanged<QuickEditCaptionFontSize> onFontSizeChanged;
  final ValueChanged<QuickEditCaptionFontFamily> onFontFamilyChanged;
  final ValueChanged<QuickEditCaptionPosition> onPositionChanged;
  final ValueChanged<QuickEditCaptionColor> onColorChanged;
  final ValueChanged<QuickEditCaptionWordHighlight> onWordHighlightChanged;
  final VoidCallback onOffsetReset;

  /// Nudge offsets in ASS PlayRes pixels (typically ± [kQuickEditCaptionsOffsetFineStep]). Screen-absolute axes (not mirrored in RTL).
  final void Function(int dxAss, int dyAss) onOffsetNudgeAss;

  @override
  State<CaptionsEditorPanel> createState() => _CaptionsEditorPanelState();
}

class _CaptionsEditorPanelState extends State<CaptionsEditorPanel> {
  bool _advancedStylingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = context.lcPalette.tiktokAccent;
    final l10n = AppLocalizations.of(context);
    final hasDraft = widget.captionDraftSegments != null &&
        widget.captionDraftSegments!.isNotEmpty;

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CaptionsSectionCard(
            theme: theme,
            scheme: scheme,
            title: l10n.editCaptionsV3AddSectionTitle,
            helper: l10n.editCaptionsSectionSubtitle,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.editCaptionsAutoToggle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: widget.autoCaptionsEnabled,
                  onChanged: widget.onAutoCaptionsChanged,
                ),
              ],
            ),
          ),
          if (widget.autoCaptionsEnabled) ...[
            const SizedBox(height: 12),
            _CaptionsSectionCard(
              theme: theme,
              scheme: scheme,
              title: l10n.editCaptionsDraftTextSectionTitle,
              child: _CaptionsDraftTextSection(
                theme: theme,
                scheme: scheme,
                l10n: l10n,
                hasDraft: hasDraft,
                isGenerating: widget.isCaptionDraftGenerating,
                showStaleHint: widget.showCaptionDraftTimingStaleHint,
                segments: widget.captionDraftSegments,
                onGenerate: widget.onGenerateCaptionsDraft,
                onRegenerate: widget.onRegenerateCaptionsDraftRequested,
                onEditCaptions: widget.onEditCaptionsDraft,
              ),
            ),
            const SizedBox(height: 12),
            _CaptionsSectionCard(
              theme: theme,
              scheme: scheme,
              title: l10n.editCaptionsV3LookSectionTitle,
              helper: l10n.editCaptionsV3LookHelper,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CaptionsPresetSection(
                    accent: accent,
                    theme: theme,
                    l10n: l10n,
                    effectivePreset: widget.effectiveCaptionPreset,
                    onBuiltInSelected: widget.onCaptionBuiltInPresetSelected,
                  ),
                  const SizedBox(height: 4),
                  _CaptionsHorizontalChipSection(
                    scheme: scheme,
                    title: l10n.editCaptionsTextSizeLabel,
                    height: 46,
                    children: [
                      for (final e in _kCaptionFontSizesOrdered)
                        _CaptionChip(
                          label: _captionFontSizeLabel(l10n, e),
                          selected: widget.fontSize == e,
                          scheme: scheme,
                          onTap: () => widget.onFontSizeChanged(e),
                        ),
                    ],
                  ),
                  _CaptionsHorizontalChipSection(
                    scheme: scheme,
                    title: l10n.editCaptionsV32FontLabel,
                    height: 46,
                    children: [
                      for (final f in _kCaptionFontFamiliesOrdered)
                        _CaptionChip(
                          label: _captionFontFamilyLabel(l10n, f),
                          selected: widget.fontFamily == f,
                          scheme: scheme,
                          onTap: () => widget.onFontFamilyChanged(f),
                        ),
                    ],
                  ),
                  _CaptionsChipSection(
                    accent: accent,
                    scheme: scheme,
                    title: l10n.editCaptionsPositionLabel,
                    spacing: () => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CaptionChip(
                          label: l10n.editCaptionsPositionTop,
                          selected:
                              widget.position == QuickEditCaptionPosition.top,
                          scheme: scheme,
                          onTap: () => widget.onPositionChanged(
                            QuickEditCaptionPosition.top,
                          ),
                        ),
                        _CaptionChip(
                          label: l10n.editCaptionsPositionBottom,
                          selected: widget.position ==
                              QuickEditCaptionPosition.bottom,
                          scheme: scheme,
                          onTap: () => widget.onPositionChanged(
                            QuickEditCaptionPosition.bottom,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  _CaptionsAdvancedStylingDisclosure(
                    theme: theme,
                    scheme: scheme,
                    accent: accent,
                    l10n: l10n,
                    expanded: _advancedStylingExpanded,
                    onExpandedChanged: (v) =>
                        setState(() => _advancedStylingExpanded = v),
                    stylePreset: widget.stylePreset,
                    wordHighlight: widget.wordHighlight,
                    color: widget.color,
                    offsetX: widget.offsetX,
                    offsetY: widget.offsetY,
                    onStyleChanged: widget.onStyleChanged,
                    onWordHighlightChanged: widget.onWordHighlightChanged,
                    onColorChanged: widget.onColorChanged,
                    onOffsetReset: widget.onOffsetReset,
                    onOffsetNudge: widget.onOffsetNudgeAss,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CaptionsSectionCard extends StatelessWidget {
  const _CaptionsSectionCard({
    required this.theme,
    required this.scheme,
    required this.title,
    this.helper,
    required this.child,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final String title;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(
          alpha: dark ? 0.34 : 0.48,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            if (helper != null) ...[
              const SizedBox(height: 6),
              Text(
                helper!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.38,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CaptionsDraftTextSection extends StatelessWidget {
  const _CaptionsDraftTextSection({
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.hasDraft,
    required this.isGenerating,
    required this.showStaleHint,
    required this.segments,
    required this.onGenerate,
    required this.onRegenerate,
    required this.onEditCaptions,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final bool hasDraft;
  final bool isGenerating;
  final bool showStaleHint;
  final List<CaptionDraftSegment>? segments;
  final VoidCallback onGenerate;
  final VoidCallback onRegenerate;
  final VoidCallback onEditCaptions;

  @override
  Widget build(BuildContext context) {
    final canEditCaptions = hasDraft && !showStaleHint && !isGenerating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showStaleHint && !isGenerating) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.22),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                l10n.editCaptionsV31StaleBeforeEdit,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.88),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!hasDraft && !isGenerating) ...[
          Text(
            l10n.editCaptionsV3DraftFlowHelper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.38,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              onPressed: onGenerate,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l10n.editCaptionsDraftGenerateButton),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.editCaptionsDraftLongVideoHelper,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
        if (isGenerating)
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.editCaptionsDraftGenerating,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        if (hasDraft && !isGenerating) ...[
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: scheme.primary.withValues(alpha: 0.88),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.editCaptionsV3DraftReady,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            captionDraftSummaryLine(l10n, segments!),
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.editCaptionsV31DraftEditHelper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (canEditCaptions)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                onPressed: onEditCaptions,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.editCaptionsV31EditCaptionsButton),
              ),
            ),
          if (canEditCaptions) const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: onRegenerate,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.onSurface.withValues(alpha: 0.9),
                side: BorderSide(color: scheme.outline.withValues(alpha: 0.38)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(l10n.editCaptionsDraftRegenerateButton),
            ),
          ),
        ],
      ],
    );
  }
}

class _CaptionsAdvancedStylingDisclosure extends StatelessWidget {
  const _CaptionsAdvancedStylingDisclosure({
    required this.theme,
    required this.scheme,
    required this.accent,
    required this.l10n,
    required this.expanded,
    required this.onExpandedChanged,
    required this.stylePreset,
    required this.wordHighlight,
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.onStyleChanged,
    required this.onWordHighlightChanged,
    required this.onColorChanged,
    required this.onOffsetReset,
    required this.onOffsetNudge,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final Color accent;
  final AppLocalizations l10n;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final QuickEditCaptionsStylePreset stylePreset;
  final QuickEditCaptionWordHighlight wordHighlight;
  final QuickEditCaptionColor color;
  final int offsetX;
  final int offsetY;
  final ValueChanged<QuickEditCaptionsStylePreset> onStyleChanged;
  final ValueChanged<QuickEditCaptionWordHighlight> onWordHighlightChanged;
  final ValueChanged<QuickEditCaptionColor> onColorChanged;
  final VoidCallback onOffsetReset;
  final void Function(int dxAss, int dyAss) onOffsetNudge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onExpandedChanged(!expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.editCaptionsV3MoreStylingTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface.withValues(alpha: 0.88),
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 22,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 4),
          _CaptionsHorizontalChipSection(
            scheme: scheme,
            title: l10n.editCaptionsV33WordHighlightLabel,
            height: 46,
            children: [
              for (final h in _kCaptionWordHighlightsOrdered)
                _CaptionChip(
                  label: _captionWordHighlightLabel(l10n, h),
                  selected: wordHighlight == h,
                  scheme: scheme,
                  onTap: () => onWordHighlightChanged(h),
                ),
            ],
          ),
          _CaptionsChipSection(
            accent: accent,
            scheme: scheme,
            title: l10n.editCaptionsV32AccentLabel,
            spacing: () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CaptionChip(
                  label: l10n.editCaptionsColorWhite,
                  selected: color == QuickEditCaptionColor.white,
                  scheme: scheme,
                  onTap: () => onColorChanged(QuickEditCaptionColor.white),
                ),
                _CaptionChip(
                  label: l10n.editCaptionsColorYellow,
                  selected: color == QuickEditCaptionColor.yellow,
                  scheme: scheme,
                  onTap: () => onColorChanged(QuickEditCaptionColor.yellow),
                ),
                _CaptionChip(
                  label: l10n.editCaptionsV32ColorPurple,
                  selected: color == QuickEditCaptionColor.purple,
                  scheme: scheme,
                  onTap: () => onColorChanged(QuickEditCaptionColor.purple),
                ),
                _CaptionChip(
                  label: l10n.editCaptionsV32ColorMint,
                  selected: color == QuickEditCaptionColor.mint,
                  scheme: scheme,
                  onTap: () => onColorChanged(QuickEditCaptionColor.mint),
                ),
              ],
            ),
          ),
          _CaptionsChipSection(
            accent: accent,
            scheme: scheme,
            title: l10n.editCaptionsStyleLabel,
            spacing: () => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _kCaptionStylesOrdered)
                  _CaptionChip(
                    label: _captionStyleLabel(l10n, s),
                    selected: stylePreset == s,
                    scheme: scheme,
                    onTap: () => onStyleChanged(s),
                  ),
              ],
            ),
          ),
          _CaptionsFineTuneSection(
            accent: accent,
            scheme: scheme,
            theme: theme,
            l10n: l10n,
            offsetX: offsetX,
            offsetY: offsetY,
            onReset: onOffsetReset,
            onNudge: onOffsetNudge,
          ),
        ],
      ],
    );
  }
}


String _captionsPresetChipLabel(AppLocalizations l10n, QuickEditCaptionPreset preset) {
  return switch (preset) {
    QuickEditCaptionPreset.minimal => l10n.editCaptionsPresetMinimal,
    QuickEditCaptionPreset.social => l10n.editCaptionsPresetSocial,
    QuickEditCaptionPreset.boldYellow => l10n.editCaptionsPresetBoldYellow,
    QuickEditCaptionPreset.darkBox => l10n.editCaptionsPresetDarkBox,
    QuickEditCaptionPreset.topClean => l10n.editCaptionsPresetTopClean,
    QuickEditCaptionPreset.creatorHighlight => l10n.editCaptionsV32PresetCreatorHighlight,
    QuickEditCaptionPreset.newsHeadline => l10n.editCaptionsV32PresetNewsHeadline,
    QuickEditCaptionPreset.custom => "",
  };
}

const _kCaptionFontSizesOrdered = [
  QuickEditCaptionFontSize.extraSmall,
  QuickEditCaptionFontSize.small,
  QuickEditCaptionFontSize.medium,
  QuickEditCaptionFontSize.large,
  QuickEditCaptionFontSize.xLarge,
  QuickEditCaptionFontSize.xxLarge,
];

const _kCaptionFontFamiliesOrdered = [
  QuickEditCaptionFontFamily.defaultFamily,
  QuickEditCaptionFontFamily.heebo,
  QuickEditCaptionFontFamily.rubik,
  QuickEditCaptionFontFamily.assistant,
  QuickEditCaptionFontFamily.notoSansHebrew,
];

const _kCaptionWordHighlightsOrdered = [
  QuickEditCaptionWordHighlight.none,
  QuickEditCaptionWordHighlight.color,
  QuickEditCaptionWordHighlight.box,
];

const _kCaptionStylesOrdered = [
  QuickEditCaptionsStylePreset.clean,
  QuickEditCaptionsStylePreset.bold,
  QuickEditCaptionsStylePreset.darkBox,
  QuickEditCaptionsStylePreset.cleanPro,
  QuickEditCaptionsStylePreset.boldSocial,
  QuickEditCaptionsStylePreset.yellowHeadline,
  QuickEditCaptionsStylePreset.darkBubble,
  QuickEditCaptionsStylePreset.highlightBox,
];

String _captionFontSizeLabel(AppLocalizations l10n, QuickEditCaptionFontSize size) {
  return switch (size) {
    QuickEditCaptionFontSize.extraSmall => l10n.editCaptionsSizeExtraSmall,
    QuickEditCaptionFontSize.small => l10n.editCaptionsSizeSmall,
    QuickEditCaptionFontSize.medium => l10n.editCaptionsSizeMedium,
    QuickEditCaptionFontSize.large => l10n.editCaptionsSizeLarge,
    QuickEditCaptionFontSize.xLarge => l10n.editCaptionsV32SizeXL,
    QuickEditCaptionFontSize.xxLarge => l10n.editCaptionsV32SizeXXL,
  };
}

String _captionWordHighlightLabel(
  AppLocalizations l10n,
  QuickEditCaptionWordHighlight mode,
) {
  return switch (mode) {
    QuickEditCaptionWordHighlight.none => l10n.editCaptionsV33WordHighlightOff,
    QuickEditCaptionWordHighlight.color => l10n.editCaptionsV33WordHighlightColor,
    QuickEditCaptionWordHighlight.box => l10n.editCaptionsV33WordHighlightBox,
  };
}

String _captionFontFamilyLabel(AppLocalizations l10n, QuickEditCaptionFontFamily family) {
  return switch (family) {
    QuickEditCaptionFontFamily.defaultFamily => l10n.editCaptionsV32FontDefault,
    QuickEditCaptionFontFamily.heebo => l10n.editCaptionsV32FontHeebo,
    QuickEditCaptionFontFamily.rubik => l10n.editCaptionsV32FontRubik,
    QuickEditCaptionFontFamily.assistant => l10n.editCaptionsV32FontAssistant,
    QuickEditCaptionFontFamily.notoSansHebrew => l10n.editCaptionsV32FontNotoSansHebrew,
  };
}

String _captionStyleLabel(AppLocalizations l10n, QuickEditCaptionsStylePreset style) {
  return switch (style) {
    QuickEditCaptionsStylePreset.clean => l10n.editCaptionsStyleClean,
    QuickEditCaptionsStylePreset.bold => l10n.editCaptionsStyleBold,
    QuickEditCaptionsStylePreset.darkBox => l10n.editCaptionsStyleDarkBox,
    QuickEditCaptionsStylePreset.cleanPro => l10n.editCaptionsV32StyleCleanPro,
    QuickEditCaptionsStylePreset.boldSocial => l10n.editCaptionsV32StyleBoldSocial,
    QuickEditCaptionsStylePreset.yellowHeadline => l10n.editCaptionsV32StyleYellowHeadline,
    QuickEditCaptionsStylePreset.darkBubble => l10n.editCaptionsV32StyleDarkBubble,
    QuickEditCaptionsStylePreset.highlightBox => l10n.editCaptionsV32StyleHighlightBox,
  };
}

/// Preset chips (built-in only); [QuickEditCaptionPreset.custom] surfaced as Manual badge beside title.
class _CaptionsPresetSection extends StatelessWidget {
  const _CaptionsPresetSection({
    required this.accent,
    required this.theme,
    required this.l10n,
    required this.effectivePreset,
    required this.onBuiltInSelected,
  });

  final Color accent;
  final ThemeData theme;
  final AppLocalizations l10n;
  final QuickEditCaptionPreset effectivePreset;
  final ValueChanged<QuickEditCaptionPreset> onBuiltInSelected;

  bool get _isManual =>
      effectivePreset == QuickEditCaptionPreset.custom;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    Widget? badge;
    if (_isManual) {
      badge = Semantics(
        label: l10n.editCaptionsPresetManualBadge,
        container: true,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
            color: scheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.38 : 0.52),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              l10n.editCaptionsPresetManualBadge,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.06,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.editCaptionsPresetLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10),
                  child: badge,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, end: 4),
            child: SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: kQuickEditCaptionBuiltInPresetsOrdered.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = kQuickEditCaptionBuiltInPresetsOrdered[i];
                  return _CaptionChip(
                    label: _captionsPresetChipLabel(l10n, p),
                    selected: effectivePreset == p,
                    scheme: scheme,
                    onTap: () => onBuiltInSelected(p),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arrow pad uses screen-relative up/down/left/right (consistent in RTL).
class _CaptionsFineTuneSection extends StatelessWidget {
  const _CaptionsFineTuneSection({
    required this.accent,
    required this.scheme,
    required this.theme,
    required this.l10n,
    required this.offsetX,
    required this.offsetY,
    required this.onReset,
    required this.onNudge,
  });

  final Color accent;
  final ColorScheme scheme;
  final ThemeData theme;
  final AppLocalizations l10n;
  final int offsetX;
  final int offsetY;
  final VoidCallback onReset;
  final void Function(int dxAss, int dyAss) onNudge;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;
    final mutedAccent = accent.withValues(alpha: dark ? 0.55 : 0.85);
    final step = kQuickEditCaptionsOffsetFineStep;

    Widget padBtn({required Widget icon, required VoidCallback onPressed}) {
      return Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
        shape: CircleBorder(side: BorderSide(color: mutedAccent.withValues(alpha: 0.22))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: IconTheme.merge(
              data: IconThemeData(size: 20, color: scheme.onSurface.withValues(alpha: 0.72)),
              child: icon,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.editCaptionsFineTuneTitle,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.88),
                  ),
                ),
              ),
              Text(
                l10n.editCaptionsOffsetCompact(offsetX, offsetY),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                padBtn(
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  onPressed: () => onNudge(0, -step),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    padBtn(
                      icon: const Icon(Icons.keyboard_arrow_left_rounded),
                      onPressed: () => onNudge(-step, 0),
                    ),
                    const SizedBox(width: 8),
                    padBtn(
                      icon: const Icon(Icons.keyboard_arrow_right_rounded),
                      onPressed: () => onNudge(step, 0),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                padBtn(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: () => onNudge(0, step),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              ),
              child: Text(l10n.editCaptionsResetPosition),
            ),
          ),
        ],
      ),
    );
  }
}

typedef _SpacingFn = Wrap Function();

class _CaptionsHorizontalChipSection extends StatelessWidget {
  const _CaptionsHorizontalChipSection({
    required this.scheme,
    required this.title,
    required this.height,
    required this.children,
  });

  final ColorScheme scheme;
  final String title;
  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => children[i],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionsChipSection extends StatelessWidget {
  const _CaptionsChipSection({
    required this.accent,
    required this.scheme,
    required this.title,
    required this.spacing,
  });

  final Color accent;
  final ColorScheme scheme;
  final String title;
  final _SpacingFn spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 8),
          spacing(),
        ],
      ),
    );
  }
}

class _CaptionChip extends StatelessWidget {
  const _CaptionChip({
    required this.label,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: dark ? 0.78 : 0.62)
        : scheme.outline.withValues(alpha: 0.26);
    final bg = selected
        ? Color.alphaBlend(
            scheme.primary.withValues(alpha: dark ? 0.32 : 0.16),
            scheme.surfaceContainerHighest,
          )
        : scheme.surface.withValues(alpha: dark ? 0.42 : 0.72);
    final textColor = selected
        ? (dark
            ? scheme.onPrimaryContainer.withValues(alpha: 0.98)
            : scheme.primary.withValues(alpha: 0.94))
        : scheme.onSurface.withValues(alpha: 0.82);

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.12,
          color: textColor,
        ),
      ),
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              child: child,
            ),
    );
  }
}
