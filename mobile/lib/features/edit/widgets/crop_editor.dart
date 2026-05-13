import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";

/// Aspect-ratio presets on a fixed grid (stable layout — selection never resizes cells).
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
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.editCropTabHint,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth;
            const spacing = 10.0;
            const runSpacing = 10.0;
            final cols = maxW >= 360 ? 3 : 2;
            final cellW = (maxW - spacing * (cols - 1)) / cols;
            const cellH = 52.0;

            return Wrap(
              spacing: spacing,
              runSpacing: runSpacing,
              children: [
                for (final o in options)
                  SizedBox(
                    width: cellW,
                    height: cellH,
                    child: _AspectCell(
                      label: o.label,
                      selected: selected == o.aspect,
                      onTap: () => onSelected(o.aspect),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AspectCell extends StatelessWidget {
  const _AspectCell({
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
    final borderColor =
        selected ? scheme.primary : scheme.outline.withValues(alpha: 0.45);
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.22)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.55);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              ),
            ),
            if (selected)
              PositionedDirectional(
                top: 6,
                end: 6,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
