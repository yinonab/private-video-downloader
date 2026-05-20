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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _PremiumChip(
      label: display.isEmpty ? "—" : display,
      background:
          scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.75 : 0.88),
      foreground: scheme.onSurfaceVariant.withValues(alpha: dark ? 0.95 : 0.88),
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
        bg = palette.tiktokAccentSoft.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.55);
        fg = palette.tiktokOnAccent.withValues(alpha: 0.95);
        break;
      case DownloadUiStatusLabel.done:
        bg = palette.successMutedBg.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.85 : 0.94);
        fg = palette.successState;
        break;
      case DownloadUiStatusLabel.failed:
      case DownloadUiStatusLabel.canceled:
        bg = palette.dangerMutedBg.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.75 : 0.88);
        fg = scheme.error.withValues(alpha: 0.88);
        break;
      case DownloadUiStatusLabel.unknown:
        bg = scheme.surfaceContainerHighest.withValues(alpha: 0.65);
        fg = scheme.onSurfaceVariant.withValues(alpha: 0.9);
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
      background: palette.tiktokAccentSoft.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.65),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: GoogleFonts.notoSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.12,
            letterSpacing: 0.08,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
