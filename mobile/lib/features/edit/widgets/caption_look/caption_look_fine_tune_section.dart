import "package:flutter/material.dart";

import "../../../../core/models/quick_edit_models.dart";
import "../../../../l10n/app_localizations.dart";

/// Accessible position nudge pad for the look editor Position tab.
class CaptionLookFineTuneSection extends StatelessWidget {
  const CaptionLookFineTuneSection({
    super.key,
    required this.accent,
    required this.l10n,
    required this.offsetX,
    required this.offsetY,
    required this.onReset,
    required this.onNudge,
  });

  final Color accent;
  final AppLocalizations l10n;
  final int offsetX;
  final int offsetY;
  final VoidCallback onReset;
  final void Function(int dxAss, int dyAss) onNudge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final mutedAccent = accent.withValues(alpha: dark ? 0.55 : 0.85);
    final step = kQuickEditCaptionsOffsetFineStep;

    Widget padBtn({required IconData icon, required VoidCallback onPressed}) {
      return Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
        shape: CircleBorder(side: BorderSide(color: mutedAccent.withValues(alpha: 0.22))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(Icons.arrow_upward_rounded, size: 26),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.editCaptionsFineTuneTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              l10n.editCaptionsOffsetCompact(offsetX, offsetY),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              padBtn(
                icon: Icons.keyboard_arrow_up_rounded,
                onPressed: () => onNudge(0, -step),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
                    shape: CircleBorder(
                        side: BorderSide(color: mutedAccent.withValues(alpha: 0.22))),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onNudge(-step, 0),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.arrow_back_rounded, size: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
                    shape: CircleBorder(
                        side: BorderSide(color: mutedAccent.withValues(alpha: 0.22))),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onNudge(step, 0),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Icon(Icons.arrow_forward_rounded, size: 26),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
                shape: CircleBorder(side: BorderSide(color: mutedAccent.withValues(alpha: 0.22))),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onNudge(0, step),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Icon(Icons.arrow_downward_rounded, size: 26),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 20),
            label: Text(l10n.editCaptionsResetPosition),
          ),
        ),
      ],
    );
  }
}
