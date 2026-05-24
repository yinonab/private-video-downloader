import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";

/// Aspect-ratio presets as compact selectable chips (center crop semantics unchanged server-side).
class CropEditor extends StatelessWidget {
  const CropEditor({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final QuickEditCropAspect selected;
  final ValueChanged<QuickEditCropAspect> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final options = <({QuickEditCropAspect aspect, String label})>[
      (aspect: QuickEditCropAspect.original, label: l10n.editCropOriginal),
      (aspect: QuickEditCropAspect.nineSixteen, label: "9:16"),
      (aspect: QuickEditCropAspect.oneOne, label: "1:1"),
      (aspect: QuickEditCropAspect.sixteenNine, label: "16:9"),
      (aspect: QuickEditCropAspect.fourFive, label: "4:5"),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.editCropSectionTitle,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.editCropTabHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              _AspectChip(
                label: o.label,
                selected: selected == o.aspect,
                onTap: () => onSelected(o.aspect),
              ),
          ],
        ),
      ],
    );
  }
}

class _AspectChip extends StatelessWidget {
  const _AspectChip({
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
    final borderColor = selected
        ? scheme.primary.withValues(alpha: 0.55)
        : scheme.outline.withValues(alpha: 0.32);
    final bg = selected
        ? scheme.primary.withValues(alpha: dark ? 0.16 : 0.12)
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
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected
                  ? scheme.primary.withValues(alpha: 0.95)
                  : scheme.onSurface.withValues(alpha: 0.88),
            ),
          ),
        ),
      ),
    );
  }
}
