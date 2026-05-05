import "package:flutter/material.dart";

/// Transparent Material bar — pairs with a gradient page behind [Scaffold].
class LinkClipPremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LinkClipPremiumAppBar({
    super.key,
    required this.title,
    this.actions = const [],
  });

  final Widget title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: theme.colorScheme.onSurface,
      centerTitle: true,
      title: DefaultTextStyle.merge(
        style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.35,
            ) ??
            const TextStyle(fontWeight: FontWeight.w700),
        child: title,
      ),
      actions: [
        for (final w in actions) Padding(padding: const EdgeInsetsDirectional.only(end: 2), child: w),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// Pill-shaped toolbar control with soft surface / border (Lucide icons typically inside).
class LinkClipToolbarIconButton extends StatelessWidget {
  const LinkClipToolbarIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface.withValues(alpha: dark ? 0.55 : 0.94),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outline.withValues(alpha: dark ? 0.45 : 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 21, color: scheme.onSurface),
          ),
        ),
      ),
    );
  }
}
