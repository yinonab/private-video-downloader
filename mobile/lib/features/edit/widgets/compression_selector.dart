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
    final dark = theme.brightness == Brightness.dark;

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
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.editCompressHelperHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 12),
        ...opts.map((o) {
          final sel = selected == o.p;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: sel
                  ? scheme.primary.withValues(alpha: dark ? 0.14 : 0.1)
                  : scheme.surfaceContainerHighest.withValues(
                      alpha: dark ? 0.35 : 0.48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: sel
                      ? scheme.primary.withValues(alpha: 0.42)
                      : scheme.outline.withValues(alpha: 0.28),
                  width: sel ? 1.15 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(o.p),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      if (sel)
                        Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: scheme.primary.withValues(alpha: 0.9),
                        )
                      else
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    scheme.outline.withValues(alpha: 0.35),
                              ),
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
