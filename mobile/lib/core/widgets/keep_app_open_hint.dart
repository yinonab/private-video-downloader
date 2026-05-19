import "package:flutter/material.dart";

/// Subtle copy while long-running **foreground** work is visible (no background services implied).
class KeepAppOpenHint extends StatelessWidget {
  const KeepAppOpenHint(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
          height: 1.38,
        ),
      ),
    );
  }
}
