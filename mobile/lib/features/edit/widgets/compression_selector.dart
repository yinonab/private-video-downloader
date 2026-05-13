import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";

class CompressionSelector extends StatelessWidget {
  const CompressionSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final QuickEditCompressPreset selected;
  final ValueChanged<QuickEditCompressPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final opts = <({QuickEditCompressPreset p, String label})>[
      (p: QuickEditCompressPreset.original, label: l10n.editCompressOriginal),
      (p: QuickEditCompressPreset.social, label: l10n.editCompressSocial),
      (p: QuickEditCompressPreset.small, label: l10n.editCompressSmall),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.editCompressSectionTitle,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.editCompressHelperHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 12),
        ...opts.map((o) {
          final sel = selected == o.p;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: sel
                  ? scheme.primaryContainer.withValues(alpha: 0.55)
                  : scheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                    color: sel
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.35),
                    width: sel ? 2 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(o.p),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Icon(
                        sel
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: sel ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          o.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
