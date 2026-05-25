import "package:flutter/material.dart";

import "../../../core/theme/linkclip_palette.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../l10n/app_localizations.dart";

/// Quick Edit — captions **V1.5**: auto transcription + burned-in subtitles with basic styling (server-side).
class CaptionsEditorPanel extends StatelessWidget {
  const CaptionsEditorPanel({
    super.key,
    required this.autoCaptionsEnabled,
    required this.stylePreset,
    required this.fontSize,
    required this.position,
    required this.color,
    required this.onAutoCaptionsChanged,
    required this.onStyleChanged,
    required this.onFontSizeChanged,
    required this.onPositionChanged,
    required this.onColorChanged,
  });

  final bool autoCaptionsEnabled;
  final QuickEditCaptionsStylePreset stylePreset;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;

  final ValueChanged<bool> onAutoCaptionsChanged;
  final ValueChanged<QuickEditCaptionsStylePreset> onStyleChanged;
  final ValueChanged<QuickEditCaptionFontSize> onFontSizeChanged;
  final ValueChanged<QuickEditCaptionPosition> onPositionChanged;
  final ValueChanged<QuickEditCaptionColor> onColorChanged;

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
            _CaptionsChipSection(
              accent: accent,
              title: l10n.editCaptionsTextSizeLabel,
              spacing: () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
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
            const SizedBox(height: 14),
            _CaptionsSampleCard(
              l10n: l10n,
              stylePreset: stylePreset,
              fontSize: fontSize,
              position: position,
              color: color,
            ),
            const SizedBox(height: 4),
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
  final VoidCallback onTap;

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

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.25 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
        ),
      ),
    );
  }
}

class _CaptionsSampleCard extends StatelessWidget {
  const _CaptionsSampleCard({
    required this.l10n,
    required this.stylePreset,
    required this.fontSize,
    required this.position,
    required this.color,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionsStylePreset stylePreset;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionPosition position;
  final QuickEditCaptionColor color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textColor =
        color == QuickEditCaptionColor.yellow ? const Color(0xFFFFD966) : Colors.white;
    final fz = switch (fontSize) {
      QuickEditCaptionFontSize.small => 12.0,
      QuickEditCaptionFontSize.medium => 13.5,
      QuickEditCaptionFontSize.large => 15.5,
    };
    final fw = switch (stylePreset) {
      QuickEditCaptionsStylePreset.bold => FontWeight.w700,
      _ => FontWeight.w500,
    };

    late final Widget sampleBody;
    switch (stylePreset) {
      case QuickEditCaptionsStylePreset.darkBox:
        sampleBody = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.74),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            l10n.editCaptionsSampleLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: textColor,
              fontSize: fz,
              fontWeight: fw,
              height: 1.22,
            ),
          ),
        );
        break;
      case QuickEditCaptionsStylePreset.bold:
        sampleBody = Text(
          l10n.editCaptionsSampleLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            color: textColor,
            fontSize: fz,
            fontWeight: fw,
            height: 1.22,
            shadows: [
              Shadow(blurRadius: 14, color: Colors.black.withValues(alpha: 0.92)),
              const Shadow(blurRadius: 0, offset: Offset(0, 1.5), color: Colors.black87),
            ],
          ),
        );
        break;
      case QuickEditCaptionsStylePreset.clean:
        sampleBody = Text(
          l10n.editCaptionsSampleLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            color: textColor,
            fontSize: fz,
            fontWeight: fw,
            height: 1.22,
            shadows: [
              Shadow(blurRadius: 10, color: Colors.black.withValues(alpha: 0.88)),
            ],
          ),
        );
    }

    final preview = SizedBox(
      height: 86,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.shade700.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: position == QuickEditCaptionPosition.top
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: position == QuickEditCaptionPosition.top ? 10 : 26,
                    bottom: position == QuickEditCaptionPosition.bottom ? 10 : 26,
                    left: 12,
                    right: 12,
                  ),
                  child: sampleBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.editCaptionsSampleHeading,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
              ),
        ),
        const SizedBox(height: 6),
        preview,
      ],
    );
  }
}
