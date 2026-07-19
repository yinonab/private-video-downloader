import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../core/theme/linkclip_design_system.dart";

/// Constant playback-speed presets — equal-sized chips with clear hierarchy.
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
    final factors = QuickEditSpeedFactor.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinkClipSectionHeader(
          title: l10n.editSpeedSectionTitle,
          subtitle: l10n.editSpeedSectionSubtitle,
        ),
        const SizedBox(height: LcSpace.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = LcSpace.sm;
            final cols = factors.length >= 5 ? 3 : 2;
            final tileW =
                (constraints.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final s in factors)
                  SizedBox(
                    width: tileW,
                    child: LinkClipChoiceChip(
                      label: s.chipLabel,
                      selected: selected == s,
                      onTap: () => onSelected(s),
                      expanded: true,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: LcSpace.lg),
        Text(
          l10n.editSpeedDurationHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
