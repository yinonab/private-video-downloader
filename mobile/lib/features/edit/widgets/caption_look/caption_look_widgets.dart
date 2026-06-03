import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/edit/caption_look_summary.dart";
import "../../../../core/models/quick_edit_models.dart";
import "../../../../l10n/app_localizations.dart";
import "../edit_captions_preview_overlay.dart";

/// Section card with title for look editor tabs.
class CaptionLookSectionCard extends StatelessWidget {
  const CaptionLookSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.55 : 0.92,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// Circular color swatch with label (36–44px tap target).
class CaptionColorSwatchGrid extends StatelessWidget {
  const CaptionColorSwatchGrid({
    super.key,
    required this.l10n,
    required this.colors,
    required this.selected,
    required this.onSelected,
  });

  final AppLocalizations l10n;
  final List<QuickEditCaptionColor> colors;
  final QuickEditCaptionColor selected;
  final ValueChanged<QuickEditCaptionColor> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 14,
      alignment: WrapAlignment.start,
      children: [
        for (final c in colors)
          _CaptionColorSwatch(
            label: captionColorLabel(l10n, c),
            color: captionColorToFlutter(c),
            selected: selected == c,
            onTap: () => onSelected(c),
          ),
      ],
    );
  }
}

class _CaptionColorSwatch extends StatelessWidget {
  const _CaptionColorSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final needsBorder =
        color == Colors.white || color.computeLuminance() > 0.92;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: selected
                          ? scheme.primary
                          : needsBorder
                              ? scheme.outline.withValues(alpha: 0.55)
                              : Colors.transparent,
                      width: selected ? 3 : needsBorder ? 1.5 : 0,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Large selectable tile (font, size, position, highlight mode).
class CaptionLookChoiceTile extends StatelessWidget {
  const CaptionLookChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.minHeight = 52,
  });

  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: scheme.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual preset card for the Presets tab.
class CaptionLookPresetCard extends StatelessWidget {
  const CaptionLookPresetCard({
    super.key,
    required this.l10n,
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final recipe = captionPresetRecipe(preset)!;
    final title = captionPresetTitle(l10n, preset);
    final tags = captionPresetTagLine(l10n, preset);

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.42)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.38),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.28),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          color: scheme.primary, size: 22),
                  ],
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tags,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.88),
                    child: SizedBox(
                      height: 56,
                      child: EditCaptionsPreviewOverlay(
                        l10n: l10n,
                        stylePreset: recipe.style,
                        fontSize: recipe.fontSize,
                        fontFamily: recipe.fontFamily,
                        position: recipe.position,
                        color: recipe.color,
                        wordHighlight: recipe.wordHighlight,
                        normalTextColor: recipe.normalTextColor,
                        activeTextColor: recipe.activeTextColor,
                        boxColor: recipe.boxColor,
                        boxShape: recipe.boxShape,
                        offsetXAss: 0,
                        offsetYAss: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Box shape picker with mini shape preview.
class CaptionBoxShapeGrid extends StatelessWidget {
  const CaptionBoxShapeGrid({
    super.key,
    required this.l10n,
    required this.selected,
    required this.onSelected,
    required this.sampleBoxColor,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionBoxShape selected;
  final ValueChanged<QuickEditCaptionBoxShape> onSelected;
  final QuickEditCaptionColor sampleBoxColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final s in const [
          QuickEditCaptionBoxShape.rectangle,
          QuickEditCaptionBoxShape.rounded,
          QuickEditCaptionBoxShape.pill,
        ])
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                end: s != QuickEditCaptionBoxShape.pill ? 8 : 0,
              ),
              child: _BoxShapeCard(
                label: captionBoxShapeLabel(l10n, s),
                shape: s,
                boxColor: captionColorToFlutter(sampleBoxColor),
                selected: selected == s,
                onTap: () => onSelected(s),
              ),
            ),
          ),
      ],
    );
  }
}

class _BoxShapeCard extends StatelessWidget {
  const _BoxShapeCard({
    required this.label,
    required this.shape,
    required this.boxColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final QuickEditCaptionBoxShape shape;
  final Color boxColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = switch (shape) {
      QuickEditCaptionBoxShape.rectangle => 2.0,
      QuickEditCaptionBoxShape.rounded => 8.0,
      QuickEditCaptionBoxShape.pill => 999.0,
    };

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.5)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 22,
                  decoration: BoxDecoration(
                    color: boxColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact static preview strip at top of look editor.
class CaptionLookEditorPreviewStrip extends StatelessWidget {
  const CaptionLookEditorPreviewStrip({
    super.key,
    required this.l10n,
    required this.snapshot,
  });

  final AppLocalizations l10n;
  final CaptionLookSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.9),
        child: SizedBox(
          height: 72,
          child: EditCaptionsPreviewOverlay(
            l10n: l10n,
            stylePreset: snapshot.style,
            fontSize: snapshot.fontSize,
            fontFamily: snapshot.fontFamily,
            position: snapshot.position,
            color: snapshot.color,
            wordHighlight: snapshot.wordHighlight,
            normalTextColor: snapshot.normalTextColor,
            activeTextColor: snapshot.activeTextColor,
            boxColor: snapshot.boxColor,
            boxShape: snapshot.boxShape,
            offsetXAss: snapshot.offsetX,
            offsetYAss: snapshot.offsetY,
          ),
        ),
      ),
    );
  }
}

TextStyle captionLookFontPreviewStyle(
  QuickEditCaptionFontFamily family,
  ThemeData theme,
) {
  final base = theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);
  return switch (family) {
    QuickEditCaptionFontFamily.heebo => GoogleFonts.heebo(textStyle: base),
    QuickEditCaptionFontFamily.rubik => GoogleFonts.rubik(textStyle: base),
    QuickEditCaptionFontFamily.assistant => GoogleFonts.assistant(textStyle: base),
    QuickEditCaptionFontFamily.notoSansHebrew =>
      GoogleFonts.notoSansHebrew(textStyle: base),
    QuickEditCaptionFontFamily.defaultFamily =>
      GoogleFonts.notoSansHebrew(textStyle: base),
  };
}

const List<QuickEditCaptionColor> kCaptionLookTextColors = [
  QuickEditCaptionColor.white,
  QuickEditCaptionColor.yellow,
  QuickEditCaptionColor.pink,
  QuickEditCaptionColor.purple,
  QuickEditCaptionColor.mint,
  QuickEditCaptionColor.black,
];

const List<QuickEditCaptionColor> kCaptionLookBoxColors = [
  QuickEditCaptionColor.white,
  QuickEditCaptionColor.yellow,
  QuickEditCaptionColor.pink,
  QuickEditCaptionColor.purple,
  QuickEditCaptionColor.mint,
  QuickEditCaptionColor.black,
];
