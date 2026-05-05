import "package:flutter/material.dart";

import "../theme/linkclip_palette.dart";
import "branded_loading.dart";

/// Primary hero-style CTA with a subtle premium gradient (home empty state).
class PremiumGradientCta extends StatelessWidget {
  const PremiumGradientCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.lcPalette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final gradients = dark
        ? const [Color(0xFF8B84FF), Color(0xFF6C63FF)]
        : const [Color(0xFF6C63FF), Color(0xFF4F46E5)];

    final shadows = dark ? const <BoxShadow>[] : palette.cardShadows;

    final child = loading
        ? SizedBox(
            height: 26,
            width: 26,
            child: BrandedLoadingMark(size: 22, iconColor: Colors.white.withValues(alpha: 0.95)),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: const IconThemeData(size: 22, color: Colors.white),
                    child: icon!,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ],
              )
            : Text(label, style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700, fontSize: 16));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradients, begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            height: 26,
            width: 26,
            child: BrandedLoadingMark(size: 22, iconColor: Theme.of(context).colorScheme.onPrimary),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme.merge(
                    data: const IconThemeData(size: 22),
                    child: icon!,
                  ),
                  const SizedBox(width: 10),
                  Flexible(child: Text(label)),
                ],
              )
            : Text(label);

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: child,
      ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.72),
          foregroundColor: scheme.onPrimaryContainer,
          elevation: 0,
        ),
        child: icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(size: 22, color: scheme.onPrimaryContainer),
                    child: icon!,
                  ),
                  const SizedBox(width: 10),
                  Flexible(child: Text(label)),
                ],
              )
            : Text(label),
      ),
    );
  }
}

class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        child: icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme.merge(
                    data: const IconThemeData(size: 22),
                    child: icon!,
                  ),
                  const SizedBox(width: 10),
                  Flexible(child: Text(label)),
                ],
              )
            : Text(label),
      ),
    );
  }
}
