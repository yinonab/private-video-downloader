import "package:flutter/material.dart";

/// Rounded determinate or indeterminate progress track + percentage column.
class BrandedProgressBar extends StatelessWidget {
  const BrandedProgressBar({
    super.key,
    this.value,
    this.percentLabel,
    this.stageLabel,
    this.bytesSubtitle,
    this.indeterminate = false,
    this.dense = false,
  });

  /// 0–1 when determinate; ignored when [indeterminate] is true.
  final double? value;

  /// e.g. `"42%"` from [AppLocalizations.downloadPercentValue]. Omit when indeterminate.
  final String? percentLabel;

  final String? stageLabel;

  final String? bytesSubtitle;

  final bool indeterminate;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final barHeight = dense ? 8.0 : 10.0;
    final percentStyle =
        dense ? theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800) : theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stageLabel != null && stageLabel!.isNotEmpty) ...[
          Text(
            stageLabel!,
            style: dense
                ? theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)
                : theme.textTheme.titleSmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: dense ? 6 : 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: indeterminate
                    ? LinearProgressIndicator(
                        minHeight: barHeight,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: scheme.primary,
                      )
                    : LinearProgressIndicator(
                        value: (value ?? 0).clamp(0.0, 1.0),
                        minHeight: barHeight,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: scheme.primary,
                      ),
              ),
            ),
            if (percentLabel != null && percentLabel!.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(percentLabel!, style: percentStyle?.copyWith(color: scheme.onSurface)),
            ],
          ],
        ),
        if (bytesSubtitle != null && bytesSubtitle!.isNotEmpty) ...[
          SizedBox(height: dense ? 4 : 6),
          Text(
            bytesSubtitle!,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
