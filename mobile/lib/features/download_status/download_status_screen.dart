import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/download_status_localizations.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/utils/download_error_display.dart";
import "../../core/widgets/app_button.dart";
import "../../services/saved_media_actions.dart";

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
    final l10n = context.l10n;
    final d = _detail;
    if (d == null || d.status != "done") return;
    final scope = AppScope.read(context);
    downloadDebugPrint(
      "pressed הורד למכשיר jobId=${widget.jobId} "
      "baseUrl=${scope.session.serverUrl.trim()} finalFileUrl=${scope.api.downloadFileUrl(widget.jobId)} "
      "tokenExists=${scope.session.deviceToken.trim().isNotEmpty}",
    );
    setState(() {
      _fileBusy = true;
      _receiveBytes = 0;
      _totalBytes = 0;
    });
    try {
      final files = scope.files;
      final outcome = await files.downloadJobMedia(
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
      downloadDebugPrint(
        "downloadToDevice success internalPath=${outcome.internalPath} "
        "mediaStorePublished=${outcome.mediaStorePublished} publicUri=${outcome.publicUri}",
      );
      final msg = outcome.mediaStorePublished == true && outcome.publicUri != null
          ? l10n.downloadSavedToDownloads
          : (Platform.isAndroid ? l10n.downloadSavedInAppOnly : l10n.downloadSavedGeneric);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e, st) {
      downloadDebugPrint(
        "catch download_status_screen._downloadToDevice type=${e.runtimeType} message=$e",
      );
      if (e is DioException) {
        downloadDebugPrint(
          "DioException dioType=${e.type} responseStatus=${e.response?.statusCode} "
          "cancelTokenCancelled=${e.requestOptions.cancelToken?.isCancelled}",
        );
      }
      if (e is ApiError) {
        downloadDebugPrint(
          "ApiError code=${e.code} httpStatus=${e.httpStatus} localized=${e.localized}",
        );
      }
      downloadDebugStackTrace("download_status_screen._downloadToDevice", st);
      if (!mounted) return;
      final msg = e is ApiError ? localizedApiErrorMessage(l10n, e) : "$e";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _fileBusy = false);
    }
  }

  Future<void> _openLocal() async {
    await openSavedDownload(
      context: context,
      session: AppScope.read(context).session,
      jobId: widget.jobId,
    );
  }

  Future<void> _shareLocal() async {
    await shareSavedDownload(
      context: context,
      session: AppScope.read(context).session,
      jobId: widget.jobId,
      title: _detail?.title,
    );
  }

  Future<void> _retry() async {
    final l10n = context.l10n;
    setState(() => _err = null);
    try {
      await AppScope.read(context).downloadService.retry(widget.jobId);
      if (!mounted) return;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tickOnce());
      await _tickOnce();
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiError ? localizedApiErrorMessage(l10n, e) : "$e";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadStatusTitle)),
      body: RefreshIndicator(
        onRefresh: _tickOnce,
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_err != null) ...[
              Icon(Icons.warning_amber_rounded, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 10),
              Text(localizedApiErrorMessage(l10n, _err!), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
              AppPrimaryButton(label: l10n.downloadRetry, loading: false, onPressed: _retry),
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
              Text((() {
                final t = (d.title ?? "").trim();
                return t.isEmpty ? l10n.untitledVideo : t;
              })(), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Text(localizedDownloadJobStatus(l10n, d.status), style: Theme.of(context).textTheme.headlineSmall),
              if (d.status == "done") ...[
                const SizedBox(height: 8),
                Text(l10n.downloadVideoReadyHint, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 10),
              LinearProgressIndicator(value: (d.progress.clamp(0, 100)) / 100),
              Text("${d.progress.clamp(0, 100)}%", style: Theme.of(context).textTheme.titleMedium),
              if ((d.speedText ?? "").trim().isNotEmpty)
                Text(l10n.downloadSpeed(d.speedText!.trim()), style: Theme.of(context).textTheme.bodyMedium),
              if ((d.etaText ?? "").trim().isNotEmpty)
                Text(l10n.downloadEta(d.etaText!.trim()), style: Theme.of(context).textTheme.bodyMedium),
              if ((d.status == "failed" || d.status == "canceled") && (d.error ?? "").trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(formatDownloadJobError(l10n, d.error!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (d.status == "failed" || d.status == "canceled") ...[
                const SizedBox(height: 22),
                AppPrimaryButton(label: l10n.downloadRetry, loading: false, onPressed: _retry),
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
                  label: l10n.downloadSaveToDevice,
                  loading: _fileBusy,
                  onPressed: _fileBusy ? null : _downloadToDevice,
                ),
                const SizedBox(height: 10),
                AppOutlinedButton(label: l10n.downloadOpen, onPressed: _openLocal),
                const SizedBox(height: 10),
                AppOutlinedButton(label: l10n.downloadShare, onPressed: _shareLocal),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _ph(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.movie_filter_rounded, size: 80)),
      );
}
