import "package:flutter/material.dart";

import "linkclip_palette.dart";

/// Practical LinkClip spacing / radius / type tokens for spacious UI cleanup.
abstract final class LcSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class LcRadius {
  static const double small = 10;
  static const double medium = 16;
  static const double large = 22;
  static const double card = 24;
}

/// Soft section card used across edit / captions panels.
class LinkClipSectionCard extends StatelessWidget {
  const LinkClipSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final palette = context.lcPalette;

    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: dark ? 0.88 : 0.98),
          borderRadius: BorderRadius.circular(LcRadius.card),
          border: Border.all(
            color: scheme.outline.withValues(alpha: dark ? 0.42 : 0.28),
          ),
          boxShadow: dark ? const <BoxShadow>[] : palette.cardShadows,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Section title + optional short help line.
class LinkClipSectionHeader extends StatelessWidget {
  const LinkClipSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: LcSpace.sm),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Large, equal-feel choice chip for format / speed / rotation.
class LinkClipChoiceChip extends StatelessWidget {
  const LinkClipChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.expanded = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final borderColor = selected
        ? scheme.primary.withValues(alpha: dark ? 0.55 : 0.7)
        : scheme.outline.withValues(alpha: 0.3);
    final bg = selected
        ? scheme.primary.withValues(alpha: dark ? 0.16 : 0.1)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.4 : 0.55);

    final child = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LcRadius.medium),
        side: BorderSide(color: borderColor, width: selected ? 1.4 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? LcSpace.md : LcSpace.lg,
            vertical: LcSpace.md,
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.95)
                      : scheme.onSurface.withValues(alpha: 0.55),
                ),
                const SizedBox(width: LcSpace.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? scheme.primary.withValues(alpha: 0.98)
                        : scheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return expanded ? child : child;
  }
}

/// Soft sticky bottom bar for primary + optional secondary actions.
class LinkClipStickyActionBar extends StatelessWidget {
  const LinkClipStickyActionBar({
    super.key,
    required this.primary,
    this.secondary,
  });

  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.surface.withValues(alpha: dark ? 0.94 : 0.98),
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: scheme.outline.withValues(alpha: 0.22)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              LcSpace.lg,
              LcSpace.md,
              LcSpace.lg,
              LcSpace.md,
            ),
            child: secondary == null
                ? primary
                : Row(
                    children: [
                      Expanded(child: secondary!),
                      const SizedBox(width: LcSpace.md),
                      Expanded(flex: 2, child: primary),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Compact empty-state block for panel interiors (captions / lists).
class LinkClipInlineEmptyState extends StatelessWidget {
  const LinkClipInlineEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LinkClipSectionCard(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(LcRadius.large),
              ),
              child: Padding(
                padding: const EdgeInsets.all(LcSpace.lg),
                child: Icon(icon, size: 36, color: scheme.primary),
              ),
            ),
          ),
          const SizedBox(height: LcSpace.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: LcSpace.sm),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: LcSpace.xl),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Dominant media/thumbnail stage for analyze / status / result screens.
class LinkClipMediaPreviewCard extends StatelessWidget {
  const LinkClipMediaPreviewCard({
    super.key,
    required this.height,
    required this.child,
  });

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LcRadius.large),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LcRadius.large),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: ColoredBox(
            color: Colors.black,
            child: SizedBox.expand(child: child),
          ),
        ),
      ),
    );
  }
}
