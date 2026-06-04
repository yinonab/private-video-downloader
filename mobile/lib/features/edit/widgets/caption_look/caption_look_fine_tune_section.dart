import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../../../../core/models/quick_edit_models.dart";
import "../../../../l10n/app_localizations.dart";
import "caption_position_dpad.dart";

/// Live HUD readout for caption X/Y offsets.
class CaptionXYReadout extends StatelessWidget {
  const CaptionXYReadout({
    super.key,
    required this.l10n,
    required this.offsetX,
    required this.offsetY,
    this.accentColor,
  });

  final AppLocalizations l10n;
  final int offsetX;
  final int offsetY;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = accentColor ?? scheme.primary;
    final text = l10n.editCaptionsOffsetCompact(offsetX, offsetY);

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LiveDot(color: accent),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  text,
                  key: ValueKey<String>(text),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.25,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.55),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// Secondary reset control with a brief rotate animation.
class CaptionPositionResetButton extends StatefulWidget {
  const CaptionPositionResetButton({
    super.key,
    required this.l10n,
    required this.onReset,
  });

  final AppLocalizations l10n;
  final VoidCallback onReset;

  @override
  State<CaptionPositionResetButton> createState() => _CaptionPositionResetButtonState();
}

class _CaptionPositionResetButtonState extends State<CaptionPositionResetButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _tap() {
    _spin.forward(from: 0);
    HapticFeedback.lightImpact();
    widget.onReset();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: TextButton.icon(
        onPressed: _tap,
        icon: RotationTransition(
          turns: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: _spin, curve: Curves.easeOutCubic),
          ),
          child: Icon(
            Icons.restart_alt_rounded,
            size: 18,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
          ),
        ),
        label: Text(widget.l10n.editCaptionsResetPosition),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// Fine-tune section: HUD + D-pad + reset.
class CaptionLookFineTuneSection extends StatelessWidget {
  const CaptionLookFineTuneSection({
    super.key,
    required this.l10n,
    required this.accentColor,
    required this.offsetX,
    required this.offsetY,
    required this.onReset,
    required this.onNudge,
  });

  final AppLocalizations l10n;
  final Color accentColor;
  final int offsetX;
  final int offsetY;
  final VoidCallback onReset;
  final void Function(int dxAss, int dyAss) onNudge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CaptionXYReadout(
          l10n: l10n,
          offsetX: offsetX,
          offsetY: offsetY,
          accentColor: accentColor,
        ),
        const SizedBox(height: 18),
        CaptionPositionDPad(
          accentColor: accentColor,
          onNudge: onNudge,
        ),
        const SizedBox(height: 10),
        CaptionPositionResetButton(l10n: l10n, onReset: onReset),
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
    required this.accentColor,
    required this.offsetX,
    required this.offsetY,
    required this.onReset,
    required this.onNudge,
  });

  final AppLocalizations l10n;
  final Color accentColor;
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
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                accentColor: accentColor,
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
