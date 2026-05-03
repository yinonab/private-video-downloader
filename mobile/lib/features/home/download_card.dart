import "package:flutter/material.dart";
import "package:intl/intl.dart";

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
    final scheme = Theme.of(context).colorScheme;
    final st = item.statusParsed;
    final dateStr = DateFormat.yMMMd("he_IL").add_Hm().format(item.createdAt.toLocal());
    final sizeStr = item.file != null ? _fmtBytes(item.file!.sizeBytes) : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenStatus,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(item.platform, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Chip(
                            label: Text(st.hebrew),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          if (sizeStr != null) ...[
                            const SizedBox(width: 8),
                            Text(sizeStr, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline)),
                          ],
                        ],
                      ),
                      if (item.active) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: (item.progress.clamp(0, 100)) / 100.0),
                        const SizedBox(height: 6),
                        Text("${item.progress.clamp(0, 100)}%", style: Theme.of(context).textTheme.labelMedium),
                      ],
                      const SizedBox(height: 6),
                      Text(dateStr, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: "",
                  icon: const Icon(Icons.more_vert),
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
                    const PopupMenuItem(value: "status", child: Text("פירוט הסטטוס")),
                    if ((item.status == "failed" || item.status == "canceled") && onRetry != null)
                      const PopupMenuItem(value: "retry", child: Text("נסה שוב")),
                    const PopupMenuItem(value: "del", child: Text("מחק")),
                    if (item.statusParsed.label == DownloadUiStatusLabel.done && localFileExists && onOpenLocal != null)
                      const PopupMenuItem(value: "open", child: Text("פתח")),
                    if (item.statusParsed.label == DownloadUiStatusLabel.done && localFileExists && onShareLocal != null)
                      const PopupMenuItem(value: "share", child: Text("שתף")),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    final thumb = item.thumbnail;
    const w = 88.0;
    const h = 66.0;
    if (thumb != null && thumb.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
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
    const w = 88.0;
    const h = 66.0;
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
      child: Icon(loading ? Icons.hourglass_bottom : Icons.ondemand_video_rounded),
    );
  }
}