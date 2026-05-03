import "dart:async";

import "package:flutter/material.dart";
import "package:open_filex/open_filex.dart";
import "package:share_plus/share_plus.dart";

import "../../core/app_scope.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/widgets/app_button.dart";

class DownloadStatusScreen extends StatefulWidget {
  const DownloadStatusScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<DownloadStatusScreen> createState() => _DownloadStatusScreenState();
}

class _DownloadStatusScreenState extends State<DownloadStatusScreen> {
  Timer? _timer;
  DownloadDetailResponse? _detail;
  ApiError? _err;
  bool _polling = false;
  bool _fileBusy = false;
  int _receiveBytes = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _tickOnce();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tickOnce());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tickOnce() async {
    if (_polling) return;
    _polling = true;
    try {
      final svc = AppScope.read(context).downloadService;
      final next = await svc.detail(widget.jobId);
      if (!mounted) return;
      setState(() {
        _detail = next;
        _err = null;
      });
      if (next.terminal) {
        _timer?.cancel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e is ApiError ? e : ApiError.fromUnknown(e));
      _timer?.cancel();
    } finally {
      _polling = false;
    }
  }

  Future<void> _downloadToDevice() async {
    final d = _detail;
    if (d == null || d.status != "done") return;
    setState(() {
      _fileBusy = true;
      _receiveBytes = 0;
      _totalBytes = 0;
    });
    try {
      final files = AppScope.read(context).files;
      await files.downloadJobMedia(
        jobId: widget.jobId,
        detail: d,
        onProgress: (r, t) {
          if (!mounted) return;
          setState(() {
            _receiveBytes = r;
            _totalBytes = t;
          });
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("הקובץ נשמר")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiError ? e.localized : "$e")));
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _openLocal() async {
    final p = await AppScope.read(context).session.localPathForJob(widget.jobId);
    if (p == null || p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("יש להוריד את הקובץ תחילה")));
      return;
    }
    await OpenFile.open(p);
  }

  Future<void> _shareLocal() async {
    final p = await AppScope.read(context).session.localPathForJob(widget.jobId);
    if (p == null || p.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("יש להוריד את הקובץ תחילה")));
      return;
    }
    await Share.shareXFiles([XFile(p)]);
  }

  Future<void> _retry() async {
    setState(() => _err = null);
    try {
      await AppScope.read(context).downloadService.retry(widget.jobId);
      if (!mounted) return;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tickOnce());
      await _tickOnce();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e is ApiError ? e.localized : "$e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      appBar: AppBar(title: const Text("סטטוס הורדה")),
      body: RefreshIndicator(
        onRefresh: _tickOnce,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(18),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_err != null) ...[
                Icon(Icons.warning_amber_rounded, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 10),
                Text(_err!.localized, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
              ],
              if (d == null && _err == null)
                const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator())),
              if (d != null) ...[
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: d.thumbnail != null && d.thumbnail!.isNotEmpty
                        ? Image.network(
                            d.thumbnail!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ph(context),
                          )
                        : _ph(context),
                  ),
                ),
                const SizedBox(height: 14),
                Text(d.title ?? "ללא כותרת", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Text(DownloadStatusParsed.fromRaw(d.status).hebrew, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: (d.progress.clamp(0, 100)) / 100),
                Text("${d.progress.clamp(0, 100)}%", style: Theme.of(context).textTheme.titleMedium),
                if ((d.speedText ?? "").trim().isNotEmpty)
                  Text("מהירות: ${d.speedText}", style: Theme.of(context).textTheme.bodyMedium),
                if ((d.etaText ?? "").trim().isNotEmpty)
                  Text("זמן משוער: ${d.etaText}", style: Theme.of(context).textTheme.bodyMedium),
                if ((d.status == "failed" || d.status == "canceled") && (d.error ?? "").trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(d.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (d.status == "failed" || d.status == "canceled") ...[
                  const SizedBox(height: 22),
                  AppPrimaryButton(label: "נסה שוב", loading: false, onPressed: _retry),
                ],
                if (d.status == "done") ...[
                  const SizedBox(height: 22),
                  if (_fileBusy && _totalBytes > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(
                        value: _totalBytes <= 0 ? null : (_receiveBytes / _totalBytes).clamp(0.0, 1.0),
                      ),
                    ),
                  AppPrimaryButton(
                    label: "הורד למכשיר",
                    loading: _fileBusy,
                    onPressed: _fileBusy ? null : _downloadToDevice,
                  ),
                  const SizedBox(height: 10),
                  AppOutlinedButton(label: "פתח", onPressed: _openLocal),
                  const SizedBox(height: 10),
                  AppOutlinedButton(label: "שתף", onPressed: _shareLocal),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _ph(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.movie_filter_rounded, size: 80)),
      );
}
