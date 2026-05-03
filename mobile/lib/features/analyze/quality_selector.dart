import "package:flutter/material.dart";

import "../../core/models/analyze_models.dart";

/// Visual choice list for yt-dlp format presets returned by [/analyze].
class QualitySelector extends StatelessWidget {
  const QualitySelector({
    super.key,
    required this.formats,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<FormatOption> formats;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "בחר איכות",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...List.generate(formats.length, (i) {
          final f = formats[i];
          final selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected ? scheme.primaryContainer.withOpacity(0.85) : scheme.surfaceContainerHighest.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(f.label.isEmpty ? f.value : f.label, style: Theme.of(context).textTheme.titleSmall)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
