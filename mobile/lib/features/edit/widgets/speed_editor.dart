import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";

/// Constant playback-speed presets — compact chips aligned with [CropEditor].
class SpeedEditor extends StatelessWidget {
  const SpeedEditor({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final QuickEditSpeedFactor selected;
  final ValueChanged<QuickEditSpeedFactor> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.editSpeedSectionTitle,
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.editSpeedSectionSubtitle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in QuickEditSpeedFactor.values)
              _SpeedChip(
                label: s.chipLabel,
                selected: selected == s,
                onTap: () => onSelected(s),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          l10n.editSpeedDurationHint,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final mutedBlue =
        scheme.primary.withValues(alpha: dark ? 0.42 : 0.72);
    final borderColor =
        selected ? mutedBlue : scheme.outline.withValues(alpha: 0.32);
    final bg = selected
        ? scheme.primary.withValues(alpha: dark ? 0.12 : 0.08)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.38 : 0.5);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.93),
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}
