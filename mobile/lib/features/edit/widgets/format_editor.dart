import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";

/// Format tab: aspect presets + Fill vs Fit/blur-back mode (inside one panel).
class FormatEditor extends StatelessWidget {
  const FormatEditor({
    super.key,
    required this.aspect,
    required this.fitMode,
    required this.onAspectChanged,
    required this.onFitModeChanged,
  });

  final QuickEditCropAspect aspect;
  final QuickEditFormatMode fitMode;
  final ValueChanged<QuickEditCropAspect> onAspectChanged;
  final ValueChanged<QuickEditFormatMode> onFitModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final shapeOpts = <({QuickEditCropAspect a, String label})>[
      (a: QuickEditCropAspect.original, label: l10n.editCropOriginal),
      (a: QuickEditCropAspect.nineSixteen, label: "9:16"),
      (a: QuickEditCropAspect.oneOne, label: "1:1"),
      (a: QuickEditCropAspect.fourFive, label: "4:5"),
      (a: QuickEditCropAspect.sixteenNine, label: "16:9"),
    ];

    final showFitModes = aspect != QuickEditCropAspect.original;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.editFormatVideoShapeTitle,
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.editFormatVideoShapeSubtitle,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in shapeOpts)
              _ChoiceChip(
                label: o.label,
                selected: aspect == o.a,
                onTap: () => onAspectChanged(o.a),
              ),
          ],
        ),
        if (showFitModes) ...[
          const SizedBox(height: 18),
          Text(
            l10n.editFormatFitModeSectionTitle,
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChoiceChip(
                label: l10n.editFormatFitOptionFill,
                selected: fitMode == QuickEditFormatMode.fill,
                onTap: () => onFitModeChanged(QuickEditFormatMode.fill),
              ),
              _ChoiceChip(
                label: l10n.editFormatFitOptionFit,
                selected: fitMode == QuickEditFormatMode.fitBlur,
                onTap: () => onFitModeChanged(QuickEditFormatMode.fitBlur),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fitMode == QuickEditFormatMode.fill
                ? l10n.editFormatFitFillExplanation
                : l10n.editFormatFitFitExplanation,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
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
    final mutedLine =
        scheme.primary.withValues(alpha: dark ? 0.42 : 0.72);
    final borderColor =
        selected ? mutedLine : scheme.outline.withValues(alpha: 0.32);
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
