import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../l10n/context_l10n.dart";

/// Collapses long caption/description behind a premium-styled toggle (RTL-safe).
class ExpandableDescription extends StatefulWidget {
  const ExpandableDescription({super.key, required this.text});

  final String text;

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final body = widget.text.trim();
    if (body.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            foregroundColor: scheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 4),
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            size: 18,
          ),
          label: Text(
            _expanded ? l10n.hideDescription : l10n.openDescription,
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SelectableText(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
