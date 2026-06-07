import "package:flutter/material.dart";

class EditDoneExportChip extends StatelessWidget {
  const EditDoneExportChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.42 : 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: dense ? 9 : 11,
            horizontal: dense ? 4 : 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: dense ? 17 : 19, color: scheme.onSurface.withValues(alpha: 0.82)),
              SizedBox(height: dense ? 5 : 7),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                      height: 1.05,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
