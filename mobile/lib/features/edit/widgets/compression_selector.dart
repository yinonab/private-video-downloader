import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../core/theme/linkclip_design_system.dart";

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
        LinkClipSectionHeader(
          title: l10n.editCompressSectionTitle,
          subtitle: l10n.editCompressHelperHint,
        ),
        const SizedBox(height: LcSpace.xl),
        ...opts.map((o) {
          final sel = selected == o.p;
          return Padding(
            padding: const EdgeInsets.only(bottom: LcSpace.sm),
            child: Material(
              color: sel
                  ? scheme.primary.withValues(alpha: dark ? 0.14 : 0.1)
                  : scheme.surfaceContainerHighest.withValues(
                      alpha: dark ? 0.35 : 0.48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LcRadius.medium),
                side: BorderSide(
                  color: sel
                      ? scheme.primary.withValues(alpha: 0.45)
                      : scheme.outline.withValues(alpha: 0.28),
                  width: sel ? 1.3 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onSelected(o.p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LcSpace.lg,
                    vertical: LcSpace.lg,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          o.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      if (sel)
                        Icon(
                          Icons.check_circle_rounded,
                          color: scheme.primary.withValues(alpha: 0.9),
                          size: 22,
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
