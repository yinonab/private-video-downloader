import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/format_display.dart";
import "../../core/models/analyze_models.dart";
import "../../core/theme/linkclip_design_system.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/widgets/linkclip_chips.dart";

enum _FormatTab { video, audio }

IconData _qualityIcon(String value, bool disabled, Color primary, Color outline) {
  switch (value) {
    case "best":
      return LucideIcons.sparkles;
    case "1080p":
      return LucideIcons.monitorPlay;
    case "720p":
      return LucideIcons.hd;
    case "480p":
      return LucideIcons.smartphone;
    case "tiktok_ready":
      return LucideIcons.share2;
    case "audio":
    case "audio_mp3":
      return LucideIcons.audioLines;
    default:
      return LucideIcons.film;
  }
}

/// Video / Audio tabbed quality picker for [/analyze] results.
class QualitySelector extends StatefulWidget {
  const QualitySelector({
    super.key,
    required this.formats,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<FormatOption> formats;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  State<QualitySelector> createState() => _QualitySelectorState();
}

class _QualitySelectorState extends State<QualitySelector> {
  late _FormatTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = _tabForSelectedIndex(widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant QualitySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.formats != widget.formats) {
      _tab = _tabForSelectedIndex(widget.selectedIndex);
    }
  }

  _FormatTab _tabForSelectedIndex(int index) {
    if (index < 0 || index >= widget.formats.length) return _FormatTab.video;
    return FormatOption.isAudioFormat(widget.formats[index])
        ? _FormatTab.audio
        : _FormatTab.video;
  }

  List<int> get _visibleIndices => _tab == _FormatTab.audio
      ? FormatOption.indicesForAudio(widget.formats)
      : FormatOption.indicesForVideo(widget.formats);

  bool get _showTabs =>
      FormatOption.indicesForVideo(widget.formats).isNotEmpty &&
      FormatOption.indicesForAudio(widget.formats).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final palette = context.lcPalette;
    final bright = theme.brightness;
    final indices = _visibleIndices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinkClipSectionHeader(title: l10n.analyzeChooseQuality),
        if (_showTabs) ...[
          const SizedBox(height: LcSpace.md),
          SegmentedButton<_FormatTab>(
            segments: [
              ButtonSegment(
                value: _FormatTab.video,
                label: Text(l10n.analyzeFormatTabVideo),
                icon: const Icon(LucideIcons.film, size: 18),
              ),
              ButtonSegment(
                value: _FormatTab.audio,
                label: Text(l10n.analyzeFormatTabAudio),
                icon: const Icon(LucideIcons.audioLines, size: 18),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              setState(() => _tab = s.first);
            },
          ),
        ],
        const SizedBox(height: LcSpace.md),
        if (indices.isEmpty)
          Text(
            l10n.qualityUnavailableForVideo,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          )
        else
          ...List.generate(indices.length, (row) {
            final i = indices[row];
            final f = widget.formats[i];
            final selected = i == widget.selectedIndex;
            final disabled = !f.available;
            final isAudio = FormatOption.isAudioFormat(f);
            final rowLabel = formatOptionDisplayLabel(context, f);
            final tikTokSpecial = f.value == "tiktok_ready";
            final iconData = _qualityIcon(
              f.value,
              disabled,
              tikTokSpecial ? palette.tiktokAccent : scheme.primary,
              scheme.outline,
            );

            Color bg;
            if (disabled) {
              bg = scheme.surfaceContainerHighest.withValues(alpha: 0.35);
            } else if (tikTokSpecial && selected) {
              bg = Color.alphaBlend(
                palette.tiktokAccentSoft.withValues(
                    alpha: bright == Brightness.dark ? 0.42 : 0.62),
                scheme.surface,
              );
            } else if (selected) {
              bg = scheme.primaryContainer.withValues(
                  alpha: bright == Brightness.dark ? 0.58 : 0.82);
            } else if (isAudio) {
              bg = scheme.secondaryContainer.withValues(
                  alpha: bright == Brightness.dark ? 0.45 : 0.72);
            } else {
              bg = scheme.surfaceContainerHighest.withValues(
                  alpha: bright == Brightness.dark ? 0.42 : 0.55);
            }

            final iconFg = disabled
                ? scheme.outline
                : tikTokSpecial
                    ? palette.tiktokAccent
                    : isAudio
                        ? scheme.secondary
                        : scheme.primary;

            final borderColor = disabled
                ? scheme.outline.withValues(alpha: 0.18)
                : selected
                    ? (tikTokSpecial
                        ? palette.tiktokAccent.withValues(alpha: 0.55)
                        : scheme.primary.withValues(alpha: 0.45))
                    : scheme.outline.withValues(alpha: 0.22);

            return Padding(
              padding: const EdgeInsets.only(bottom: LcSpace.sm),
              child: Material(
                color: bg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LcRadius.medium),
                  side: BorderSide(
                    color: borderColor,
                    width: selected && !disabled ? 1.4 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: disabled ? null : () => widget.onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LcSpace.lg,
                      vertical: LcSpace.lg,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(iconData, color: iconFg, size: 22),
                        const SizedBox(width: LcSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                spacing: LcSpace.sm,
                                runSpacing: LcSpace.xs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    rowLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: disabled
                                          ? scheme.onSurfaceVariant
                                          : scheme.onSurface,
                                      letterSpacing: -0.15,
                                    ),
                                  ),
                                  if (!disabled && tikTokSpecial)
                                    LinkClipTikTokChip(
                                        label: l10n.qualityTikTokReadyBadge),
                                ],
                              ),
                              if (!disabled && isAudio) ...[
                                const SizedBox(height: LcSpace.xs),
                                Text(
                                  l10n.formatAudioMp3Subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: LcSpace.xs),
                                Text(
                                  l10n.formatAudioMp3Description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (!disabled && tikTokSpecial) ...[
                                const SizedBox(height: LcSpace.sm),
                                Text(
                                  l10n.qualityTikTokReadyDescription,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (disabled) ...[
                                const SizedBox(height: LcSpace.xs),
                                Text(
                                  l10n.qualityUnavailableForVideo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.outline,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: LcSpace.sm),
                        Icon(
                          disabled
                              ? LucideIcons.circleMinus
                              : selected
                                  ? LucideIcons.circleCheck
                                  : LucideIcons.circle,
                          color: disabled
                              ? scheme.outline
                              : selected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant
                                      .withValues(alpha: 0.55),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(
                    delay: (30 * row).ms,
                    duration: 220.ms,
                    curve: Curves.easeOut)
                .slideY(
                    begin: 0.02,
                    end: 0,
                    duration: 240.ms,
                    curve: Curves.easeOut);
          }),
      ],
    );
  }
}
