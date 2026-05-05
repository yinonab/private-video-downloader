import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../theme/linkclip_palette.dart";

/// Small bouncing downward arrow — LinkClip-branded motion for loaders.
class BrandedLoadingMark extends StatefulWidget {
  const BrandedLoadingMark({super.key, this.size = 40, this.iconColor});

  final double size;
  final Color? iconColor;

  @override
  State<BrandedLoadingMark> createState() => _BrandedLoadingMarkState();
}

class _BrandedLoadingMarkState extends State<BrandedLoadingMark> with SingleTickerProviderStateMixin {
  late final AnimationController _bob;

  @override
  void initState() {
    super.initState();
    _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.iconColor ?? scheme.primary;
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, child) {
        final y = -4.0 + 10.0 * Curves.easeInOut.transform(_bob.value);
        return Transform.translate(offset: Offset(0, y), child: child);
      },
      child: Icon(LucideIcons.arrowDown, size: widget.size, color: color),
    );
  }
}

/// Full-panel branded loader with optional caption (replaces generic spinners).
class BrandedLoadingPanel extends StatelessWidget {
  const BrandedLoadingPanel({super.key, this.message, this.compact = false});

  final String? message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bubble = context.lcPalette.loaderBubble;
    final circlePad = compact ? 18.0 : 22.0;
    final iconSize = compact ? 32.0 : 44.0;

    Widget panel = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(circlePad),
          decoration: BoxDecoration(
            color: Color.alphaBlend(bubble.withValues(alpha: 0.92), scheme.surface),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.12),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: BrandedLoadingMark(size: iconSize),
        ),
        if (message != null && message!.isNotEmpty) ...[
          SizedBox(height: compact ? 14 : 18),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: panel,
      ),
    );
  }
}
