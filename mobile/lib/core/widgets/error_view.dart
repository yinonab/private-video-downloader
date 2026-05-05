import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "app_button.dart";

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.title, required this.retryLabel, required this.onRetry});

  final String title;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.triangleAlert, color: scheme.error, size: 44),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.error),
          ),
          const SizedBox(height: 18),
          AppPrimaryButton(label: retryLabel, onPressed: onRetry),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 240.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 260.ms, curve: Curves.easeOut);
  }
}
