import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/l10n/context_l10n.dart";

/// Compact horizontal row: paste link vs edit from device (RTL-safe).
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
    final scheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 320;
        final paste = _CompactQuickButton(
          icon: LucideIcons.link2,
          title: l10n.homeActionPasteLinkTitle,
          subtitle: l10n.homeActionPasteLinkSubtitle,
          accent: scheme.primary,
          filled: true,
          onTap: onPasteLink,
        );
        final edit = _CompactQuickButton(
          icon: LucideIcons.squarePen,
          title: l10n.homeActionEditVideoTitle,
          subtitle: l10n.homeActionEditVideoSubtitle,
          accent: scheme.tertiary,
          filled: false,
          onTap: onEditVideo,
        );
        final gap = narrow ? 8.0 : 10.0;
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
    );
  }
}

class _CompactQuickButton extends StatelessWidget {
  const _CompactQuickButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final border = scheme.outline.withValues(alpha: dark ? 0.26 : 0.22);
    final bg = filled
        ? Color.alphaBlend(accent.withValues(alpha: dark ? 0.14 : 0.1), scheme.surfaceContainerHighest)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.42 : 0.72);

    final iconColor = filled ? accent : scheme.onSurfaceVariant;
    final titleColor = scheme.onSurface;
    final subColor = scheme.onSurfaceVariant.withValues(alpha: 0.82);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: filled ? accent.withValues(alpha: dark ? 0.35 : 0.42) : border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.15,
                          color: titleColor,
                          fontSize: (theme.textTheme.titleSmall?.fontSize ?? 15) * 0.96,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subColor,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                          fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) * 0.94,
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
