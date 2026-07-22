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
import "../../core/models/quick_edit_models.dart";
import "../../core/media/linkclip_media_thumbnail.dart";
import "../../core/theme/linkclip_design_system.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/widgets/branded_progress.dart";
import "../../core/widgets/linkclip_chips.dart";
import "../../l10n/app_localizations.dart";

/// Compact media card: aspect-aware project tile + title/actions (not full-width landscape banners).
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

  final bool showQuickEdit;
  final VoidCallback? onQuickEdit;

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

  /// Restrained swipe pane (~0.24–0.32 of card width depending on icon count).
  static double _swipeExtentRatio(int actionCount) {
    if (actionCount <= 0) return 0;
    final raw = 0.068 * actionCount + 0.11;
    return math.min(0.32, math.max(0.22, raw));
  }

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
    final isAudioOnly = downloadItemIsAudioOnly(item);

    final primary = _primaryAction(
      l10n,
      done: done,
      failedOrCanceled: failedOrCanceled,
      onRetry: onRetry,
      onOpenStatus: onOpenStatus,
      onOpenLocal: onOpenLocal,
      localFileExists: localFileExists,
      isAudioOnly: isAudioOnly,
      showQuickEdit: showQuickEdit,
      onQuickEdit: onQuickEdit,
    );

    final primaryIsOpenLocal = done && localFileExists && onOpenLocal != null;

    final cardFace = Material(
      color: scheme.surface.withValues(alpha: dark ? 0.88 : 1),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LcRadius.card),
        side: BorderSide(color: scheme.outline.withValues(alpha: dark ? 0.38 : 0.26)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(LcSpace.lg, LcSpace.lg, LcSpace.sm, LcSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ThumbnailTap(
                  localFileExists: localFileExists,
                  onOpenLocal: onOpenLocal,
                  onFallback: onOpenStatus,
                  child: _thumb(context),
                ),
                const SizedBox(width: LcSpace.md),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(LcRadius.small),
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
                            hideOpenInSheet: primaryIsOpenLocal,
                            isAudioOnly: isAudioOnly,
                          ),
                        );
                      },
                      splashColor: scheme.primary.withValues(alpha: 0.06),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              titleLine,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                                height: 1.3,
                                letterSpacing: -0.15,
                              ),
                            ),
                            const SizedBox(height: LcSpace.sm),
                            Wrap(
                              spacing: LcSpace.sm,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                LinkClipStatusChip(
                                  label: statusLabel,
                                  semantic: item.statusParsed.label,
                                ),
                                Text(
                                  platformLine.toLowerCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            if (done && isAudioOnly) ...[
                              const SizedBox(height: LcSpace.sm),
                              Text(
                                l10n.downloadCardMp3Badge,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.primary.withValues(alpha: 0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (done && isTikTokJob) ...[
                              const SizedBox(height: LcSpace.sm),
                              Text(
                                l10n.downloadChipTikTokReady,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: palette.tiktokOnAccent.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w500,
                                  fontSize: (theme.textTheme.labelSmall?.fontSize ?? 11) * 0.95,
                                ),
                              ),
                            ],
                            if (item.active) ...[
                              const SizedBox(height: LcSpace.md),
                              Builder(
                                builder: (context) {
                                  final pct = ui.determinatePercent ?? 0;
                                  return BrandedProgressBar(
                                    dense: true,
                                    indeterminate: ui.showIndeterminateProgress,
                                    value: ui.showDeterminateProgress ? pct / 100.0 : null,
                                    percentLabel:
                                        ui.showDeterminateProgress ? l10n.progressPercent(pct) : null,
                                    stageLabel: ui.progressStageTitle,
                                    stageSubtitle: ui.progressStageSubtitle,
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: LcSpace.sm),
                            Text(
                              [if (sizeStr != null) sizeStr, dateStr].join(" · "),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w400,
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
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  onOpened: () => HapticFeedback.selectionClick(),
                  icon: Icon(
                    LucideIcons.ellipsisVertical,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                    size: 20,
                  ),
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
                    primaryIsOpenLocal: primaryIsOpenLocal,
                    isAudioOnly: isAudioOnly,
                  ),
                ),
              ],
            ),
          ),
          if (primary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(LcSpace.lg, 0, LcSpace.lg, LcSpace.lg),
              child: _PrimaryCta(
                label: primary.label,
                icon: primary.icon,
                onTap: primary.onTap,
              ),
            ),
        ],
      ),
    );

    Widget layered = cardFace;
    final swipeActions = _swipePaneChildren(
      context,
      l10n,
      scheme: scheme,
      dark: dark,
      done: done,
      failedOrCanceled: failedOrCanceled,
      onOpenStatus: onOpenStatus,
      onRetry: onRetry,
      onDelete: onDelete,
      onShareLocal: onShareLocal,
      onQuickEdit: onQuickEdit,
      isAudioOnly: isAudioOnly,
    );
    if (swipeActions.isNotEmpty) {
      layered = Slidable(
        key: ValueKey<String>("download-slidable-${item.id}"),
        groupTag: "home-downloads",
        closeOnScroll: true,
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: _swipeExtentRatio(swipeActions.length),
          dragDismissible: false,
          children: swipeActions,
        ),
        child: cardFace,
      );
    }

    if (listAnimationIndex != null && listAnimationIndex! < 16) {
      final i = listAnimationIndex!;
      return layered
          .animate(delay: (i * 18).ms)
          .fadeIn(duration: 200.ms, curve: Curves.easeOut)
          .slideY(begin: 0.02, duration: 220.ms, curve: Curves.easeOutCubic);
    }

    return layered;
  }

  List<Widget> _swipePaneChildren(
    BuildContext context,
    AppLocalizations l10n, {
    required ColorScheme scheme,
    required bool dark,
    required bool done,
    required bool failedOrCanceled,
    required VoidCallback onOpenStatus,
    required VoidCallback? onRetry,
    required VoidCallback onDelete,
    required VoidCallback? onShareLocal,
    required VoidCallback? onQuickEdit,
    required bool isAudioOnly,
  }) {
    final swipeNeutralBg = dark ? const Color(0xFF1B2433) : scheme.surfaceContainerHighest.withValues(alpha: 0.96);
    final swipeNeutralIcon = dark ? const Color(0xFFA7B2C2) : scheme.onSurfaceVariant.withValues(alpha: 0.85);
    final swipeAccentIcon = dark ? const Color(0xFFA9CCE6) : scheme.primary.withValues(alpha: 0.88);
    final swipeDangerBg = dark ? const Color(0xFF3A2024) : Color.alphaBlend(const Color(0xFFC96B6B).withValues(alpha: 0.12), scheme.surface);
    final swipeDangerIcon = const Color(0xFFC96B6B);

    CustomSlidableAction iconSwipe({
      required BuildContext outerContext,
      required String tooltipMessage,
      required IconData icon,
      required VoidCallback invoke,
      required Color bgColor,
      required Color iconColor,
    }) {
      final pad =
          EdgeInsetsDirectional.only(start: 4, end: 2, top: 9, bottom: 17).resolve(Directionality.of(outerContext));
      return CustomSlidableAction(
        flex: 1,
        padding: pad,
        backgroundColor: Colors.transparent,
        autoClose: true,
        onPressed: (_) {
          HapticFeedback.lightImpact();
          invoke();
        },
        child: Tooltip(
          message: tooltipMessage,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outline.withValues(alpha: dark ? 0.32 : 0.38)),
            ),
            child: Center(child: Icon(icon, size: 21, color: iconColor)),
          ),
        ),
      );
    }

    if (item.active) {
      return [
        iconSwipe(
          outerContext: context,
          tooltipMessage: l10n.downloadCardStatusDetails,
          icon: LucideIcons.info,
          invoke: onOpenStatus,
          bgColor: swipeNeutralBg,
          iconColor: swipeNeutralIcon,
        ),
      ];
    }

    if (failedOrCanceled) {
      final list = <Widget>[];
      if (onRetry != null) {
        list.add(iconSwipe(
          outerContext: context,
          tooltipMessage: l10n.downloadCardRetry,
          icon: LucideIcons.rotateCw,
          invoke: onRetry,
          bgColor: swipeNeutralBg,
          iconColor: swipeAccentIcon,
        ));
      }
      list.add(iconSwipe(
        outerContext: context,
        tooltipMessage: l10n.downloadCardDelete,
        icon: LucideIcons.trash2,
        invoke: onDelete,
        bgColor: swipeDangerBg,
        iconColor: swipeDangerIcon,
      ));
      return list;
    }

    if (done) {
      final list = <Widget>[];
      if (localFileExists && onShareLocal != null) {
        list.add(iconSwipe(
          outerContext: context,
          tooltipMessage: l10n.downloadShare,
          icon: LucideIcons.share2,
          invoke: onShareLocal,
          bgColor: swipeNeutralBg,
          iconColor: swipeAccentIcon,
        ));
      }
      if (showQuickEdit && onQuickEdit != null) {
        list.add(iconSwipe(
          outerContext: context,
          tooltipMessage:
              isAudioOnly ? l10n.downloadCardEditAudio : l10n.downloadCardEditVideo,
          icon: isAudioOnly ? LucideIcons.audioLines : LucideIcons.scissors,
          invoke: onQuickEdit,
          bgColor: swipeNeutralBg,
          iconColor: swipeAccentIcon,
        ));
      }
      list.add(iconSwipe(
        outerContext: context,
        tooltipMessage: l10n.downloadCardDelete,
        icon: LucideIcons.trash2,
        invoke: onDelete,
        bgColor: swipeDangerBg,
        iconColor: swipeDangerIcon,
      ));
      return list;
    }

    return [
      iconSwipe(
        outerContext: context,
        tooltipMessage: l10n.downloadCardStatusDetails,
        icon: LucideIcons.info,
        invoke: onOpenStatus,
        bgColor: swipeNeutralBg,
        iconColor: swipeNeutralIcon,
      ),
      iconSwipe(
        outerContext: context,
        tooltipMessage: l10n.downloadCardDelete,
        icon: LucideIcons.trash2,
        invoke: onDelete,
        bgColor: swipeDangerBg,
        iconColor: swipeDangerIcon,
      ),
    ];
  }

  ({String label, IconData icon, VoidCallback onTap})? _primaryAction(
    AppLocalizations l10n, {
    required bool done,
    required bool failedOrCanceled,
    required VoidCallback? onRetry,
    required VoidCallback onOpenStatus,
    required VoidCallback? onOpenLocal,
    required bool localFileExists,
    required bool isAudioOnly,
    required bool showQuickEdit,
    required VoidCallback? onQuickEdit,
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
    if (done && isAudioOnly && showQuickEdit && onQuickEdit != null) {
      return (
        label: l10n.downloadCardEditAudio,
        icon: LucideIcons.audioLines,
        onTap: onQuickEdit,
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
    required bool primaryIsOpenLocal,
    required bool isAudioOnly,
  }) {
    final out = <PopupMenuEntry<String>>[
      PopupMenuItem(value: "status", child: Text(l10n.downloadCardStatusDetails)),
      if (done && !localFileExists) PopupMenuItem(value: "save", child: Text(l10n.downloadSaveToDevice)),
      if (done && localFileExists && onOpenLocal != null && !primaryIsOpenLocal)
        PopupMenuItem(value: "open", child: Text(l10n.downloadOpen)),
      if (done && localFileExists && onShareLocal != null)
        PopupMenuItem(value: "share", child: Text(l10n.downloadShare)),
      if (done && showQuickEdit && onQuickEdit != null)
        PopupMenuItem(
          value: "edit",
          child: Text(isAudioOnly ? l10n.downloadCardEditAudio : l10n.downloadCardEditVideo),
        ),
      if (failedOrCanceled && onRetry != null) PopupMenuItem(value: "retry", child: Text(l10n.downloadCardRetry)),
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
    required bool hideOpenInSheet,
    required bool isAudioOnly,
  }) {
    return [
      _SheetTile(icon: LucideIcons.info, label: l10n.downloadCardStatusDetails, onTap: () => onOpenStatus()),
      if (done && !localFileExists)
        _SheetTile(icon: LucideIcons.smartphone, label: l10n.downloadSaveToDevice, onTap: () => onOpenStatus()),
      if (done && localFileExists && onOpenLocal != null && !hideOpenInSheet)
        _SheetTile(icon: LucideIcons.externalLink, label: l10n.downloadOpen, onTap: () => onOpenLocal!()),
      if (done && localFileExists && onShareLocal != null)
        _SheetTile(icon: LucideIcons.share2, label: l10n.downloadShare, onTap: () => onShareLocal!()),
      if (done && showQuickEdit && onQuickEdit != null)
        _SheetTile(
          icon: isAudioOnly ? LucideIcons.audioLines : LucideIcons.scissors,
          label: isAudioOnly ? l10n.downloadCardEditAudio : l10n.downloadCardEditVideo,
          onTap: () => onQuickEdit!(),
        ),
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
      backgroundColor: scheme.surfaceContainerHighest,
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
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
    final audio = downloadItemIsAudioOnly(item);
    final thumb = item.thumbnail?.trim();
    return LinkClipMediaThumbnail(
      networkUrl: audio ? null : (thumb != null && thumb.isNotEmpty ? thumb : null),
      layout: LinkClipMediaThumbnailLayout.tile,
      fitStrategy: LinkClipMediaThumbnailFit.cover,
      resolveImageAspect: !audio,
      isAudio: audio,
      borderRadius: BorderRadius.circular(LcRadius.medium),
      placeholderIcon: audio ? LucideIcons.audioLines : LucideIcons.video,
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
      borderRadius: BorderRadius.circular(LcRadius.medium),
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
        splashColor: scheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(LcRadius.medium),
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
    final theme = Theme.of(context);

    final fill = Color.alphaBlend(scheme.primary.withValues(alpha: 0.18), scheme.surface);
    final fg = scheme.primary;

    return SizedBox(
      height: 40,
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: fill,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        icon: Icon(icon, size: 17, color: fg),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(color: fg, fontWeight: FontWeight.w600),
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
    final fg = destructive ? scheme.error.withValues(alpha: 0.92) : scheme.onSurface;
    return ListTile(
      leading: Icon(icon, size: 22, color: fg),
      title: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w500)),
      onTap: () {
        Navigator.pop(context);
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}
