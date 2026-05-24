import "package:flutter/material.dart";

import "../../../l10n/app_localizations.dart";

/// Quick Edit — **Captions V1**: auto transcription + burned-in subtitles (server-side).
class CaptionsEditorPanel extends StatelessWidget {
  const CaptionsEditorPanel({
    super.key,
    required this.autoCaptionsEnabled,
    required this.onAutoCaptionsChanged,
  });

  final bool autoCaptionsEnabled;
  final ValueChanged<bool> onAutoCaptionsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.editCaptionsSectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.editCaptionsSectionSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.42 : 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outline.withValues(alpha: 0.22),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              title: Text(
                l10n.editCaptionsAutoToggle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Theme(
                data: theme.copyWith(
                  switchTheme: SwitchThemeData(
                    thumbColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.onPrimary;
                      }
                      return scheme.outline;
                    }),
                    trackColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.primary.withValues(alpha: 0.42);
                      }
                      return scheme.surfaceContainerHighest;
                    }),
                  ),
                ),
                child: Switch.adaptive(
                  value: autoCaptionsEnabled,
                  onChanged: onAutoCaptionsChanged,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.editCaptionsBurnInHelper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
              height: 1.38,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.editCaptionsMayTakeLongerNote,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
