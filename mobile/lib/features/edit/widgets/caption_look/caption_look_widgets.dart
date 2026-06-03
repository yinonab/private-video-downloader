import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../core/edit/caption_look_summary.dart";
import "../../../../core/models/quick_edit_models.dart";
import "../../../../l10n/app_localizations.dart";
import "../edit_captions_preview_overlay.dart";

/// Minimum width for two-column preset grid.
const double kCaptionLookPresetGridMinWidth = 340;

/// Section card with title for look editor tabs.
class CaptionLookSectionCard extends StatelessWidget {
  const CaptionLookSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool dense;

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
        padding: EdgeInsets.fromLTRB(14, dense ? 10 : 12, 14, dense ? 12 : 14),
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
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: dense ? 10 : 12),
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
      spacing: 8,
      runSpacing: 10,
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

/// Compact preset card — color dots + tags (no embedded video preview).
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
    final subtitle = captionPresetCompactSubtitle(l10n, preset);
    final subtitleLines = subtitle.split("\n");

    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.38)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.32),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outline.withValues(alpha: 0.24),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: 4),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: scheme.primary,
                          size: 18,
                        ),
                      ),
                  ],
                ),
                for (final line in subtitleLines)
                  if (line.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        line.trim(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                const SizedBox(height: 8),
                CaptionPresetColorDots(recipe: recipe),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small color dots for a preset recipe (normal / active / box).
class CaptionPresetColorDots extends StatelessWidget {
  const CaptionPresetColorDots({super.key, required this.recipe});

  final CaptionPresetFields recipe;

  @override
  Widget build(BuildContext context) {
    final normal = effectiveCaptionNormalTextColor(
      color: recipe.color,
      normalTextColor: recipe.normalTextColor,
    );
    final active = effectiveCaptionActiveTextColor(
      color: recipe.color,
      wordHighlight: recipe.wordHighlight,
      normalTextColor: recipe.normalTextColor,
      activeTextColor: recipe.activeTextColor,
      boxColor: recipe.boxColor,
    );

    final dots = <Widget>[
      _StyleColorDot(color: captionColorToFlutter(normal)),
    ];

    if (recipe.wordHighlight != QuickEditCaptionWordHighlight.none) {
      dots.add(_StyleColorDot(color: captionColorToFlutter(active)));
    }
    if (recipe.wordHighlight == QuickEditCaptionWordHighlight.box) {
      final box = effectiveCaptionBoxColor(
        color: recipe.color,
        wordHighlight: recipe.wordHighlight,
        boxColor: recipe.boxColor,
      );
      dots.add(_StyleColorDot(color: captionColorToFlutter(box)));
    }

    return Row(
      children: [
        for (var i = 0; i < dots.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          dots[i],
        ],
      ],
    );
  }
}

class _StyleColorDot extends StatelessWidget {
  const _StyleColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final needsBorder =
        color == Colors.white || color.computeLuminance() > 0.92;
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: needsBorder
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
              )
            : null,
      ),
    );
  }
}

/// Presets tab: 2-column grid when wide enough, else compact single column.
class CaptionLookPresetGrid extends StatelessWidget {
  const CaptionLookPresetGrid({
    super.key,
    required this.l10n,
    required this.effectivePreset,
    required this.onPreset,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionPreset effectivePreset;
  final ValueChanged<QuickEditCaptionPreset> onPreset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= kCaptionLookPresetGridMinWidth;
        final presets = kCaptionLookEditorPresetsOrdered;

        if (useGrid) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.42,
            ),
            itemCount: presets.length,
            itemBuilder: (context, i) {
              final p = presets[i];
              return CaptionLookPresetCard(
                l10n: l10n,
                preset: p,
                selected: effectivePreset == p,
                onTap: () => onPreset(p),
              );
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: presets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final p = presets[i];
            return CaptionLookPresetCard(
              l10n: l10n,
              preset: p,
              selected: effectivePreset == p,
              onTap: () => onPreset(p),
            );
          },
        );
      },
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
          height: 60,
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
