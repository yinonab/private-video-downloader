import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../models/download_models.dart";
import "../theme/linkclip_palette.dart";

/// Compact platform pill — lowercase label for calm hierarchy.
class LinkClipPlatformChip extends StatelessWidget {
  const LinkClipPlatformChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = label.trim().toLowerCase();
    return _PremiumChip(
      label: display.isEmpty ? "—" : display,
      background: scheme.primaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.42 : 0.72),
      foreground: scheme.onPrimaryContainer,
    );
  }
}

class LinkClipStatusChip extends StatelessWidget {
  const LinkClipStatusChip({super.key, required this.label, required this.semantic});

  final String label;
  final DownloadUiStatusLabel semantic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.lcPalette;

    late Color bg;
    late Color fg;
    switch (semantic) {
      case DownloadUiStatusLabel.running:
      case DownloadUiStatusLabel.queued:
        bg = scheme.primaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.85);
        fg = scheme.onPrimaryContainer;
        break;
      case DownloadUiStatusLabel.done:
        bg = palette.successState.withValues(alpha: 0.14);
        fg = palette.successState;
        break;
      case DownloadUiStatusLabel.failed:
      case DownloadUiStatusLabel.canceled:
        bg = scheme.error.withValues(alpha: 0.12);
        fg = scheme.error;
        break;
      case DownloadUiStatusLabel.unknown:
        bg = scheme.surfaceContainerHighest.withValues(alpha: 0.9);
        fg = scheme.onSurfaceVariant;
        break;
    }

    return _PremiumChip(label: label, background: bg, foreground: fg);
  }
}

class LinkClipTikTokChip extends StatelessWidget {
  const LinkClipTikTokChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.lcPalette;
    return _PremiumChip(
      label: label,
      background: palette.tiktokAccentSoft.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.55 : 0.9),
      foreground: palette.tiktokOnAccent,
    );
  }
}

class _PremiumChip extends StatelessWidget {
  const _PremiumChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.notoSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.15,
          color: foreground,
        ),
      ),
    );
  }
}
