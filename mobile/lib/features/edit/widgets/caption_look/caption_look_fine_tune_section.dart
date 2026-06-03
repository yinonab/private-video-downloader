import "package:flutter/material.dart";

import "../../../../core/models/quick_edit_models.dart";
import "../../../../l10n/app_localizations.dart";

/// Live X/Y coordinate readout above the position joystick.
class CaptionXYReadout extends StatelessWidget {
  const CaptionXYReadout({
    super.key,
    required this.l10n,
    required this.offsetX,
    required this.offsetY,
  });

  final AppLocalizations l10n;
  final int offsetX;
  final int offsetY;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            l10n.editCaptionsOffsetCompact(offsetX, offsetY),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tactile gamepad-style joystick for caption position fine-tuning.
class CaptionPositionJoystick extends StatelessWidget {
  const CaptionPositionJoystick({
    super.key,
    required this.onNudge,
  });

  final void Function(int dxAss, int dyAss) onNudge;

  static const double _btnSize = 52;
  static const double _hubSize = 28;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final step = kQuickEditCaptionsOffsetFineStep;

    // Physical D-pad layout stays LTR so left/right match screen motion in RTL locales.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _JoystickButton(
              size: _btnSize,
              icon: Icons.keyboard_arrow_up_rounded,
              onPressed: () => onNudge(0, -step),
            ),
            const SizedBox(height: _gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _JoystickButton(
                  size: _btnSize,
                  icon: Icons.keyboard_arrow_left_rounded,
                  onPressed: () => onNudge(-step, 0),
                ),
                const SizedBox(width: _gap),
                const _JoystickHub(size: _hubSize),
                const SizedBox(width: _gap),
                _JoystickButton(
                  size: _btnSize,
                  icon: Icons.keyboard_arrow_right_rounded,
                  onPressed: () => onNudge(step, 0),
                ),
              ],
            ),
            const SizedBox(height: _gap),
            _JoystickButton(
              size: _btnSize,
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: () => onNudge(0, step),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoystickHub extends StatelessWidget {
  const _JoystickHub({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        ),
      ),
    );
  }
}

class _JoystickButton extends StatefulWidget {
  const _JoystickButton({
    required this.size,
    required this.icon,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  State<_JoystickButton> createState() => _JoystickButtonState();
}

class _JoystickButtonState extends State<_JoystickButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Material(
        elevation: _pressed ? 0 : (isDark ? 1 : 2),
        shadowColor: Colors.black.withValues(alpha: 0.25),
        color: _pressed
            ? scheme.primaryContainer.withValues(alpha: 0.65)
            : scheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.72 : 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _pressed
                ? scheme.primary.withValues(alpha: 0.55)
                : scheme.outline.withValues(alpha: 0.22),
            width: _pressed ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          onTap: widget.onPressed,
          child: Icon(
            widget.icon,
            size: 26,
            color: scheme.onSurface.withValues(alpha: _pressed ? 0.95 : 0.78),
          ),
        ),
      ),
    );
  }
}

/// Fine-tune section: XY readout + joystick + reset (title in parent card).
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaptionXYReadout(
          l10n: l10n,
          offsetX: offsetX,
          offsetY: offsetY,
        ),
        const SizedBox(height: 16),
        CaptionPositionJoystick(onNudge: onNudge),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: onReset,
            icon: Icon(
              Icons.restart_alt_rounded,
              size: 18,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
            label: Text(l10n.editCaptionsResetPosition),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.9),
            ),
          ),
        ),
      ],
    );
  }
}

/// Premium pill segmented Top / Bottom control.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.45 : 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _PillSegment(
                label: l10n.editCaptionsPositionTop,
                selected: position == QuickEditCaptionPosition.top,
                onTap: () => onPosition(QuickEditCaptionPosition.top),
                scheme: scheme,
              ),
            ),
            Expanded(
              child: _PillSegment(
                label: l10n.editCaptionsPositionBottom,
                selected: position == QuickEditCaptionPosition.bottom,
                onTap: () => onPosition(QuickEditCaptionPosition.bottom),
                scheme: scheme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillSegment extends StatelessWidget {
  const _PillSegment({
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? scheme.primary.withValues(alpha: 0.92) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 42,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? scheme.onPrimary
                          : scheme.onSurface.withValues(alpha: 0.82),
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Polished fine-tune card (title + helper + controls).
class CaptionLookFineTuneCard extends StatelessWidget {
  const CaptionLookFineTuneCard({
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      color: scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.55 : 0.92),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.editCaptionsFineTuneTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.editCaptionsV34PositionFineTuneHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                  height: 1.35,
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              CaptionLookFineTuneSection(
                l10n: l10n,
                offsetX: offsetX,
                offsetY: offsetY,
                onReset: onReset,
                onNudge: onNudge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
