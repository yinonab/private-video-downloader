import "package:flutter/material.dart";
import "package:intl/intl.dart" hide TextDirection;

import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/download_status_localizations.dart";
import "../../core/models/download_models.dart";

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
  });

  final DownloadItem item;
  final VoidCallback onOpenStatus;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;
  final VoidCallback? onOpenLocal;
  final VoidCallback? onShareLocal;
  final bool localFileExists;

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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locTag = Localizations.localeOf(context).toString();
    final dateStr = DateFormat.yMMMd(locTag).add_Hm().format(item.createdAt.toLocal());
    final sizeStr = item.file != null ? _fmtBytes(item.file!.sizeBytes) : null;
    final titleLine = item.title.isEmpty ? l10n.untitledVideo : item.title;
    final platformLine = item.platform.isEmpty ? l10n.unknownPlatform : item.platform;
    final statusLabel = localizedDownloadJobStatus(l10n, item.status);
    final done = item.statusParsed.label == DownloadUiStatusLabel.done;
    final failedOrCanceled = item.status == "failed" || item.status == "canceled";

    return Material(
      color: scheme.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpenStatus,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
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
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              label: Text(platformLine),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              labelStyle: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              backgroundColor: scheme.primaryContainer.withValues(alpha: 0.45),
                              side: BorderSide.none,
                            ),
                            Chip(
                              label: Text(statusLabel),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              labelStyle: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                              backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                              side: BorderSide.none,
                            ),
                          ],
                        ),
                        if (item.active) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              minHeight: 6,
                              value: (item.progress.clamp(0, 100)) / 100.0,
                              backgroundColor: scheme.surfaceContainerHighest,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${item.progress.clamp(0, 100)}%",
                            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 8),
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
                    icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
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
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: "status", child: Text(l10n.downloadCardStatusDetails)),
                      if (failedOrCanceled && onRetry != null)
                        PopupMenuItem(value: "retry", child: Text(l10n.downloadCardRetry)),
                      PopupMenuItem(value: "del", child: Text(l10n.downloadCardDelete)),
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
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: FilledButton.icon(
                onPressed: onOpenStatus,
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(l10n.downloadSaveToDevice),
              ),
            ),
          if (done && localFileExists && onOpenLocal != null && onShareLocal != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onOpenLocal,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(l10n.downloadOpen),
                  ),
                  TextButton.icon(
                    onPressed: onShareLocal,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: Text(l10n.downloadShare),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    final thumb = item.thumbnail;
    const w = 104.0;
    const h = 78.0;
    if (thumb != null && thumb.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          thumb,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _ph(context),
          loadingBuilder: (context, child, prog) => prog == null ? child : _ph(context, loading: true),
        ),
      );
    }
    return _ph(context);
  }

  Widget _ph(BuildContext context, {bool loading = false}) {
    const w = 104.0;
    const h = 78.0;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        loading ? Icons.hourglass_bottom_rounded : Icons.movie_filter_rounded,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
