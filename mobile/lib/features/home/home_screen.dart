import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/utils/url_utils.dart";
import "../../core/widgets/empty_state.dart";
import "../../core/widgets/error_view.dart";
import "../../core/widgets/loading_view.dart";
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
      if (!mounted) return;
      setState(() {
        _busy = false;
        _first = false;
      });
    }
  }

  void _openAnalyze(String raw) {
    final u = UrlUtils.extractFirst(raw) ?? (UrlUtils.looksLikeHttpUrl(raw.trim()) ? raw.trim() : null);
    if (u == null || u.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("הקישור לא תקין")));
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
    final c = TextEditingController();
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("הדבק קישור", textAlign: TextAlign.right),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: c,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(hintText: "מדביקים כאן את הקישור מהאפליקציה המקורית"),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ביטול")),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text("המשך")),
          ],
        );
      },
    );
    if (res == null || res.isEmpty) return;
    _openAnalyze(res);
  }

  Future<void> _confirmDelete(DownloadItem j) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("למחוק הורדה?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("ביטול")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("מחק")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AppScope.read(context).downloadService.delete(j.id);
      await AppScope.read(context).files.deleteCached(j.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      final m = e is ApiError ? e.localized : "${e}";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _retry(DownloadItem j) async {
    try {
      await AppScope.read(context).downloadService.retry(j.id);
      await _load();
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => DownloadStatusScreen(jobId: j.id)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      final m = e is ApiError ? e.localized : "${e}";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("ההורדות שלי"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _busy ? null : _load),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
              await _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pasteDialog,
        icon: const Icon(Icons.link),
        label: const Text("הדבק קישור"),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_first && _busy) return const LoadingView(message: "טוען…");
    if (_err != null) {
      return ErrorView(
        title: _err is ApiError ? (_err! as ApiError).localized : "שגיאה",
        retryLabel: "נסה שוב",
        onRetry: _load,
      );
    }
    if (_items.isEmpty && !_busy) {
      return EmptyState(
        title: "עדיין אין הורדות",
        subtitle: "שתפו סרטון או הדביקו קישור כדי להתחיל",
        buttonLabel: "הדבק קישור",
        onTap: _pasteDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return _busy ? const Padding(padding: EdgeInsets.all(22), child: LoadingView()) : const SizedBox(height: 48);
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
