import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:flutter_slidable/flutter_slidable.dart";
import "package:intl/intl.dart" hide TextDirection;
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/download_job_ui_state.dart";
import "../../core/models/download_models.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/widgets/branded_progress.dart";
import "../../core/widgets/linkclip_chips.dart";
import "../../core/widgets/linkclip_network_thumbnail.dart";
import "../../l10n/app_localizations.dart";

/// Compact download row: one primary action; overflow menu, long-press sheet, and swipe shortcuts.
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
    this.listAnimationIndex,
  });

  final DownloadItem item;
  final VoidCallback onOpenStatus;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;
  final VoidCallback? onOpenLocal;
  final VoidCallback? onShareLocal;
  final bool localFileExists;

  /// When true and [onQuickEdit] is set, offers Quick Edit for finished jobs (menu / gestures).
  final bool showQuickEdit;
  final VoidCallback? onQuickEdit;

  /// When non-null and small, card fades/slides in subtly (list performance cap).
  final int? listAnimationIndex;

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

  static const double _thumbW = 102;

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
    final isTikTokJob = (item.requestedFormat ?? "").trim().toLowerCase() == "tiktok_ready";

    final primary = _primaryAction(
      l10n,
      done: done,
      failedOrCanceled: failedOrCanceled,
      onRetry: onRetry,
      onOpenStatus: onOpenStatus,
      onOpenLocal: onOpenLocal,
      localFileExists: localFileExists,
    );

    final cardFace = Material(
      color: scheme.surface.withValues(alpha: dark ? 0.92 : 1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outline.withValues(alpha: dark ? 0.28 : 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ThumbnailTap(
                  localFileExists: localFileExists,
                  onOpenLocal: onOpenLocal,
                  onFallback: onOpenStatus,
                  child: _thumb(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onOpenStatus();
                      },
                      onLongPress: () {
                        HapticFeedback.selectionClick();
                        _showActionsSheet(
                          context,
                          entries: _sheetEntries(
                            l10n: l10n,
                            failedOrCanceled: failedOrCanceled,
                            done: done,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      splashColor: scheme.primary.withValues(alpha: 0.07),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
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
                                height: 1.2,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    platformLine.toLowerCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                LinkClipStatusChip(label: statusLabel, semantic: item.statusParsed.label),
                              ],
                            ),
                            if (done && isTikTokJob) ...[
                              const SizedBox(height: 6),
                              Text(
                                l10n.downloadChipTikTokReady,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: palette.tiktokOnAccent.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w600,
                                  fontSize: (theme.textTheme.labelSmall?.fontSize ?? 11) * 0.95,
                                ),
                              ),
                            ],
                            if (item.active) ...[
                              const SizedBox(height: 10),
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
                            const SizedBox(height: 8),
                            Text(
                              [
                                if (sizeStr != null) sizeStr,
                                dateStr,
                              ].join(" · "),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onOpened: () => HapticFeedback.selectionClick(),
                  icon: Icon(LucideIcons.ellipsisVertical, color: scheme.onSurfaceVariant, size: 22),
                  onSelected: (k) {
                    HapticFeedback.lightImpact();
                    _handleMenuKey(
                      k,
                      onOpenStatus: onOpenStatus,
                      onRetry: onRetry,
                      onDelete: onDelete,
                      onOpenLocal: onOpenLocal,
                      onShareLocal: onShareLocal,
                      onQuickEdit: onQuickEdit,
                    );
                  },
                  itemBuilder: (ctx) => _popupEntries(
                    l10n: l10n,
                    scheme: scheme,
                    failedOrCanceled: failedOrCanceled,
                    done: done,
                  ),
                ),
              ],
            ),
          ),
          if (primary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _PrimaryCta(
                label: primary.label,
                icon: primary.icon,
                onTap: primary.onTap,
              ),
            ),
        ],
      ),
    );

    final actions = _slidableActions(
      context,
      l10n: l10n,
      scheme: scheme,
      failedOrCanceled: failedOrCanceled,
      done: done,
    );

    Widget slidableChild = Slidable(
      key: ValueKey<String>("slidable-${item.id}"),
      groupTag: "home-downloads",
      closeOnScroll: true,
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: math.min(0.52, 0.26 + actions.length * 0.11),
        children: actions,
      ),
      child: cardFace,
    );

    if (listAnimationIndex != null && listAnimationIndex! < 16) {
      final i = listAnimationIndex!;
      slidableChild = slidableChild
          .animate(delay: (i * 20).ms)
          .fadeIn(duration: 210.ms, curve: Curves.easeOut)
          .slideY(begin: 0.03, duration: 240.ms, curve: Curves.easeOutCubic);
    }

    return slidableChild;
  }

  ({String label, IconData icon, VoidCallback onTap})? _primaryAction(
    AppLocalizations l10n, {
    required bool done,
    required bool failedOrCanceled,
    required VoidCallback? onRetry,
    required VoidCallback onOpenStatus,
    required VoidCallback? onOpenLocal,
    required bool localFileExists,
  }) {
    if (failedOrCanceled && onRetry != null) {
      return (
        label: l10n.downloadCardRetry,
        icon: LucideIcons.rotateCw,
        onTap: onRetry,
      );
    }
    if (done && !localFileExists) {
      return (
        label: l10n.downloadSaveToDevice,
        icon: LucideIcons.smartphone,
        onTap: onOpenStatus,
      );
    }
    if (done && localFileExists && onOpenLocal != null) {
      return (
        label: l10n.downloadOpen,
        icon: LucideIcons.externalLink,
        onTap: onOpenLocal,
      );
    }
    return null;
  }

  List<PopupMenuEntry<String>> _popupEntries({
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required bool failedOrCanceled,
    required bool done,
  }) {
    final out = <PopupMenuEntry<String>>[
      PopupMenuItem(value: "status", child: Text(l10n.downloadCardStatusDetails)),
      if (done && !localFileExists)
        PopupMenuItem(value: "save", child: Text(l10n.downloadSaveToDevice)),
      if (done && localFileExists && onOpenLocal != null)
        PopupMenuItem(value: "open", child: Text(l10n.downloadOpen)),
      if (done && localFileExists && onShareLocal != null)
        PopupMenuItem(value: "share", child: Text(l10n.downloadShare)),
      if (done && showQuickEdit && onQuickEdit != null)
        PopupMenuItem(value: "edit", child: Text(l10n.downloadCardEdit)),
      if (failedOrCanceled && onRetry != null)
        PopupMenuItem(value: "retry", child: Text(l10n.downloadCardRetry)),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: "del",
        child: Text(l10n.downloadCardDelete, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
      ),
    ];
    return out;
  }

  List<Widget> _sheetEntries({
    required AppLocalizations l10n,
    required bool failedOrCanceled,
    required bool done,
  }) {
    return [
      _SheetTile(
        icon: LucideIcons.info,
        label: l10n.downloadCardStatusDetails,
        onTap: () => onOpenStatus(),
      ),
      if (done && !localFileExists)
        _SheetTile(icon: LucideIcons.smartphone, label: l10n.downloadSaveToDevice, onTap: () => onOpenStatus()),
      if (done && localFileExists && onOpenLocal != null)
        _SheetTile(icon: LucideIcons.externalLink, label: l10n.downloadOpen, onTap: () => onOpenLocal!()),
      if (done && localFileExists && onShareLocal != null)
        _SheetTile(icon: LucideIcons.share2, label: l10n.downloadShare, onTap: () => onShareLocal!()),
      if (done && showQuickEdit && onQuickEdit != null)
        _SheetTile(icon: LucideIcons.scissors, label: l10n.downloadCardEdit, onTap: () => onQuickEdit!()),
      if (failedOrCanceled && onRetry != null)
        _SheetTile(icon: LucideIcons.rotateCw, label: l10n.downloadCardRetry, onTap: () => onRetry!()),
      const Divider(height: 1),
      _SheetTile(
        icon: LucideIcons.trash2,
        label: l10n.downloadCardDelete,
        destructive: true,
        onTap: () => onDelete(),
      ),
    ];
  }

  List<Widget> _slidableActions(
    BuildContext context, {
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required bool failedOrCanceled,
    required bool done,
  }) {
    final active = item.active;
    final beforeDelete = <Widget>[];

    void addBeforeDelete(Widget w) {
      if (beforeDelete.length < 2) beforeDelete.add(w);
    }

    if (active) {
      addBeforeDelete(
        SlidableAction(
          onPressed: (_) {
            HapticFeedback.lightImpact();
            onOpenStatus();
          },
          backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
          foregroundColor: scheme.onSurface,
          icon: Icons.info_outline_rounded,
          label: l10n.downloadCardStatusDetails,
        ),
      );
    } else if (failedOrCanceled && onRetry != null) {
      addBeforeDelete(
        SlidableAction(
          onPressed: (_) {
            HapticFeedback.lightImpact();
            onRetry!();
          },
          backgroundColor: scheme.primaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.85 : 1),
          foregroundColor: scheme.onPrimaryContainer,
          icon: Icons.refresh_rounded,
          label: l10n.downloadCardRetry,
        ),
      );
    } else if (done && !localFileExists) {
      addBeforeDelete(
        SlidableAction(
          onPressed: (_) {
            HapticFeedback.lightImpact();
            onOpenStatus();
          },
          backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.92),
          foregroundColor: scheme.onSecondaryContainer,
          icon: Icons.save_alt_rounded,
          label: l10n.downloadSaveToDevice,
        ),
      );
      if (showQuickEdit && onQuickEdit != null) {
        addBeforeDelete(
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              onQuickEdit!();
            },
            backgroundColor: scheme.tertiaryContainer.withValues(alpha: 0.92),
            foregroundColor: scheme.onTertiaryContainer,
            icon: Icons.content_cut_rounded,
            label: l10n.downloadCardEdit,
          ),
        );
      }
    } else if (done && localFileExists) {
      if (onShareLocal != null) {
        addBeforeDelete(
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              onShareLocal!();
            },
            backgroundColor: scheme.primaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.55 : 0.95),
            foregroundColor: scheme.onPrimaryContainer,
            icon: Icons.share_rounded,
            label: l10n.downloadShare,
          ),
        );
      }
      if (showQuickEdit && onQuickEdit != null) {
        addBeforeDelete(
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              onQuickEdit!();
            },
            backgroundColor: scheme.tertiaryContainer.withValues(alpha: 0.92),
            foregroundColor: scheme.onTertiaryContainer,
            icon: Icons.content_cut_rounded,
            label: l10n.downloadCardEdit,
          ),
        );
      }
    }

    final deleteAction = SlidableAction(
      onPressed: (_) {
        HapticFeedback.lightImpact();
        onDelete();
      },
      backgroundColor: scheme.error,
      foregroundColor: scheme.onError,
      icon: Icons.delete_outline_rounded,
      label: l10n.downloadCardDelete,
    );

    final actions = <Widget>[...beforeDelete, deleteAction];
    return actions;
  }

  void _handleMenuKey(
    String k, {
    required VoidCallback onOpenStatus,
    required VoidCallback? onRetry,
    required VoidCallback onDelete,
    required VoidCallback? onOpenLocal,
    required VoidCallback? onShareLocal,
    required VoidCallback? onQuickEdit,
  }) {
    switch (k) {
      case "status":
        onOpenStatus();
        break;
      case "save":
        onOpenStatus();
        break;
      case "open":
        onOpenLocal?.call();
        break;
      case "share":
        onShareLocal?.call();
        break;
      case "edit":
        onQuickEdit?.call();
        break;
      case "retry":
        onRetry?.call();
        break;
      case "del":
        onDelete();
        break;
      default:
        break;
    }
  }

  void _showActionsSheet(
    BuildContext context, {
    required List<Widget> entries,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerHigh,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    l10n.downloadCardActionsTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                ...entries,
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _thumb(BuildContext context) {
    final thumb = item.thumbnail;
    if (thumb != null && thumb.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: _thumbW,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.88),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailTap extends StatelessWidget {
  const _ThumbnailTap({
    required this.localFileExists,
    required this.onOpenLocal,
    required this.onFallback,
    required this.child,
  });

  final bool localFileExists;
  final VoidCallback? onOpenLocal;
  final VoidCallback onFallback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (localFileExists && onOpenLocal != null) {
            onOpenLocal!();
          } else {
            onFallback();
          }
        },
        splashColor: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        icon: Icon(icon, size: 18, color: scheme.onPrimary),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = destructive ? scheme.error : scheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: fg),
      title: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        HapticFeedback.lightImpact();
        onTap();
      },
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
