import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/l10n/context_l10n.dart";
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
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
          const SizedBox(height: 28),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (extraNote != null && extraNote!.trim().isNotEmpty) ...[
            Text(
              extraNote!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (showKeepOpenHint)
            KeepAppOpenHint(context.l10n.keepAppOpenUntilDownloadFinished),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: pct != null ? (pct.clamp(0, 100) / 100.0) : null,
            ),
          ),
        ],
      ),
    );
  }
}
