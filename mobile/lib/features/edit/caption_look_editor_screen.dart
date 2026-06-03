import "package:flutter/material.dart";

import "../../core/edit/caption_look_summary.dart";
import "../../core/models/quick_edit_models.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../l10n/app_localizations.dart";
import "widgets/caption_look/caption_look_fine_tune_section.dart";
import "widgets/caption_look/caption_look_widgets.dart";

/// Full-screen caption look editor (V3.4D) — presets, text, highlight, position.
class CaptionLookEditorScreen extends StatefulWidget {
  const CaptionLookEditorScreen({
    super.key,
    required this.initial,
  });

  final CaptionLookSnapshot initial;

  @override
  State<CaptionLookEditorScreen> createState() => _CaptionLookEditorScreenState();
}

class _CaptionLookEditorScreenState extends State<CaptionLookEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late QuickEditCaptionsStylePreset _style;
  late QuickEditCaptionFontSize _fontSize;
  late QuickEditCaptionFontFamily _fontFamily;
  late QuickEditCaptionPosition _position;
  late QuickEditCaptionColor _color;
  late QuickEditCaptionWordHighlight _wordHighlight;
  late int _offsetX;
  late int _offsetY;
  QuickEditCaptionColor? _normalTextColor;
  QuickEditCaptionColor? _activeTextColor;
  QuickEditCaptionColor? _boxColor;
  late QuickEditCaptionBoxShape _boxShape;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _style = i.style;
    _fontSize = i.fontSize;
    _fontFamily = i.fontFamily;
    _position = i.position;
    _color = i.color;
    _wordHighlight = i.wordHighlight;
    _offsetX = i.offsetX;
    _offsetY = i.offsetY;
    _normalTextColor = i.normalTextColor;
    _activeTextColor = i.activeTextColor;
    _boxColor = i.boxColor;
    _boxShape = i.boxShape;
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  CaptionLookSnapshot get _snapshot => captionLookSnapshotFrom(
        style: _style,
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        position: _position,
        color: _color,
        wordHighlight: _wordHighlight,
        offsetX: _offsetX,
        offsetY: _offsetY,
        normalTextColor: _normalTextColor,
        activeTextColor: _activeTextColor,
        boxColor: _boxColor,
        boxShape: _boxShape,
      );

  QuickEditCaptionPreset get _effectivePreset => inferQuickEditCaptionPreset(
        fontSize: _fontSize,
        fontFamily: _fontFamily,
        position: _position,
        color: _color,
        style: _style,
        wordHighlight: _wordHighlight,
        offsetX: _offsetX,
        offsetY: _offsetY,
        normalTextColor: _normalTextColor,
        activeTextColor: _activeTextColor,
        boxColor: _boxColor,
        boxShape: _boxShape,
      );

  void _applyPreset(QuickEditCaptionPreset preset) {
    final r = captionPresetRecipe(preset);
    if (r == null) return;
    setState(() {
      applyCaptionPresetFields(
        r,
        setFontSize: (v) => _fontSize = v,
        setFontFamily: (v) => _fontFamily = v,
        setPosition: (v) => _position = v,
        setColor: (v) => _color = v,
        setStyle: (v) => _style = v,
        setWordHighlight: (v) {
          _wordHighlight = v;
          if (v == QuickEditCaptionWordHighlight.none) {
            _normalTextColor = null;
            _activeTextColor = null;
            _boxColor = null;
          }
        },
        setOffsetX: (v) => _offsetX = v,
        setOffsetY: (v) => _offsetY = v,
        setNormalTextColor: (v) => _normalTextColor = v,
        setActiveTextColor: (v) => _activeTextColor = v,
        setBoxColor: (v) => _boxColor = v,
        setBoxShape: (v) => _boxShape = v,
      );
    });
  }

  void _done() {
    Navigator.of(context).pop(_snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = context.lcPalette.tiktokAccent;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editCaptionsV34LookEditorTitle),
        actions: [
          TextButton(
            onPressed: _done,
            child: Text(
              l10n.editCaptionsV34Done,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: theme.textTheme.titleSmall,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: l10n.editCaptionsV34TabPresets, height: 48),
            Tab(text: l10n.editCaptionsV34TabText, height: 48),
            Tab(text: l10n.editCaptionsV34TabHighlight, height: 48),
            Tab(text: l10n.editCaptionsV34TabPosition, height: 48),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CaptionLookEditorPreviewStrip(l10n: l10n, snapshot: _snapshot),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _PresetsTab(
                  l10n: l10n,
                  effectivePreset: _effectivePreset,
                  onPreset: _applyPreset,
                ),
                _TextTab(
                  l10n: l10n,
                  fontFamily: _fontFamily,
                  fontSize: _fontSize,
                  normalColor: effectiveCaptionNormalTextColor(
                    color: _color,
                    normalTextColor: _normalTextColor,
                  ),
                  onFontFamily: (v) => setState(() => _fontFamily = v),
                  onFontSize: (v) => setState(() => _fontSize = v),
                  onNormalColor: (v) => setState(() => _normalTextColor = v),
                ),
                _HighlightTab(
                  l10n: l10n,
                  wordHighlight: _wordHighlight,
                  color: _color,
                  normalTextColor: _normalTextColor,
                  activeTextColor: _activeTextColor,
                  boxColor: _boxColor,
                  boxShape: _boxShape,
                  onWordHighlight: (v) => setState(() {
                    _wordHighlight = v;
                    if (v == QuickEditCaptionWordHighlight.none) {
                      _normalTextColor = null;
                      _activeTextColor = null;
                      _boxColor = null;
                    }
                  }),
                  onActiveColor: (v) => setState(() => _activeTextColor = v),
                  onBoxColor: (v) => setState(() => _boxColor = v),
                  onBoxShape: (v) => setState(() => _boxShape = v),
                ),
                _PositionTab(
                  l10n: l10n,
                  accent: accent,
                  position: _position,
                  offsetX: _offsetX,
                  offsetY: _offsetY,
                  onPosition: (v) => setState(() => _position = v),
                  onReset: () => setState(() {
                    _offsetX = 0;
                    _offsetY = 0;
                  }),
                  onNudge: (dx, dy) => setState(() {
                    _offsetX = clampQuickEditCaptionOffsetX(_offsetX + dx);
                    _offsetY = clampQuickEditCaptionOffsetY(_offsetY + dy);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetsTab extends StatelessWidget {
  const _PresetsTab({
    required this.l10n,
    required this.effectivePreset,
    required this.onPreset,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionPreset effectivePreset;
  final ValueChanged<QuickEditCaptionPreset> onPreset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final p in kCaptionLookEditorPresetsOrdered) ...[
          CaptionLookPresetCard(
            l10n: l10n,
            preset: p,
            selected: effectivePreset == p,
            onTap: () => onPreset(p),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TextTab extends StatelessWidget {
  const _TextTab({
    required this.l10n,
    required this.fontFamily,
    required this.fontSize,
    required this.normalColor,
    required this.onFontFamily,
    required this.onFontSize,
    required this.onNormalColor,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionFontFamily fontFamily;
  final QuickEditCaptionFontSize fontSize;
  final QuickEditCaptionColor normalColor;
  final ValueChanged<QuickEditCaptionFontFamily> onFontFamily;
  final ValueChanged<QuickEditCaptionFontSize> onFontSize;
  final ValueChanged<QuickEditCaptionColor> onNormalColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        CaptionLookSectionCard(
          title: l10n.editCaptionsV32FontLabel,
          child: Column(
            children: [
              for (final f in const [
                QuickEditCaptionFontFamily.defaultFamily,
                QuickEditCaptionFontFamily.heebo,
                QuickEditCaptionFontFamily.rubik,
                QuickEditCaptionFontFamily.assistant,
                QuickEditCaptionFontFamily.notoSansHebrew,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CaptionLookChoiceTile(
                    label: captionFontFamilyShortLabel(l10n, f),
                    selected: fontFamily == f,
                    onTap: () => onFontFamily(f),
                    leading: Text(
                      "Aa",
                      style: captionLookFontPreviewStyle(f, theme),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CaptionLookSectionCard(
          title: l10n.editCaptionsTextSizeLabel,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in const [
                QuickEditCaptionFontSize.extraSmall,
                QuickEditCaptionFontSize.small,
                QuickEditCaptionFontSize.medium,
                QuickEditCaptionFontSize.large,
                QuickEditCaptionFontSize.xLarge,
                QuickEditCaptionFontSize.xxLarge,
              ])
                _SizeChip(
                  label: _sizeLabel(l10n, s),
                  selected: fontSize == s,
                  onTap: () => onFontSize(s),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CaptionLookSectionCard(
          title: l10n.editCaptionsV34NormalTextColor,
          child: CaptionColorSwatchGrid(
            l10n: l10n,
            colors: kCaptionLookTextColors,
            selected: normalColor,
            onSelected: onNormalColor,
          ),
        ),
      ],
    );
  }

  String _sizeLabel(AppLocalizations l10n, QuickEditCaptionFontSize s) {
    return switch (s) {
      QuickEditCaptionFontSize.extraSmall => l10n.editCaptionsSizeExtraSmall,
      QuickEditCaptionFontSize.small => l10n.editCaptionsSizeSmall,
      QuickEditCaptionFontSize.medium => l10n.editCaptionsSizeMedium,
      QuickEditCaptionFontSize.large => l10n.editCaptionsSizeLarge,
      QuickEditCaptionFontSize.xLarge => l10n.editCaptionsV32SizeXL,
      QuickEditCaptionFontSize.xxLarge => l10n.editCaptionsV32SizeXXL,
    };
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

class _HighlightTab extends StatelessWidget {
  const _HighlightTab({
    required this.l10n,
    required this.wordHighlight,
    required this.color,
    required this.normalTextColor,
    required this.activeTextColor,
    required this.boxColor,
    required this.boxShape,
    required this.onWordHighlight,
    required this.onActiveColor,
    required this.onBoxColor,
    required this.onBoxShape,
  });

  final AppLocalizations l10n;
  final QuickEditCaptionWordHighlight wordHighlight;
  final QuickEditCaptionColor color;
  final QuickEditCaptionColor? normalTextColor;
  final QuickEditCaptionColor? activeTextColor;
  final QuickEditCaptionColor? boxColor;
  final QuickEditCaptionBoxShape boxShape;
  final ValueChanged<QuickEditCaptionWordHighlight> onWordHighlight;
  final ValueChanged<QuickEditCaptionColor> onActiveColor;
  final ValueChanged<QuickEditCaptionColor> onBoxColor;
  final ValueChanged<QuickEditCaptionBoxShape> onBoxShape;

  @override
  Widget build(BuildContext context) {
    final showHighlight = wordHighlight != QuickEditCaptionWordHighlight.none;
    final effActive = effectiveCaptionActiveTextColor(
      color: color,
      wordHighlight: wordHighlight,
      normalTextColor: normalTextColor,
      activeTextColor: activeTextColor,
      boxColor: boxColor,
    );
    final effBox = effectiveCaptionBoxColor(
      color: color,
      wordHighlight: wordHighlight,
      boxColor: boxColor,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        CaptionLookSectionCard(
          title: l10n.editCaptionsV33WordHighlightLabel,
          child: Column(
            children: [
              for (final h in const [
                QuickEditCaptionWordHighlight.none,
                QuickEditCaptionWordHighlight.color,
                QuickEditCaptionWordHighlight.box,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CaptionLookChoiceTile(
                    label: _highlightLabel(l10n, h),
                    subtitle: _highlightSubtitle(l10n, h),
                    selected: wordHighlight == h,
                    onTap: () => onWordHighlight(h),
                    leading: _HighlightModeIcon(mode: h),
                    minHeight: 56,
                  ),
                ),
            ],
          ),
        ),
        if (showHighlight) ...[
          const SizedBox(height: 16),
          CaptionLookSectionCard(
            title: l10n.editCaptionsV34ActiveWordColor,
            child: CaptionColorSwatchGrid(
              l10n: l10n,
              colors: kCaptionLookTextColors,
              selected: effActive,
              onSelected: onActiveColor,
            ),
          ),
        ],
        if (wordHighlight == QuickEditCaptionWordHighlight.box) ...[
          const SizedBox(height: 16),
          CaptionLookSectionCard(
            title: l10n.editCaptionsV34BoxColor,
            child: CaptionColorSwatchGrid(
              l10n: l10n,
              colors: kCaptionLookBoxColors,
              selected: effBox,
              onSelected: onBoxColor,
            ),
          ),
          const SizedBox(height: 16),
          CaptionLookSectionCard(
            title: l10n.editCaptionsV34BoxShape,
            child: CaptionBoxShapeGrid(
              l10n: l10n,
              selected: boxShape,
              onSelected: onBoxShape,
              sampleBoxColor: effBox,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.editCaptionsV34HighlightDraftHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.88),
                height: 1.4,
              ),
        ),
      ],
    );
  }

  String _highlightLabel(AppLocalizations l10n, QuickEditCaptionWordHighlight h) {
    return switch (h) {
      QuickEditCaptionWordHighlight.none => l10n.editCaptionsV33WordHighlightOff,
      QuickEditCaptionWordHighlight.color => l10n.editCaptionsV33WordHighlightColor,
      QuickEditCaptionWordHighlight.box => l10n.editCaptionsV33WordHighlightBox,
    };
  }

  String _highlightSubtitle(AppLocalizations l10n, QuickEditCaptionWordHighlight h) {
    return switch (h) {
      QuickEditCaptionWordHighlight.none => l10n.editCaptionsV34HighlightModeOffHint,
      QuickEditCaptionWordHighlight.color => l10n.editCaptionsV34HighlightModeColorHint,
      QuickEditCaptionWordHighlight.box => l10n.editCaptionsV34HighlightModeBoxHint,
    };
  }
}

class _HighlightModeIcon extends StatelessWidget {
  const _HighlightModeIcon({required this.mode});

  final QuickEditCaptionWordHighlight mode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: switch (mode) {
        QuickEditCaptionWordHighlight.none => const Text(
            "Abc",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        QuickEditCaptionWordHighlight.color => RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(fontSize: 13, color: Colors.white),
              children: [
                TextSpan(text: "Ab"),
                TextSpan(
                  text: "c",
                  style: TextStyle(color: Color(0xFFFFD966), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        QuickEditCaptionWordHighlight.box => RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.white),
              children: [
                const TextSpan(text: "A"),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C8A).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "b",
                      style: TextStyle(fontSize: 11, color: Colors.black),
                    ),
                  ),
                ),
                const TextSpan(text: "c"),
              ],
            ),
          ),
      },
    );
  }
}

class _PositionTab extends StatelessWidget {
  const _PositionTab({
    required this.l10n,
    required this.accent,
    required this.position,
    required this.offsetX,
    required this.offsetY,
    required this.onPosition,
    required this.onReset,
    required this.onNudge,
  });

  final AppLocalizations l10n;
  final Color accent;
  final QuickEditCaptionPosition position;
  final int offsetX;
  final int offsetY;
  final ValueChanged<QuickEditCaptionPosition> onPosition;
  final VoidCallback onReset;
  final void Function(int dx, int dy) onNudge;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        CaptionLookSectionCard(
          title: l10n.editCaptionsPositionLabel,
          child: Column(
            children: [
              CaptionLookChoiceTile(
                label: l10n.editCaptionsPositionTop,
                selected: position == QuickEditCaptionPosition.top,
                onTap: () => onPosition(QuickEditCaptionPosition.top),
                minHeight: 56,
              ),
              const SizedBox(height: 8),
              CaptionLookChoiceTile(
                label: l10n.editCaptionsPositionBottom,
                selected: position == QuickEditCaptionPosition.bottom,
                onTap: () => onPosition(QuickEditCaptionPosition.bottom),
                minHeight: 56,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CaptionLookSectionCard(
          title: l10n.editCaptionsFineTuneTitle,
          child: CaptionLookFineTuneSection(
            accent: accent,
            l10n: l10n,
            offsetX: offsetX,
            offsetY: offsetY,
            onReset: onReset,
            onNudge: onNudge,
          ),
        ),
      ],
    );
  }
}
