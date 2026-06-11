import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../core/edit/caption_draft_summary.dart";
import "../../../core/edit/caption_look_summary.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";
import "caption_look/caption_look_widgets.dart";

/// Quick Edit — captions panel (V3.4H/I): compact status, hero look, optional draft.
class CaptionsEditorPanel extends StatelessWidget {
  const CaptionsEditorPanel({
    super.key,
    required this.autoCaptionsEnabled,
    required this.effectiveCaptionPreset,
    required this.lookStyleDetailLine,
    required this.lookColor,
    required this.lookWordHighlight,
    required this.lookFontFamily,
    this.lookNormalTextColor,
    this.lookActiveTextColor,
    this.lookBoxColor,
    required this.lookBoxShape,
    required this.onCustomizeLook,
    required this.onAutoCaptionsChanged,
    required this.onGenerateCaptionsDraft,
    required this.onRegenerateCaptionsDraftRequested,
    this.captionDraftSegments,
    required this.onEditCaptionsDraft,
    required this.isCaptionDraftGenerating,
    required this.showCaptionDraftTimingStaleHint,
  });

  final bool autoCaptionsEnabled;
  final QuickEditCaptionPreset effectiveCaptionPreset;
  final String lookStyleDetailLine;
  final QuickEditCaptionColor lookColor;
  final QuickEditCaptionWordHighlight lookWordHighlight;
  final QuickEditCaptionFontFamily lookFontFamily;
  final QuickEditCaptionColor? lookNormalTextColor;
  final QuickEditCaptionColor? lookActiveTextColor;
  final QuickEditCaptionColor? lookBoxColor;
  final QuickEditCaptionBoxShape lookBoxShape;
  final VoidCallback onCustomizeLook;
  final VoidCallback onGenerateCaptionsDraft;
  final VoidCallback onRegenerateCaptionsDraftRequested;
  final List<CaptionDraftSegment>? captionDraftSegments;
  final VoidCallback onEditCaptionsDraft;
  final bool isCaptionDraftGenerating;
  final bool showCaptionDraftTimingStaleHint;
  final ValueChanged<bool> onAutoCaptionsChanged;

  CaptionPresetFields get _lookFields => CaptionPresetFields(
        fontSize: QuickEditCaptionFontSize.medium,
        fontFamily: lookFontFamily,
        position: QuickEditCaptionPosition.bottom,
        color: lookColor,
        style: QuickEditCaptionsStylePreset.cleanPro,
        wordHighlight: lookWordHighlight,
        offsetX: 0,
        offsetY: 0,
        normalTextColor: lookNormalTextColor,
        activeTextColor: lookActiveTextColor,
        boxColor: lookBoxColor,
        boxShape: lookBoxShape,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!autoCaptionsEnabled) {
      return _CaptionsOffInviteCard(
        theme: theme,
        scheme: scheme,
        l10n: l10n,
        onAutoCaptionsChanged: onAutoCaptionsChanged,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CaptionsActiveStatusBar(
          theme: theme,
          scheme: scheme,
          l10n: l10n,
          onAutoCaptionsChanged: onAutoCaptionsChanged,
        ),
        if ((captionDraftSegments == null || captionDraftSegments!.isEmpty) &&
            !isCaptionDraftGenerating) ...[
          const SizedBox(height: 12),
          _CaptionsPreviewDraftRequiredCard(
            theme: theme,
            scheme: scheme,
            l10n: l10n,
            onCreateDraft: onGenerateCaptionsDraft,
          ),
        ],
        const SizedBox(height: 12),
        _CaptionsLookHeroCard(
          theme: theme,
          scheme: scheme,
          l10n: l10n,
          effectivePreset: effectiveCaptionPreset,
          styleDetailLine: lookStyleDetailLine,
          lookFields: _lookFields,
          onCustomizeLook: onCustomizeLook,
        ),
        const SizedBox(height: 10),
        _CaptionsDraftSecondaryCard(
          theme: theme,
          scheme: scheme,
          l10n: l10n,
          hasDraft: captionDraftSegments != null && captionDraftSegments!.isNotEmpty,
          isGenerating: isCaptionDraftGenerating,
          showStaleHint: showCaptionDraftTimingStaleHint,
          segments: captionDraftSegments,
          onGenerate: onGenerateCaptionsDraft,
          onRegenerate: onRegenerateCaptionsDraftRequested,
          onEditCaptions: onEditCaptionsDraft,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Captions OFF — inviting feature CTA (V3.4I).
class _CaptionsOffInviteCard extends StatelessWidget {
  const _CaptionsOffInviteCard({
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.onAutoCaptionsChanged,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final ValueChanged<bool> onAutoCaptionsChanged;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: dark ? 0.5 : 0.65),
            scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.35 : 0.55),
          ],
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.subtitles_rounded,
                      size: 26,
                      color: scheme.primary.withValues(alpha: 0.92),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.editCaptionsV3AddSectionTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.editCaptionsV34OffInviteSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _BenefitChip(label: l10n.editCaptionsV34BenefitDraft, scheme: scheme),
                _BenefitChip(label: l10n.editCaptionsV34BenefitStyles, scheme: scheme),
                _BenefitChip(label: l10n.editCaptionsV34BenefitHighlight, scheme: scheme),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.editCaptionsV34EnableCaptions,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: false,
                  onChanged: onAutoCaptionsChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Captions ON — compact status row.
class _CaptionsActiveStatusBar extends StatelessWidget {
  const _CaptionsActiveStatusBar({
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.onAutoCaptionsChanged,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final ValueChanged<bool> onAutoCaptionsChanged;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: dark ? 0.28 : 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.subtitles_rounded,
              size: 20,
              color: scheme.primary.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.editCaptionsV34PanelActiveStatus,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Semantics(
              label: l10n.editCaptionsV34PanelTurnOff,
              child: Switch.adaptive(
                value: true,
                onChanged: onAutoCaptionsChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Creator-style look hero card (V3.4I).
class _CaptionsLookHeroCard extends StatelessWidget {
  const _CaptionsLookHeroCard({
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.effectivePreset,
    required this.styleDetailLine,
    required this.lookFields,
    required this.onCustomizeLook,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final QuickEditCaptionPreset effectivePreset;
  final String styleDetailLine;
  final CaptionPresetFields lookFields;
  final VoidCallback onCustomizeLook;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;
    final presetName = captionPresetTitle(l10n, effectivePreset);
    final isManual = effectivePreset == QuickEditCaptionPreset.custom;
    final shapeLabel = lookFields.wordHighlight == QuickEditCaptionWordHighlight.box
        ? captionBoxShapeLabel(l10n, lookFields.boxShape)
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: dark ? 0.22 : 0.14),
            scheme.primaryContainer.withValues(alpha: dark ? 0.48 : 0.62),
            scheme.surfaceContainerHigh.withValues(alpha: dark ? 0.4 : 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.editCaptionsV34PanelLookTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LookStylePreviewTile(l10n: l10n, lookFields: lookFields),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              presetName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isManual) ...[
                            const SizedBox(width: 6),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: scheme.surface.withValues(alpha: 0.6),
                                border: Border.all(
                                  color: scheme.outline.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                child: Text(
                                  l10n.editCaptionsPresetManualBadge,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        styleDetailLine,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CaptionPresetColorDots(recipe: lookFields),
                          if (shapeLabel != null) ...[
                            const SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: scheme.surface.withValues(alpha: 0.5),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  shapeLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCustomizeLook,
              icon: const Icon(Icons.auto_awesome_rounded, size: 20),
              label: Text(l10n.editCaptionsV34CustomizeLook),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains that a caption draft is required before real preview text appears.
class _CaptionsPreviewDraftRequiredCard extends StatelessWidget {
  const _CaptionsPreviewDraftRequiredCard({
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.onCreateDraft,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final VoidCallback onCreateDraft;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: dark ? 0.22 : 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.editCaptionsPreviewDraftRequiredTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.editCaptionsPreviewDraftRequiredBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                height: 1.38,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreateDraft,
              icon: const Icon(Icons.subtitles_outlined, size: 20),
              label: Text(l10n.editCaptionsPreviewDraftRequiredCta),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mini dark stage with sample caption text.
class _LookStylePreviewTile extends StatelessWidget {
  const _LookStylePreviewTile({
    required this.l10n,
    required this.lookFields,
  });

  final AppLocalizations l10n;
  final CaptionPresetFields lookFields;

  @override
  Widget build(BuildContext context) {
    final normal = effectiveCaptionNormalTextColor(
      color: lookFields.color,
      normalTextColor: lookFields.normalTextColor,
    );
    final textColor = captionColorToFlutter(normal);
    final sample = l10n.editCaptionsV34SamplePreviewLabel;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFF0A0A0C),
        child: SizedBox(
          width: 72,
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Center(
              child: Text(
                sample,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(
                  textStyle: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    shadows: const [
                      Shadow(
                        blurRadius: 6,
                        color: Color(0xCC000000),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary optional draft card.
class _CaptionsDraftSecondaryCard extends StatelessWidget {
  const _CaptionsDraftSecondaryCard({
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
    final dark = theme.brightness == Brightness.dark;
    final canEdit = hasDraft && !showStaleHint && !isGenerating;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.28 : 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.editCaptionsV34PanelDraftTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (!hasDraft && !isGenerating) ...[
              const SizedBox(height: 6),
              Text(
                l10n.editCaptionsV34PanelDraftHelper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.35,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.editCaptionsV34PanelDraftTimingHint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (showStaleHint && !isGenerating) ...[
              const SizedBox(height: 8),
              Text(
                l10n.editCaptionsV31StaleBeforeEdit,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (isGenerating) ...[
              const SizedBox(height: 10),
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
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (hasDraft && !isGenerating) ...[
              const SizedBox(height: 8),
              Text(
                l10n.editCaptionsV34PanelDraftReady,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                captionDraftSummaryLine(l10n, segments!),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.editCaptionsV34PanelDraftReadyHelper,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            if (!hasDraft && !isGenerating)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: onGenerate,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.editCaptionsDraftGenerateButton),
                ),
              ),
            if (canEdit) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton(
                  onPressed: onEditCaptions,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(l10n.editCaptionsV34PanelEditCaptions),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (hasDraft && !isGenerating)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onRegenerate,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  child: Text(l10n.editCaptionsDraftRegenerateButton),
                ),
              ),
            if (!hasDraft && !isGenerating) ...[
              const SizedBox(height: 4),
              Text(
                l10n.editCaptionsDraftLongVideoHelper,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
