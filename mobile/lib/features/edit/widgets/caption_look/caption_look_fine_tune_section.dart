import "package:flutter/material.dart";

import "../../../../core/models/quick_edit_models.dart";
import "../../../../l10n/app_localizations.dart";

/// Compact D-pad for fine-tuning caption position (title lives in parent section).
class CaptionLookFineTuneSection extends StatelessWidget {
  const CaptionLookFineTuneSection({
    super.key,
    required this.l10n,
    required this.offsetX,
    required this.offsetY,
    required this.onReset,
    required this.onNudge,
  });

  final AppLocalizations l10n;
  final int offsetX;
  final int offsetY;
  final VoidCallback onReset;
  final void Function(int dxAss, int dyAss) onNudge;

  static const double _btnSize = 48;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final step = kQuickEditCaptionsOffsetFineStep;

    Widget padBtn({required IconData icon, required VoidCallback onPressed}) {
      return SizedBox(
        width: _btnSize,
        height: _btnSize,
        child: Material(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outline.withValues(alpha: 0.22)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Icon(icon, size: _iconSize, color: scheme.onSurface.withValues(alpha: 0.75)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            l10n.editCaptionsOffsetCompact(offsetX, offsetY),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              padBtn(
                icon: Icons.keyboard_arrow_up_rounded,
                onPressed: () => onNudge(0, -step),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  padBtn(
                    icon: Icons.keyboard_arrow_left_rounded,
                    onPressed: () => onNudge(-step, 0),
                  ),
                  const SizedBox(width: 8),
                  padBtn(
                    icon: Icons.keyboard_arrow_right_rounded,
                    onPressed: () => onNudge(step, 0),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              padBtn(
                icon: Icons.keyboard_arrow_down_rounded,
                onPressed: () => onNudge(0, step),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: Text(l10n.editCaptionsResetPosition),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}

/// Top / Bottom segmented control for position.
class CaptionLookPositionSegmented extends StatelessWidget {
  const CaptionLookPositionSegmented({
    super.key,
    required this.l10n,
    required this.position,
    required this.onPosition,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionPosition position;
  final ValueChanged<QuickEditCaptionPosition> onPosition;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _Segment(
            label: l10n.editCaptionsPositionTop,
            selected: position == QuickEditCaptionPosition.top,
            onTap: () => onPosition(QuickEditCaptionPosition.top),
            scheme: scheme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Segment(
            label: l10n.editCaptionsPositionBottom,
            selected: position == QuickEditCaptionPosition.bottom,
            onTap: () => onPosition(QuickEditCaptionPosition.bottom),
            scheme: scheme,
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
