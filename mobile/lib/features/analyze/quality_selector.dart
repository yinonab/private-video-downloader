import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/format_display.dart";
import "../../core/models/analyze_models.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/widgets/linkclip_chips.dart";

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
      return LucideIcons.music2;
    default:
      return LucideIcons.film;
  }
}

/// Visual choice list for yt-dlp format presets returned by [/analyze].
class QualitySelector extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.lcPalette;
    final bright = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.analyzeChooseQuality,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
        ),
        const SizedBox(height: 12),
        ...List.generate(formats.length, (i) {
          final f = formats[i];
          final selected = i == selectedIndex;
          final disabled = !f.available;
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
            bg = Color.alphaBlend(palette.tiktokAccentSoft.withValues(alpha: bright == Brightness.dark ? 0.42 : 0.62), scheme.surface);
          } else if (selected) {
            bg = scheme.primaryContainer.withValues(alpha: bright == Brightness.dark ? 0.58 : 0.82);
          } else {
            bg = scheme.surfaceContainerHighest.withValues(alpha: bright == Brightness.dark ? 0.42 : 0.55);
          }

          final iconFg = disabled
              ? scheme.outline
              : tikTokSpecial
                  ? palette.tiktokAccent
                  : scheme.primary;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: disabled ? null : () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.surface.withValues(alpha: bright == Brightness.dark ? 0.35 : 0.72),
                          border: Border.all(color: scheme.outline.withValues(alpha: 0.28)),
                        ),
                        child: Icon(iconData, color: iconFg, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  rowLabel,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: disabled ? scheme.onSurfaceVariant : scheme.onSurface,
                                        letterSpacing: -0.15,
                                      ),
                                ),
                                if (!disabled && tikTokSpecial)
                                  LinkClipTikTokChip(label: l10n.qualityTikTokReadyBadge),
                              ],
                            ),
                            if (!disabled && tikTokSpecial) ...[
                              const SizedBox(height: 8),
                              Text(
                                l10n.qualityTikTokReadyDescription,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.38,
                                    ),
                              ),
                            ],
                            if (disabled) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.qualityUnavailableForVideo,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.outline,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        disabled ? LucideIcons.circleMinus : selected ? LucideIcons.circleCheck : LucideIcons.circle,
                        color: disabled ? scheme.outline : selected ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
              .animate()
              .fadeIn(delay: (35 * i).ms, duration: 240.ms, curve: Curves.easeOut)
              .slideX(begin: 0.02, end: 0, duration: 260.ms, curve: Curves.easeOut);
        }),
      ],
    );
  }
}
