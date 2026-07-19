import "package:flutter/material.dart";

import "../../../core/l10n/context_l10n.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../core/theme/linkclip_design_system.dart";

/// Format tab: aspect presets + Fill screen vs Keep all (blur backdrop).
class FormatEditor extends StatelessWidget {
  const FormatEditor({
    super.key,
    required this.aspect,
    required this.fitMode,
    required this.rotation,
    required this.onAspectChanged,
    required this.onFitModeChanged,
    required this.onRotationChanged,
  });

  final QuickEditCropAspect aspect;
  final QuickEditFormatMode fitMode;
  final QuickEditRotation rotation;
  final ValueChanged<QuickEditCropAspect> onAspectChanged;
  final ValueChanged<QuickEditFormatMode> onFitModeChanged;
  final ValueChanged<QuickEditRotation> onRotationChanged;

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

    final fitEnabled = aspect != QuickEditCropAspect.original;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinkClipSectionHeader(
          title: l10n.editFormatVideoShapeTitle,
          subtitle: l10n.editFormatVideoShapeSubtitle,
        ),
        const SizedBox(height: LcSpace.lg),
        Wrap(
          spacing: LcSpace.sm,
          runSpacing: LcSpace.sm,
          children: [
            for (final o in shapeOpts)
              LinkClipChoiceChip(
                label: o.label,
                selected: aspect == o.a,
                onTap: () => onAspectChanged(o.a),
              ),
          ],
        ),
        const SizedBox(height: LcSpace.xl),
        LinkClipSectionHeader(title: l10n.editFormatFitModeSectionTitle),
        const SizedBox(height: LcSpace.md),
        if (!fitEnabled) ...[
          Text(
            l10n.editFormatFitModeNeedsShapeHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
          const SizedBox(height: LcSpace.md),
        ],
        IgnorePointer(
          ignoring: !fitEnabled,
          child: Opacity(
            opacity: fitEnabled ? 1 : 0.52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FitModeCard(
                        icon: Icons.crop_rounded,
                        label: l10n.editFormatFitOptionFill,
                        selected:
                            fitMode == QuickEditFormatMode.fill && fitEnabled,
                        onTap: () =>
                            onFitModeChanged(QuickEditFormatMode.fill),
                      ),
                    ),
                    const SizedBox(width: LcSpace.md),
                    Expanded(
                      child: _FitModeCard(
                        icon: Icons.layers_outlined,
                        label: l10n.editFormatFitOptionFit,
                        selected: fitMode == QuickEditFormatMode.fitBlur &&
                            fitEnabled,
                        onTap: () =>
                            onFitModeChanged(QuickEditFormatMode.fitBlur),
                      ),
                    ),
                  ],
                ),
                if (fitEnabled) ...[
                  const SizedBox(height: LcSpace.md),
                  Text(
                    fitMode == QuickEditFormatMode.fill
                        ? l10n.editFormatFitFillExplanation
                        : l10n.editFormatFitFitExplanation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: LcSpace.xl),
        LinkClipSectionHeader(
          title: l10n.editFormatRotationTitle,
          subtitle: l10n.editFormatRotationSubtitle,
        ),
        const SizedBox(height: LcSpace.lg),
        Wrap(
          spacing: LcSpace.sm,
          runSpacing: LcSpace.sm,
          children: [
            for (final r in QuickEditRotation.values)
              LinkClipChoiceChip(
                label: r.chipLabel,
                selected: rotation == r,
                onTap: () => onRotationChanged(r),
                icon: Icons.rotate_right_rounded,
              ),
          ],
        ),
      ],
    );
  }
}

class _FitModeCard extends StatelessWidget {
  const _FitModeCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: dark ? 0.55 : 0.7)
        : scheme.outline.withValues(alpha: 0.3);
    final bg = selected
        ? scheme.primary.withValues(alpha: dark ? 0.16 : 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55);
    final iconColor = selected
        ? scheme.primary.withValues(alpha: 0.92)
        : scheme.onSurface.withValues(alpha: 0.55);
    final textColor = selected
        ? scheme.primary.withValues(alpha: 0.95)
        : scheme.onSurface.withValues(alpha: 0.88);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LcRadius.medium),
        side: BorderSide(color: borderColor, width: selected ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: iconColor),
              const SizedBox(height: LcSpace.sm),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
