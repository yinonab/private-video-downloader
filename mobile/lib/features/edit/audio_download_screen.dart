import "dart:async";

import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/app_scope.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/download_models.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/linkclip_app_bar.dart";
import "../../services/saved_media_actions.dart";

/// Audio-only download actions — video Quick Edit is not available (V3.4I).
class AudioDownloadScreen extends StatefulWidget {
  const AudioDownloadScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<AudioDownloadScreen> createState() => _AudioDownloadScreenState();
}

class _AudioDownloadScreenState extends State<AudioDownloadScreen> {
  DownloadDetailResponse? _detail;
  String? _localPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.read(context);
    final detail = await scope.api.downloadDetail(widget.jobId);
    final path = await scope.session.localPathForJob(widget.jobId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _localPath = path;
    });
  }

  Future<void> _openLocal() async {
    setState(() => _busy = true);
    try {
      await openSavedDownload(
        context: context,
        session: AppScope.read(context).session,
        jobId: widget.jobId,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareLocal() async {
    setState(() => _busy = true);
    try {
      await shareSavedDownload(
        context: context,
        session: AppScope.read(context).session,
        jobId: widget.jobId,
        title: _detail?.title,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasFile = _localPath != null && _localPath!.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            scheme.surfaceContainerLow.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LinkClipPremiumAppBar(title: Text(l10n.editAudioScreenTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.audioLines,
                        size: 48,
                        color: scheme.primary.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.editAudioFileExplanation,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          color: scheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.editAudioVideoEditsUnavailable,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.editAudioAvailableActions,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (hasFile) ...[
                AppOutlinedButton(
                  label: l10n.downloadOpen,
                  icon: Icon(LucideIcons.externalLink, color: scheme.primary),
                  onPressed: () {
                    if (_busy) return;
                    unawaited(_openLocal());
                  },
                ),
                const SizedBox(height: 10),
                AppOutlinedButton(
                  label: l10n.downloadShare,
                  icon: Icon(LucideIcons.share2, color: scheme.primary),
                  onPressed: () {
                    if (_busy) return;
                    unawaited(_shareLocal());
                  },
                ),
              ] else
                Text(
                  l10n.editAudioSaveFileFirst,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.editAudioLimitationsNote,
                          style: theme.textTheme.labelSmall?.copyWith(
                            height: 1.35,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
