import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/app_scope.dart";
import "../../core/downloads/redownload_request_resolution.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/models/quick_edit_models.dart";
import "../../core/utils/url_utils.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/widgets/error_view.dart";
import "../../core/widgets/linkclip_app_bar.dart";
import "../../core/widgets/loading_view.dart";
import "../../l10n/app_localizations.dart";
import "../../services/saved_media_actions.dart";
import "../analyze/analyze_screen.dart";
import "../download_status/download_status_screen.dart";
import "../edit/quick_edit_launch.dart";
import "../edit/local_video_edit_launcher.dart";
import "../settings/settings_screen.dart";
import "download_card.dart";
import "home_edits_tab.dart";
import "home_quick_actions.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _first = true;
  Object? _err;
  List<DownloadItem> _items = [];

  late TabController _tabController;

  Future<void> _load() async {
    final svc = AppScope.read(context).downloadService;
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final page = await svc.list(page: 1, limit: 50);
      if (!mounted) return;
      final session = AppScope.read(context).session;
      setState(() => _items = page.items);
      for (final job in page.items) {
        unawaited(tryBackfillStoredRequestFromListItem(session, job));
      }
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

  Future<void> _openAnalyze(String raw) async {
    final l10n = context.l10n;
    final u = UrlUtils.extractFirst(raw) ?? (UrlUtils.looksLikeHttpUrl(raw.trim()) ? raw.trim() : null);
    if (u == null || u.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.homeInvalidLink)));
      return;
    }
    final cleanUrl = UrlUtils.stripTrailingJunk(u);
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AnalyzeScreen(key: ValueKey<String>("analyze|$cleanUrl"), initialUrl: cleanUrl),
      ),
    );
    if (mounted) await _load();
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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onHomeTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _load();
    });
  }

  void _onHomeTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onHomeTabChanged);
    _tabController.dispose();
    super.dispose();
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
    final showPasteFab = listReady && hasItems && _tabController.index == 0;

    return DecoratedBox(
      decoration: linkClipPageGradientDecoration(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LinkClipPremiumAppBar(
          title: Text(l10n.appTitle),
          actions: [
            LinkClipToolbarIconButton(
              icon: LucideIcons.refreshCw,
              tooltip: l10n.homeRetry,
              onPressed: _busy ? null : _load,
            ),
            LinkClipToolbarIconButton(
              icon: LucideIcons.settings,
              tooltip: l10n.settingsTitle,
              onPressed: () async {
                await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
                await _load();
              },
            ),
          ],
        ),
      floatingActionButton: showPasteFab
          ? FloatingActionButton.extended(
              onPressed: _pasteDialog,
              icon: Icon(LucideIcons.link2, color: scheme.onPrimary),
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
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: HomeQuickActions(
                        onPasteLink: _pasteDialog,
                        onEditVideo: () {
                          unawaited(launchLocalVideoEdit(context));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: scheme.primary,
                        labelColor: scheme.primary,
                        unselectedLabelColor: scheme.onSurfaceVariant,
                        indicatorWeight: 3,
                        labelStyle: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        tabs: [
                          Tab(text: l10n.homeTabDownloads),
                          Tab(text: l10n.homeTabEdits),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          _buildDownloadsTab(context),
                          HomeEditsTab(
                            editHistory: AppScope.read(context).editHistory,
                            onEditVideo: () {
                              unawaited(launchLocalVideoEdit(context));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildDownloadsTab(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final hasItems = _items.isNotEmpty;
    final reserveFab = hasItems && _tabController.index == 0;
    final bottomInset = MediaQuery.of(context).padding.bottom + (reserveFab ? 112 : 28);

    if (!hasItems) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
          children: [
            const SizedBox(height: 8),
            _HomeEmptyIllustration(l10n: l10n, scheme: scheme, theme: theme),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottomInset),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return _busy ? const Padding(padding: EdgeInsets.all(22), child: LoadingView(compact: true)) : const SizedBox(height: 24);
          }
          final job = _items[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FutureBuilder<String?>(
              future: AppScope.read(context).session.localPathForJob(job.id),
              builder: (context, snap) {
                final exists = snap.hasData && (snap.data?.isNotEmpty ?? false);
                final eligible = downloadItemEligibleForQuickEdit(job);
                return DownloadCard(
                  item: job,
                  localFileExists: exists,
                  showQuickEdit: eligible,
                  onQuickEdit: eligible
                      ? () async {
                          await launchQuickEditForJob(
                            context,
                            jobId: job.id,
                            serverRetentionReferenceUtc: job.createdAt,
                            prefetchListItem: job,
                          );
                          await _load();
                        }
                      : null,
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
    final block = Center(
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
              child: Icon(LucideIcons.video, size: 52, color: scheme.primary),
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
    return block
        .animate()
        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
        .scale(begin: const Offset(0.97, 0.97), end: const Offset(1, 1), duration: 340.ms, curve: Curves.easeOut);
  }
}
