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

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 320;
        final paste = _CompactQuickTile(
          icon: LucideIcons.link2,
          title: l10n.homeActionPasteLinkTitle,
          subtitle: l10n.homeActionPasteLinkSubtitle,
          emphasize: true,
          onTap: onPasteLink,
        );
        final edit = _CompactQuickTile(
          icon: LucideIcons.squarePen,
          title: l10n.homeActionEditVideoTitle,
          subtitle: l10n.homeActionEditVideoSubtitle,
          emphasize: false,
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

class _CompactQuickTile extends StatelessWidget {
  const _CompactQuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.emphasize,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool emphasize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    final accent = emphasize ? scheme.primary : scheme.onSurfaceVariant;
    final bg = emphasize
        ? scheme.primary.withValues(alpha: dark ? 0.1 : 0.08)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.42 : 0.55);

    final borderColor = emphasize
        ? scheme.primary.withValues(alpha: dark ? 0.24 : 0.22)
        : scheme.outline.withValues(alpha: dark ? 0.32 : 0.35);

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
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: accent.withValues(alpha: emphasize ? (dark ? 0.92 : 0.88) : 0.75)),
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
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.15,
                          height: 1.12,
                          color: scheme.onSurface.withValues(alpha: 0.95),
                          fontSize: (theme.textTheme.titleSmall?.fontSize ?? 15) * 0.95,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          height: 1.12,
                          fontWeight: FontWeight.w400,
                          fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12) * 0.95,
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
