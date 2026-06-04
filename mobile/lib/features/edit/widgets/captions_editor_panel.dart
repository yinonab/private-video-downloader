import "package:flutter/material.dart";

import "../../../core/edit/caption_draft_summary.dart";
import "../../../core/edit/caption_look_summary.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";
import "caption_look/caption_look_widgets.dart";

/// Quick Edit — captions panel (V3.4H): compact status, hero look, optional draft.
class CaptionsEditorPanel extends StatelessWidget {
  const CaptionsEditorPanel({
    super.key,
    required this.autoCaptionsEnabled,
    required this.effectiveCaptionPreset,
    required this.lookStyleDetailLine,
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
  final VoidCallback onCustomizeLook;
  final VoidCallback onGenerateCaptionsDraft;
  final VoidCallback onRegenerateCaptionsDraftRequested;
  final List<CaptionDraftSegment>? captionDraftSegments;
  final VoidCallback onEditCaptionsDraft;
  final bool isCaptionDraftGenerating;
  final bool showCaptionDraftTimingStaleHint;
  final ValueChanged<bool> onAutoCaptionsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (!autoCaptionsEnabled) {
      return _CaptionsOffEnableCard(
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
        const SizedBox(height: 12),
        _CaptionsLookHeroCard(
          theme: theme,
          scheme: scheme,
          l10n: l10n,
          effectivePreset: effectiveCaptionPreset,
          styleDetailLine: lookStyleDetailLine,
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

/// Captions OFF — friendly enable card.
class _CaptionsOffEnableCard extends StatelessWidget {
  const _CaptionsOffEnableCard({
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
        color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.34 : 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.editCaptionsV3AddSectionTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.editCaptionsSectionSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Row(
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

/// Captions ON — compact status row (no bulky enable card).
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

/// Primary hero card — caption look.
class _CaptionsLookHeroCard extends StatelessWidget {
  const _CaptionsLookHeroCard({
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.effectivePreset,
    required this.styleDetailLine,
    required this.onCustomizeLook,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final QuickEditCaptionPreset effectivePreset;
  final String styleDetailLine;
  final VoidCallback onCustomizeLook;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;
    final presetName = captionPresetTitle(l10n, effectivePreset);
    final isManual = effectivePreset == QuickEditCaptionPreset.custom;
    final recipe = captionPresetRecipe(effectivePreset);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: dark ? 0.42 : 0.55),
            scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.38 : 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LookMiniPreview(
                  scheme: scheme,
                  recipe: recipe,
                  isManual: isManual,
                ),
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
                            const SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: scheme.outline.withValues(alpha: 0.4),
                                ),
                                color: scheme.surface.withValues(alpha: 0.5),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                child: Text(
                                  l10n.editCaptionsPresetManualBadge,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        styleDetailLine,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onCustomizeLook,
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: Text(l10n.editCaptionsV34CustomizeLook),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookMiniPreview extends StatelessWidget {
  const _LookMiniPreview({
    required this.scheme,
    required this.recipe,
    required this.isManual,
  });

  final ColorScheme scheme;
  final CaptionPresetFields? recipe;
  final bool isManual;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.88),
        child: SizedBox(
          width: 52,
          height: 52,
          child: recipe != null
              ? Center(
                  child: CaptionPresetColorDots(recipe: recipe!),
                )
              : Center(
                  child: Icon(
                    Icons.palette_outlined,
                    size: 22,
                    color: scheme.primary.withValues(alpha: 0.85),
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
