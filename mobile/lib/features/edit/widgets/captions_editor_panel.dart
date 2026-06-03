import "package:flutter/material.dart";

import "../../../core/edit/caption_draft_summary.dart";
import "../../../core/edit/caption_look_summary.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

/// Quick Edit — captions auto burn-in + draft + compact look summary (V3.4D).
class CaptionsEditorPanel extends StatelessWidget {
  const CaptionsEditorPanel({
    super.key,
    required this.autoCaptionsEnabled,
    required this.effectiveCaptionPreset,
    required this.lookSummaryLine,
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
  final String lookSummaryLine;
  final VoidCallback onCustomizeLook;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final hasDraft = captionDraftSegments != null &&
        captionDraftSegments!.isNotEmpty;

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
                  value: autoCaptionsEnabled,
                  onChanged: onAutoCaptionsChanged,
                ),
              ],
            ),
          ),
          if (autoCaptionsEnabled) ...[
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
                isGenerating: isCaptionDraftGenerating,
                showStaleHint: showCaptionDraftTimingStaleHint,
                segments: captionDraftSegments,
                onGenerate: onGenerateCaptionsDraft,
                onRegenerate: onRegenerateCaptionsDraftRequested,
                onEditCaptions: onEditCaptionsDraft,
              ),
            ),
            const SizedBox(height: 12),
            _CaptionsSectionCard(
              theme: theme,
              scheme: scheme,
              title: l10n.editCaptionsV3LookSectionTitle,
              helper: l10n.editCaptionsV3LookHelper,
              child: _CaptionsLookCompactSection(
                theme: theme,
                scheme: scheme,
                l10n: l10n,
                effectivePreset: effectiveCaptionPreset,
                summaryLine: lookSummaryLine,
                onCustomizeLook: onCustomizeLook,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CaptionsLookCompactSection extends StatelessWidget {
  const _CaptionsLookCompactSection({
    required this.theme,
    required this.scheme,
    required this.l10n,
    required this.effectivePreset,
    required this.summaryLine,
    required this.onCustomizeLook,
  });

  final ThemeData theme;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final QuickEditCaptionPreset effectivePreset;
  final String summaryLine;
  final VoidCallback onCustomizeLook;

  @override
  Widget build(BuildContext context) {
    final presetName = captionPresetTitle(l10n, effectivePreset);
    final isManual = effectivePreset == QuickEditCaptionPreset.custom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presetName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    summaryLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isManual) ...[
              const SizedBox(width: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: onCustomizeLook,
          icon: const Icon(Icons.tune_rounded, size: 20),
          label: Text(l10n.editCaptionsV34CustomizeLook),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
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
