import "package:flutter/material.dart";
import "package:intl/intl.dart" hide TextDirection;
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/download_job_ui_state.dart";
import "../../core/models/download_models.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/widgets/branded_progress.dart";
import "../../core/widgets/linkclip_network_thumbnail.dart";
import "../../core/widgets/linkclip_chips.dart";

class DownloadCard extends StatelessWidget {
  const DownloadCard({
    super.key,
    required this.item,
    required this.onOpenStatus,
    required this.onRetry,
    required this.onDelete,
    required this.onOpenLocal,
    required this.onShareLocal,
    required this.localFileExists,
    this.showQuickEdit = false,
    this.onQuickEdit,
  });

  final DownloadItem item;
  final VoidCallback onOpenStatus;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;
  final VoidCallback? onOpenLocal;
  final VoidCallback? onShareLocal;
  final bool localFileExists;

  /// When true and [onQuickEdit] is set, offers Quick Edit for finished jobs (no local file required).
  final bool showQuickEdit;
  final VoidCallback? onQuickEdit;

  static String? _fmtBytes(int? b) {
    if (b == null || b <= 0) return null;
    const u = ["B", "KB", "MB", "GB"];
    var v = b.toDouble();
    var i = 0;
    while (v >= 1024 && i < u.length - 1) {
      v /= 1024;
      i++;
    }
    final s = i == 0 ? v.toInt().toString() : v.toStringAsFixed(v >= 10 ? 0 : 1);
    return "$s ${u[i]}";
  }

  static const double _thumbW = 132;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.lcPalette;
    final dark = theme.brightness == Brightness.dark;
    final locTag = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.yMMMd(locTag).add_Hm().format(item.createdAt.toLocal());
    final sizeStr = item.file != null ? _fmtBytes(item.file!.sizeBytes) : null;
    final titleLine = item.title.isEmpty ? l10n.untitledVideo : item.title;
    final platformLine = item.platform.isEmpty ? l10n.unknownPlatform : item.platform;
    final ui = mapDownloadJobUi(
      l10n,
      jobId: item.id,
      status: item.status,
      processingStage: item.processingStage,
      progressPercent: item.progressPercent,
      requestedFormat: item.requestedFormat,
      compactProgressCard: true,
    );
    final statusLabel = ui.statusChipLabel;
    final done = item.statusParsed.label == DownloadUiStatusLabel.done;
    final failedOrCanceled = item.status == "failed" || item.status == "canceled";

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: dark ? const <BoxShadow>[] : palette.cardShadows,
      ),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: scheme.outline.withValues(alpha: dark ? 0.55 : 0.42)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onOpenStatus,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _thumb(context),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                              height: 1.25,
                              letterSpacing: -0.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              LinkClipPlatformChip(label: platformLine),
                              LinkClipStatusChip(label: statusLabel, semantic: item.statusParsed.label),
                              if (done &&
                                  (item.requestedFormat ?? "").trim().toLowerCase() == "tiktok_ready")
                                LinkClipTikTokChip(label: l10n.downloadChipTikTokReady),
                            ],
                          ),
                          if (item.active) ...[
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final pct = ui.determinatePercent ?? 0;
                                return BrandedProgressBar(
                                  dense: true,
                                  indeterminate: ui.showIndeterminateProgress,
                                  value: ui.showDeterminateProgress ? pct / 100.0 : null,
                                  percentLabel: ui.showDeterminateProgress ? l10n.progressPercent(pct) : null,
                                  stageLabel: ui.progressStageTitle,
                                  stageSubtitle: ui.progressStageSubtitle,
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          Text(
                            [
                              if (sizeStr != null) sizeStr,
                              dateStr,
                            ].join(" · "),
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: "",
                      icon: Icon(LucideIcons.ellipsisVertical, color: scheme.onSurfaceVariant),
                      onSelected: (k) {
                        if (k == "status") {
                          onOpenStatus();
                        } else if (k == "retry") {
                          onRetry?.call();
                        } else if (k == "del") {
                          onDelete();
                        } else if (k == "open") {
                          onOpenLocal?.call();
                        } else if (k == "share") {
                          onShareLocal?.call();
                        } else if (k == "edit") {
                          onQuickEdit?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(value: "status", child: Text(l10n.downloadCardStatusDetails)),
                        if (failedOrCanceled && onRetry != null)
                          PopupMenuItem(value: "retry", child: Text(l10n.downloadCardRetry)),
                        PopupMenuItem(value: "del", child: Text(l10n.downloadCardDelete)),
                        if (done && showQuickEdit && onQuickEdit != null)
                          PopupMenuItem(value: "edit", child: Text(l10n.downloadCardEdit)),
                        if (done && localFileExists && onOpenLocal != null)
                          PopupMenuItem(value: "open", child: Text(l10n.downloadOpen)),
                        if (done && localFileExists && onShareLocal != null)
                          PopupMenuItem(value: "share", child: Text(l10n.downloadShare)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (done && !localFileExists)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showQuickEdit && onQuickEdit != null) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: onQuickEdit,
                        icon: Icon(LucideIcons.scissors, color: scheme.primary),
                        label: Text(l10n.downloadCardEdit),
                      ),
                      const SizedBox(height: 10),
                    ],
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: onOpenStatus,
                      icon: Icon(LucideIcons.smartphone, color: scheme.onPrimary),
                      label: Text(l10n.downloadSaveToDevice),
                    ),
                  ],
                ),
              ),
            if (done && localFileExists && onOpenLocal != null && onShareLocal != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _InlinePremiumAction(
                        icon: LucideIcons.externalLink,
                        label: l10n.downloadOpen,
                        onTap: onOpenLocal!,
                        dense: showQuickEdit && onQuickEdit != null,
                      ),
                    ),
                    SizedBox(width: showQuickEdit && onQuickEdit != null ? 8 : 10),
                    Expanded(
                      child: _InlinePremiumAction(
                        icon: LucideIcons.share2,
                        label: l10n.downloadShare,
                        onTap: onShareLocal!,
                        dense: showQuickEdit && onQuickEdit != null,
                      ),
                    ),
                    if (showQuickEdit && onQuickEdit != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _InlinePremiumAction(
                          icon: LucideIcons.scissors,
                          label: l10n.downloadCardEdit,
                          onTap: onQuickEdit!,
                          dense: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    final thumb = item.thumbnail;
    if (thumb != null && thumb.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: _thumbW,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LinkClipNetworkThumbnail(
              imageUrl: thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _ph(context),
              loadingBuilder: (context, child, prog) => prog == null ? child : _ph(context, loading: true),
            ),
          ),
        ),
      );
    }
    return _ph(context);
  }

  Widget _ph(BuildContext context, {bool loading = false}) {
    final scheme = Theme.of(context).colorScheme;
    final icon = loading ? _LucideSpinner(iconData: LucideIcons.loader, color: scheme.primary) : Icon(LucideIcons.video, color: scheme.onSurfaceVariant);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: _thumbW,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class _InlinePremiumAction extends StatelessWidget {
  const _InlinePremiumAction({
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
    return Material(
      color: scheme.primaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dense ? 10 : 12, horizontal: dense ? 5 : 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: dense ? 16 : 18, color: scheme.primary),
              SizedBox(width: dense ? 5 : 8),
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: dense ? 12.5 : null,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LucideSpinner extends StatefulWidget {
  const _LucideSpinner({required this.iconData, required this.color});

  final IconData iconData;
  final Color color;

  @override
  State<_LucideSpinner> createState() => _LucideSpinnerState();
}

class _LucideSpinnerState extends State<_LucideSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _rot =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 880))..repeat();

  @override
  void dispose() {
    _rot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rot,
      child: Icon(widget.iconData, color: widget.color),
    );
  }
}
