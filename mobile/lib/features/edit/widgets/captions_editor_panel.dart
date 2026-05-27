import "package:flutter/material.dart";

import "../../../core/theme/linkclip_palette.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

/// Quick Edit — captions auto burn-in + styling + **V2.2** offsets + **V2.3** presets (UX only).
class CaptionsEditorPanel extends StatelessWidget {
  const CaptionsEditorPanel({
    super.key,
    required this.autoCaptionsEnabled,
    required this.stylePreset,
    required this.fontSize,
    required this.position,
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.onAutoCaptionsChanged,
    required this.onStyleChanged,
    required this.onFontSizeChanged,
    required this.onPositionChanged,
    required this.onColorChanged,
    required this.onOffsetReset,
    required this.onOffsetNudgeAss,
    required this.effectiveCaptionPreset,
    required this.onCaptionBuiltInPresetSelected,
  });

  final bool autoCaptionsEnabled;
  final QuickEditCaptionsStylePreset stylePreset;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;
  final int offsetX;
  final int offsetY;

  /// Inferred from current size/position/color/style/offsets ([QuickEditCaptionPreset.custom] if no match).
  final QuickEditCaptionPreset effectiveCaptionPreset;

  /// User picked a named preset (**not** [QuickEditCaptionPreset.custom]).
  final ValueChanged<QuickEditCaptionPreset> onCaptionBuiltInPresetSelected;

  final ValueChanged<bool> onAutoCaptionsChanged;
  final ValueChanged<QuickEditCaptionsStylePreset> onStyleChanged;
  final ValueChanged<QuickEditCaptionFontSize> onFontSizeChanged;
  final ValueChanged<QuickEditCaptionPosition> onPositionChanged;
  final ValueChanged<QuickEditCaptionColor> onColorChanged;
  final VoidCallback onOffsetReset;

  /// Nudge offsets in ASS PlayRes pixels (typically ± [kQuickEditCaptionsOffsetFineStep]). Screen-absolute axes (not mirrored in RTL).
  final void Function(int dxAss, int dyAss) onOffsetNudgeAss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = context.lcPalette.tiktokAccent;
    final l10n = AppLocalizations.of(context);

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.editCaptionsSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.editCaptionsSectionSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.42 : 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              title: Text(
                l10n.editCaptionsAutoToggle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Theme(
                data: theme.copyWith(
                  switchTheme: SwitchThemeData(
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.onPrimary;
                      }
                      return scheme.outline;
                    }),
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.primary.withValues(alpha: 0.42);
                      }
                      return scheme.surfaceContainerHighest;
                    }),
                  ),
                ),
                child: Switch.adaptive(
                  value: autoCaptionsEnabled,
                  onChanged: onAutoCaptionsChanged,
                ),
              ),
            ),
          ),
          if (autoCaptionsEnabled) ...[
            const SizedBox(height: 18),
            _CaptionsPresetSection(
              accent: accent,
              theme: theme,
              l10n: l10n,
              effectivePreset: effectiveCaptionPreset,
              onBuiltInSelected: onCaptionBuiltInPresetSelected,
            ),
            const SizedBox(height: 14),
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsTextSizeLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CaptionChip(
                    label: l10n.editCaptionsSizeExtraSmall,
                    selected:
                        fontSize == QuickEditCaptionFontSize.extraSmall,
                    accent: accent,
                    onTap: () => onFontSizeChanged(
                      QuickEditCaptionFontSize.extraSmall,
                    ),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsSizeSmall,
                    selected: fontSize == QuickEditCaptionFontSize.small,
                    accent: accent,
                    onTap: () => onFontSizeChanged(QuickEditCaptionFontSize.small),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsSizeMedium,
                    selected: fontSize == QuickEditCaptionFontSize.medium,
                    accent: accent,
                    onTap: () => onFontSizeChanged(QuickEditCaptionFontSize.medium),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsSizeLarge,
                    selected: fontSize == QuickEditCaptionFontSize.large,
                    accent: accent,
                    onTap: () => onFontSizeChanged(QuickEditCaptionFontSize.large),
                  ),
                ],
              ),
            ),
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsPositionLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CaptionChip(
                    label: l10n.editCaptionsPositionTop,
                    selected: position == QuickEditCaptionPosition.top,
                    accent: accent,
                    onTap: () => onPositionChanged(QuickEditCaptionPosition.top),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsPositionBottom,
                    selected: position == QuickEditCaptionPosition.bottom,
                    accent: accent,
                    onTap: () => onPositionChanged(QuickEditCaptionPosition.bottom),
                  ),
                ],
              ),
            ),
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsColorLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CaptionChip(
                    label: l10n.editCaptionsColorWhite,
                    selected: color == QuickEditCaptionColor.white,
                    accent: accent,
                    onTap: () => onColorChanged(QuickEditCaptionColor.white),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsColorYellow,
                    selected: color == QuickEditCaptionColor.yellow,
                    accent: accent,
                    onTap: () => onColorChanged(QuickEditCaptionColor.yellow),
                  ),
                ],
              ),
            ),
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsStyleLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CaptionChip(
                    label: l10n.editCaptionsStyleClean,
                    selected: stylePreset == QuickEditCaptionsStylePreset.clean,
                    accent: accent,
                    onTap: () => onStyleChanged(QuickEditCaptionsStylePreset.clean),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsStyleBold,
                    selected: stylePreset == QuickEditCaptionsStylePreset.bold,
                    accent: accent,
                    onTap: () => onStyleChanged(QuickEditCaptionsStylePreset.bold),
                  ),
                  _CaptionChip(
                    label: l10n.editCaptionsStyleDarkBox,
                    selected:
                        stylePreset == QuickEditCaptionsStylePreset.darkBox,
                    accent: accent,
                    onTap: () =>
                        onStyleChanged(QuickEditCaptionsStylePreset.darkBox),
                  ),
                ],
              ),
            ),
            _CaptionsFineTuneSection(
              accent: accent,
              scheme: scheme,
              theme: theme,
              l10n: l10n,
              offsetX: offsetX,
              offsetY: offsetY,
              onReset: onOffsetReset,
              onNudge: onOffsetNudgeAss,
            ),
          ],
          const SizedBox(height: 14),
          Text(
            l10n.editCaptionsBurnInHelper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
              height: 1.38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            autoCaptionsEnabled
                ? l10n.editCaptionsSpeechDenseHint
                : l10n.editCaptionsMayTakeLongerNote,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

String _captionsPresetChipLabel(AppLocalizations l10n, QuickEditCaptionPreset preset) {
  return switch (preset) {
    QuickEditCaptionPreset.minimal => l10n.editCaptionsPresetMinimal,
    QuickEditCaptionPreset.social => l10n.editCaptionsPresetSocial,
    QuickEditCaptionPreset.boldYellow => l10n.editCaptionsPresetBoldYellow,
    QuickEditCaptionPreset.darkBox => l10n.editCaptionsPresetDarkBox,
    QuickEditCaptionPreset.topClean => l10n.editCaptionsPresetTopClean,
    QuickEditCaptionPreset.custom => "",
  };
}

/// Preset chips (built‑in only); [QuickEditCaptionPreset.custom] surfaced as Manual badge beside title.
class _CaptionsPresetSection extends StatelessWidget {
  const _CaptionsPresetSection({
    required this.accent,
    required this.theme,
    required this.l10n,
    required this.effectivePreset,
    required this.onBuiltInSelected,
  });

  final Color accent;
  final ThemeData theme;
  final AppLocalizations l10n;
  final QuickEditCaptionPreset effectivePreset;
  final ValueChanged<QuickEditCaptionPreset> onBuiltInSelected;

  bool get _isManual =>
      effectivePreset == QuickEditCaptionPreset.custom;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;

    Widget? badge;
    if (_isManual) {
      badge = Semantics(
        label: l10n.editCaptionsPresetManualBadge,
        container: true,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.42)),
            color: scheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.38 : 0.52),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              l10n.editCaptionsPresetManualBadge,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.06,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.editCaptionsPresetLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.9),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10),
                  child: badge,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, end: 4),
            child: SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: kQuickEditCaptionBuiltInPresetsOrdered.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final p = kQuickEditCaptionBuiltInPresetsOrdered[i];
                  return _CaptionChip(
                    label: _captionsPresetChipLabel(l10n, p),
                    selected: effectivePreset == p,
                    accent: accent,
                    onTap: () => onBuiltInSelected(p),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Arrow pad uses screen-relative up/down/left/right (consistent in RTL).
class _CaptionsFineTuneSection extends StatelessWidget {
  const _CaptionsFineTuneSection({
    required this.accent,
    required this.scheme,
    required this.theme,
    required this.l10n,
    required this.offsetX,
    required this.offsetY,
    required this.onReset,
    required this.onNudge,
  });

  final Color accent;
  final ColorScheme scheme;
  final ThemeData theme;
  final AppLocalizations l10n;
  final int offsetX;
  final int offsetY;
  final VoidCallback onReset;
  final void Function(int dxAss, int dyAss) onNudge;

  @override
  Widget build(BuildContext context) {
    final dark = theme.brightness == Brightness.dark;
    final mutedAccent = accent.withValues(alpha: dark ? 0.55 : 0.85);
    final step = kQuickEditCaptionsOffsetFineStep;

    Widget padBtn({required Widget icon, required VoidCallback onPressed}) {
      return Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55),
        shape: CircleBorder(side: BorderSide(color: mutedAccent.withValues(alpha: 0.22))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: IconTheme.merge(
              data: IconThemeData(size: 20, color: scheme.onSurface.withValues(alpha: 0.72)),
              child: icon,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(
            alpha: dark ? 0.28 : 0.42,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.editCaptionsFineTuneTitle,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.editCaptionsOffsetCompact(offsetX, offsetY),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    padBtn(
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      onPressed: () => onNudge(0, -step),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        padBtn(
                          icon: const Icon(Icons.keyboard_arrow_left_rounded),
                          onPressed: () => onNudge(-step, 0),
                        ),
                        const SizedBox(width: 10),
                        padBtn(
                          icon: const Icon(Icons.keyboard_arrow_right_rounded),
                          onPressed: () => onNudge(step, 0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    padBtn(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () => onNudge(0, step),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant.withValues(alpha: 0.92),
                    textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.editCaptionsResetPosition),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _SpacingFn = Wrap Function();

class _CaptionsChipSection extends StatelessWidget {
  const _CaptionsChipSection({
    required this.accent,
    required this.title,
    required this.spacing,
  });

  final Color accent;
  final String title;
  final _SpacingFn spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          spacing(),
        ],
      ),
    );
  }
}

class _CaptionChip extends StatelessWidget {
  const _CaptionChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final mutedBlue = accent.withValues(alpha: dark ? 0.52 : 0.88);
    final borderColor =
        selected ? mutedBlue : scheme.outline.withValues(alpha: 0.32);
    final bg = selected
        ? accent.withValues(alpha: dark ? 0.14 : 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.38 : 0.48);

    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Text(
        label,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.12,
          color: selected ? accent.withValues(alpha: dark ? 0.95 : 0.94) : scheme.onSurface.withValues(alpha: 0.88),
        ),
      ),
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.25 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              child: child,
            ),
    );
  }
}