import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:intl/intl.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";
import "package:open_filex/open_filex.dart";
import "package:path/path.dart" as p;
import "package:share_plus/share_plus.dart";

import "../../core/app_scope.dart";
import "../../core/config/media_export_constants.dart";
import "../../core/edit_history/local_edit_history_display.dart";
import "../../core/edit_history/local_edit_history_item.dart";
import "../../core/edit_history/local_edit_history_store.dart";
import "../../core/edit_history/local_edit_history_time_filter.dart";
import "../../core/edit_history/local_edit_history_title.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/media_export_display_path.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../l10n/app_localizations.dart";
import "widgets/edit_history_thumbnail.dart";

/// Local-only edited outputs (metadata under app support; files in app `documents/edits/`).
class HomeEditsTab extends StatefulWidget {
  const HomeEditsTab({
    super.key,
    required this.editHistory,
    required this.onEditVideo,
  });

  final LocalEditHistoryStore editHistory;
  final VoidCallback onEditVideo;

  @override
  State<HomeEditsTab> createState() => _HomeEditsTabState();
}

class _HomeEditsTabState extends State<HomeEditsTab> {
  LocalEditHistoryTimeFilter _filter = LocalEditHistoryTimeFilter.threeDays;
  Future<List<ResolvedEditHistoryRow>>? _resolvedFuture;

  @override
  void initState() {
    super.initState();
    widget.editHistory.addListener(_onHistoryChanged);
    _scheduleResolve();
  }

  @override
  void dispose() {
    widget.editHistory.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (!mounted) return;
    setState(_scheduleResolve);
  }

  void _scheduleResolve() {
    _resolvedFuture = resolveEditHistoryForDisplay(
      items: widget.editHistory.items,
      timeFilter: _filter,
    );
  }

  String _filterLabel(AppLocalizations l10n, LocalEditHistoryTimeFilter f) {
    return switch (f) {
      LocalEditHistoryTimeFilter.today => l10n.editsFilterToday,
      LocalEditHistoryTimeFilter.twoDays => l10n.editsFilterTwoDays,
      LocalEditHistoryTimeFilter.threeDays => l10n.editsFilterThreeDays,
      LocalEditHistoryTimeFilter.week => l10n.editsFilterWeek,
      LocalEditHistoryTimeFilter.twoWeeks => l10n.editsFilterTwoWeeks,
      LocalEditHistoryTimeFilter.month => l10n.editsFilterMonth,
      LocalEditHistoryTimeFilter.unlimited => l10n.editsFilterUnlimited,
    };
  }

  static String _fmtBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return "";
    if (bytes < 1024) return "$bytes B";
    final kb = bytes / 1024;
    if (kb < 1024) return "${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB";
    final mb = kb / 1024;
    return "${mb.toStringAsFixed(mb >= 10 ? 1 : 2)} MB";
  }

  static String? _fmtDurationSec(int? sec) {
    if (sec == null || sec <= 0) return null;
    final m = sec ~/ 60;
    final s = sec % 60;
    return "$m:${s.toString().padLeft(2, "0")}";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom + 20;
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.42 : 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<LocalEditHistoryTimeFilter>(
                  value: _filter,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(14),
                  items: LocalEditHistoryTimeFilter.values
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(_filterLabel(l10n, f)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _filter = v;
                      _scheduleResolve();
                    });
                  },
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await widget.editHistory.hydrate();
              if (mounted) setState(_scheduleResolve);
            },
            child: FutureBuilder<List<ResolvedEditHistoryRow>>(
              future: _resolvedFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: CircularProgressIndicator()),
                    ],
                  );
                }
                final rows = snap.data ?? [];
                if (rows.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(24, 48, 24, bottomPad),
                    children: [
                      Icon(LucideIcons.squarePen, size: 52, color: scheme.primary.withValues(alpha: 0.65)),
                      const SizedBox(height: 18),
                      Text(
                        l10n.editsNoItemsTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.editsNoItemsSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: widget.onEditVideo,
                        icon: Icon(LucideIcons.clapperboard, color: scheme.onPrimary),
                        label: Text(l10n.homeActionEditVideoTitle),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EditHistoryCard(
                        row: row,
                        localeTag: localeTag,
                        editHistory: widget.editHistory,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EditHistoryCard extends StatelessWidget {
  const _EditHistoryCard({
    required this.row,
    required this.localeTag,
    required this.editHistory,
  });

  final ResolvedEditHistoryRow row;
  final String localeTag;
  final LocalEditHistoryStore editHistory;

  String _sourceLabel(AppLocalizations l10n, LocalEditHistoryItem item) {
    switch (item.sourceKind) {
      case "download":
        return l10n.editsFromDownload;
      case "upload":
        return l10n.editsFromDevice;
      default:
        return "";
    }
  }

  Future<void> _confirmDeleteFromApp(BuildContext context) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteEditFromAppTitle),
        content: Text(l10n.deleteEditFromAppBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.homeCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.homeDeleteConfirm),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await editHistory.deleteEditOutputFromApp(row.item.editJobId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = context.lcPalette;
    final item = row.item;
    final exists = row.fileExists;
    final df = DateFormat.yMd(localeTag).add_Hm();
    final displayTitle = resolveEditHistoryDisplayTitle(l10n, item);

    final chips = <Widget>[];
    final src = _sourceLabel(l10n, item);
    if (src.isNotEmpty) {
      chips.add(_chip(theme, scheme, src));
    }
    final sz = _HomeEditsTabState._fmtBytes(row.resolvedSizeBytes ?? item.sizeBytes);
    if (sz.isNotEmpty) chips.add(_chip(theme, scheme, sz));
    final dur = _HomeEditsTabState._fmtDurationSec(item.durationSeconds);
    if (dur != null) chips.add(_chip(theme, scheme, dur));

    final card = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surface,
            Color.alphaBlend(scheme.primary.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.06), scheme.surface),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: exists ? 0.38 : 0.22)),
        boxShadow: Theme.of(context).brightness == Brightness.dark ? const <BoxShadow>[] : palette.cardShadows,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditHistoryThumbnail(
                  item: item,
                  fileExists: exists,
                  editHistory: editHistory,
                  borderRadius: BorderRadius.circular(14),
                  size: 72,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        df.format(item.savedAt),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      if (!exists) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.editsDeletedLocally,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (v) async {
                    if (v == "delete_app") {
                      await _confirmDeleteFromApp(context);
                    } else if (v == "remove_meta") {
                      await editHistory.removeByEditJobId(item.editJobId);
                    }
                  },
                  itemBuilder: (ctx) {
                    if (exists) {
                      return [
                        PopupMenuItem<String>(
                          value: "delete_app",
                          child: Text(l10n.deleteEditFromApp),
                        ),
                      ];
                    }
                    return [
                      PopupMenuItem<String>(
                        value: "remove_meta",
                        child: Text(l10n.removeEditFromList),
                      ),
                    ];
                  },
                  child: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: chips),
            ],
            if (exists) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _open(context, item.localFilePath),
                    icon: Icon(LucideIcons.externalLink, size: 18, color: scheme.primary),
                    label: Text(l10n.editsOpen),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _share(context, item.localFilePath),
                    icon: Icon(LucideIcons.share2, size: 18, color: scheme.primary),
                    label: Text(l10n.editsShare),
                  ),
                  if (Platform.isAndroid && !item.publishedToPublicDownloads)
                    OutlinedButton.icon(
                      onPressed: () => _save(context, item),
                      icon: Icon(LucideIcons.download, size: 18, color: scheme.primary),
                      label: Text(l10n.editsSave),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    return Opacity(opacity: exists ? 1 : 0.72, child: card);
  }

  static Widget _chip(ThemeData theme, ColorScheme scheme, String text) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, String path) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final f = File(path);
    if (!await f.exists()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.editsFileUnavailable)));
      return;
    }
    try {
      final r = await OpenFilex.open(path);
      if (!context.mounted) return;
      if (r.type != ResultType.done) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
      }
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
    }
  }

  Future<void> _share(BuildContext context, String path) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final f = File(path);
    if (!await f.exists()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.editsFileUnavailable)));
      return;
    }
    final name = p.basename(path);
    try {
      final xf = XFile(path, mimeType: "video/mp4", name: name);
      final result = await Share.shareXFiles([xf]);
      if (!context.mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.savedShareFailedHint)));
      }
    } on PlatformException {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedShareFailedHint)));
    }
  }

  Future<void> _save(BuildContext context, LocalEditHistoryItem item) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final scope = AppScope.read(context);
    final path = item.localFilePath.trim();
    final file = File(path);
    if (!await file.exists()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.editsFileUnavailable)));
      return;
    }
    final displayPath = MediaExportDisplayPath.downloadsThenFolder(l10n, kLinkClipMediaStoreFolderName);
    final ok = await scope.files.publishMp4ToAndroidDownloads(
      internalAbsolutePath: path,
      shareDisplayName: p.basename(path),
    );
    if (!context.mounted) return;
    if (ok) {
      await scope.editHistory.markPublishedToPublicDownloads(item.editJobId);
    }
    final still = await file.exists();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok || still ? l10n.editSavedToDownloads(displayPath) : l10n.editSaveFailed),
      ),
    );
  }
}
