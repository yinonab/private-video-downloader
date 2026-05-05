import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/utils/url_utils.dart";
import "../../core/widgets/error_view.dart";
import "../../core/widgets/loading_view.dart";
import "../../l10n/app_localizations.dart";
import "../../services/saved_media_actions.dart";
import "../analyze/analyze_screen.dart";
import "../download_status/download_status_screen.dart";
import "../settings/settings_screen.dart";
import "download_card.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;
  bool _first = true;
  Object? _err;
  List<DownloadItem> _items = [];

  Future<void> _load() async {
    final svc = AppScope.read(context).downloadService;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final page = await svc.list(page: 1, limit: 50);
      if (!mounted) return;
      setState(() => _items = page.items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _first = false;
        });
      }
    }
  }

  void _openAnalyze(String raw) {
    final l10n = context.l10n;
    final u = UrlUtils.extractFirst(raw) ?? (UrlUtils.looksLikeHttpUrl(raw.trim()) ? raw.trim() : null);
    if (u == null || u.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.homeInvalidLink)));
      return;
    }
    final cleanUrl = UrlUtils.stripTrailingJunk(u);
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AnalyzeScreen(key: ValueKey<String>("analyze|$cleanUrl"), initialUrl: cleanUrl),
      ),
    );
  }

  Future<void> _pasteDialog() async {
    final l10n = context.l10n;
    final c = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.homePasteDialogTitle),
          content: TextField(
            controller: c,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(hintText: l10n.homePasteDialogHint),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.homeCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(l10n.homeContinue)),
          ],
        );
      },
    );
    if (res == null || res.isEmpty) return;
    _openAnalyze(res);
  }

  Future<void> _confirmDelete(DownloadItem j) async {
    final l10n = context.l10n;
    final scope = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.homeDeleteDownloadTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.homeCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.homeDeleteConfirm)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await scope.downloadService.delete(j.id);
      await scope.files.deleteCached(j.id);
      await _load();
    } catch (e) {
      final m = e is ApiError ? localizedApiErrorMessage(loc, e) : "$e";
      messenger.showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _retry(DownloadItem j) async {
    final scope = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    try {
      await scope.downloadService.retry(j.id);
      await _load();
      if (!context.mounted) return;
      await nav.push<void>(
        MaterialPageRoute<void>(builder: (_) => DownloadStatusScreen(jobId: j.id)),
      );
      await _load();
    } catch (e) {
      final m = e is ApiError ? localizedApiErrorMessage(loc, e) : "$e";
      messenger.showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _openLocal(String jobId) async {
    await openSavedDownload(
      context: context,
      session: AppScope.read(context).session,
      jobId: jobId,
    );
  }

  Future<void> _shareLocal(String jobId, String title) async {
    await shareSavedDownload(
      context: context,
      session: AppScope.read(context).session,
      jobId: jobId,
      title: title,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final initialLoading = _first && _busy;
    final hasError = _err != null;
    final listReady = !_first && !_busy && !hasError;
    final hasItems = listReady && _items.isNotEmpty;
    final isEmpty = listReady && _items.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _busy ? null : _load),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () async {
              await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
              await _load();
            },
          ),
        ],
      ),
      floatingActionButton: hasItems
          ? FloatingActionButton.extended(
              onPressed: _pasteDialog,
              icon: const Icon(Icons.link_rounded),
              label: Text(l10n.homePasteLinkFab),
            )
          : null,
      body: initialLoading
          ? LoadingView(message: l10n.homeLoading)
          : hasError
              ? ErrorView(
                  title: _err is ApiError ? localizedApiErrorMessage(l10n, _err! as ApiError) : l10n.homeErrorGeneric,
                  retryLabel: l10n.homeRetry,
                  onRetry: _load,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, hasItems ? 6 : 12),
                      child: _HomeHeroCard(
                        compact: hasItems,
                        showTip: isEmpty,
                        showPrimaryButton: isEmpty,
                        onPaste: _pasteDialog,
                      ),
                    ),
                    if (hasItems) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Text(
                          l10n.homeRecentDownloads,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: isEmpty ? _HomeEmptyIllustration(l10n: l10n, scheme: scheme, theme: theme) : _buildList(context),
                    ),
                  ],
                ),
    );
  }

  Widget _buildList(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom + 88;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return _busy ? const Padding(padding: EdgeInsets.all(22), child: LoadingView()) : const SizedBox(height: 24);
          }
          final job = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FutureBuilder<String?>(
              future: AppScope.read(context).session.localPathForJob(job.id),
              builder: (context, snap) {
                final exists = snap.hasData && (snap.data?.isNotEmpty ?? false);
                return DownloadCard(
                  item: job,
                  localFileExists: exists,
                  onOpenStatus: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(builder: (_) => DownloadStatusScreen(jobId: job.id)),
                    );
                    await _load();
                  },
                  onRetry: (job.status == "failed" || job.status == "canceled") ? () => _retry(job) : null,
                  onDelete: () => _confirmDelete(job),
                  onOpenLocal: exists ? () => _openLocal(job.id) : null,
                  onShareLocal: exists ? () => _shareLocal(job.id, job.title) : null,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HomeHeroCard extends StatelessWidget {
  const _HomeHeroCard({
    required this.compact,
    required this.showTip,
    required this.showPrimaryButton,
    required this.onPaste,
  });

  final bool compact;
  final bool showTip;
  final bool showPrimaryButton;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.play_circle_outline_rounded, color: scheme.primary, size: compact ? 26 : 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.homeHeroTitle,
                    style: compact
                        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface)
                        : theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              compact ? l10n.homeHeroSubtitleCompact : l10n.homeHeroSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            if (showTip) ...[
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.tips_and_updates_outlined, size: 20, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.homeShareTip,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (showPrimaryButton) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPaste,
                  icon: const Icon(Icons.content_paste_go_rounded),
                  label: Text(l10n.homePasteLinkButton),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyIllustration extends StatelessWidget {
  const _HomeEmptyIllustration({
    required this.l10n,
    required this.scheme,
    required this.theme,
  });

  final AppLocalizations l10n;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.video_library_rounded, size: 52, color: scheme.primary),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.homeEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.homeEmptySubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
