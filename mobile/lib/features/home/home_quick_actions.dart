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
              scheme.primary.withValues(alpha: dark ? 0.14 : 0.08),
              scheme.surface,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.primary.withValues(alpha: dark ? 0.42 : 0.28),
          width: 1.2,
        ),
        boxShadow: dark ? const <BoxShadow>[] : palette.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.homeQuickActionsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 340;
                final gap = 10.0;
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
              accent.withValues(alpha: dark ? 0.42 : 0.58),
              accent.withValues(alpha: dark ? 0.22 : 0.38),
            ],
          )
        : LinearGradient(
            colors: [
              scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.55 : 0.72),
              scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.38 : 0.55),
            ],
          );

    final borderColor =
        emphasizePrimary ? accent.withValues(alpha: 0.55) : scheme.outline.withValues(alpha: 0.45);

    final titleColor = emphasizePrimary ? scheme.onPrimary : scheme.onSurface;
    final subColor = emphasizePrimary
        ? scheme.onPrimary.withValues(alpha: 0.88)
        : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: emphasizePrimary ? 1.6 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: titleColor),
                const SizedBox(width: 10),
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
                          height: 1.15,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subColor,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
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
