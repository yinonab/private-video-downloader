import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "edit_done_export_chip.dart";

class EditDoneBody extends StatelessWidget {
  const EditDoneBody({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onOpen,
    required this.onShare,
    required this.onSave,
    required this.openLabel,
    required this.shareLabel,
    required this.saveLabel,
    required this.doneLabel,
    this.successIcon = LucideIcons.circleCheck,
  });

  final String title;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final String openLabel;
  final String shareLabel;
  final String saveLabel;
  final String doneLabel;
  final IconData successIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(successIcon, size: 56, color: scheme.primary.withValues(alpha: 0.88)),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: EditDoneExportChip(
                  icon: LucideIcons.externalLink,
                  label: openLabel,
                  onTap: onOpen,
                  dense: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EditDoneExportChip(
                  icon: LucideIcons.share2,
                  label: shareLabel,
                  onTap: onShare,
                  dense: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EditDoneExportChip(
                  icon: LucideIcons.download,
                  label: saveLabel,
                  onTap: onSave,
                  dense: true,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: scheme.primary.withValues(alpha: 0.88),
              foregroundColor: scheme.onPrimary,
            ),
            child: Text(doneLabel),
          ),
        ],
      ),
    );
  }
}
