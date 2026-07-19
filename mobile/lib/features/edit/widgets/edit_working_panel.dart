import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/theme/linkclip_design_system.dart";
import "../../../core/theme/linkclip_palette.dart";
import "../../../core/widgets/keep_app_open_hint.dart";
import "edit_processing_animation.dart";

/// Shared edit-job progress UI (video + audio).
class EditWorkingPanel extends StatelessWidget {
  const EditWorkingPanel({
    super.key,
    required this.headline,
    required this.subtitle,
    this.extraNote,
    this.progressPercent,
    this.showKeepOpenHint = false,
    this.leadingIcon = LucideIcons.clapperboard,
  });

  final String headline;
  final String subtitle;
  final String? extraNote;
  final int? progressPercent;
  final bool showKeepOpenHint;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.lcPalette;
    final pct = progressPercent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(LcSpace.xl, LcSpace.lg, LcSpace.xl, LcSpace.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LcRadius.card),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: LcSpace.md, horizontal: LcSpace.sm),
                child: leadingIcon == LucideIcons.clapperboard
                    ? EditProcessingAnimation(
                        size: 220,
                        color: scheme.primary,
                        accentGlow: palette.loaderBubble,
                      )
                    : Icon(leadingIcon, size: 88, color: scheme.primary.withValues(alpha: 0.82)),
              ),
            ),
          ),
          const SizedBox(height: LcSpace.xxl),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: LcSpace.md),
          if (extraNote != null && extraNote!.trim().isNotEmpty) ...[
            Text(
              extraNote!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: LcSpace.sm),
          ],
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (showKeepOpenHint)
            KeepAppOpenHint(context.l10n.keepAppOpenUntilEditFinished),
          const SizedBox(height: LcSpace.xl),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: pct != null ? (pct.clamp(0, 100) / 100.0) : null,
            ),
          ),
        ],
      ),
    );
  }
}
