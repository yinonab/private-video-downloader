import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/format_display.dart";
import "../../core/models/analyze_models.dart";

/// Visual choice list for yt-dlp format presets returned by [/analyze].
class QualitySelector extends StatelessWidget {
  const QualitySelector({
    super.key,
    required this.formats,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<FormatOption> formats;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.analyzeChooseQuality,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...List.generate(formats.length, (i) {
          final f = formats[i];
          final selected = i == selectedIndex;
          final disabled = !f.available;
          final rowLabel = formatOptionDisplayLabel(context, f);
          final iconData = disabled
              ? LucideIcons.circleMinus
              : selected
                  ? LucideIcons.circleCheck
                  : LucideIcons.circle;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: disabled
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
                  : selected
                      ? scheme.primaryContainer.withValues(alpha: 0.85)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: disabled ? null : () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        iconData,
                        color: disabled ? scheme.outline : scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              rowLabel,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: disabled ? scheme.onSurfaceVariant : null,
                                  ),
                            ),
                            if (disabled) ...[
                              const SizedBox(height: 4),
                              Text(
                                l10n.qualityUnavailableForVideo,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.outline,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: (35 * i).ms, duration: 240.ms, curve: Curves.easeOut)
              .slideX(begin: 0.02, end: 0, duration: 260.ms, curve: Curves.easeOut);
        }),
      ],
    );
  }
}
