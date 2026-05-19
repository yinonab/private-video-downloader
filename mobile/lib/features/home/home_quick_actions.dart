import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/l10n/context_l10n.dart";
import "../../core/theme/linkclip_palette.dart";

/// Compact primary choices: paste a link vs edit from device.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    super.key,
    required this.onPasteLink,
    required this.onEditVideo,
  });

  final VoidCallback onPasteLink;
  final VoidCallback onEditVideo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.lcPalette;
    final dark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface,
            Color.alphaBlend(
              scheme.primary.withValues(alpha: dark ? 0.07 : 0.045),
              scheme.surface,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outline.withValues(alpha: dark ? 0.38 : 0.26),
          width: 1,
        ),
        boxShadow: dark ? const <BoxShadow>[] : palette.cardShadows.map((s) {
          return BoxShadow(
            color: s.color.withValues(alpha: s.color.a * 0.45),
            blurRadius: s.blurRadius * 0.65,
            offset: Offset(s.offset.dx, s.offset.dy * 0.7),
            spreadRadius: s.spreadRadius,
          );
        }).toList(),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.homeQuickActionsTitle,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 340;
                final gap = 8.0;
                final paste = _QuickActionTile(
                  icon: LucideIcons.link2,
                  title: l10n.homeActionPasteLinkTitle,
                  subtitle: l10n.homeActionPasteLinkSubtitle,
                  accent: scheme.primary,
                  onTap: onPasteLink,
                  emphasizePrimary: true,
                );
                final edit = _QuickActionTile(
                  icon: LucideIcons.squarePen,
                  title: l10n.homeActionEditVideoTitle,
                  subtitle: l10n.homeActionEditVideoSubtitle,
                  accent: scheme.tertiary,
                  onTap: onEditVideo,
                  emphasizePrimary: false,
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      paste,
                      SizedBox(height: gap),
                      edit,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: paste),
                    SizedBox(width: gap),
                    Expanded(child: edit),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
    required this.emphasizePrimary,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
  final bool emphasizePrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final bg = emphasizePrimary
        ? LinearGradient(
            colors: [
              accent.withValues(alpha: dark ? 0.32 : 0.42),
              accent.withValues(alpha: dark ? 0.16 : 0.26),
            ],
          )
        : LinearGradient(
            colors: [
              scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.48 : 0.62),
              scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.34 : 0.48),
            ],
          );

    final borderColor =
        emphasizePrimary ? accent.withValues(alpha: 0.42) : scheme.outline.withValues(alpha: 0.38);

    final titleColor = emphasizePrimary ? scheme.onPrimary : scheme.onSurface;
    final subColor = emphasizePrimary
        ? scheme.onPrimary.withValues(alpha: 0.88)
        : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            gradient: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: emphasizePrimary ? 1.15 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: titleColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          color: titleColor,
                          fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) * 0.98,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subColor,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) * 0.97,
                        ),
                      ),
                    ],
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
