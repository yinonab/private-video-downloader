import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/app_scope.dart";
import "../../core/config/build_flags.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../l10n/app_localizations.dart";
import "../../core/l10n/download_stage_localizations.dart";
import "../../core/l10n/download_status_localizations.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/theme/app_theme.dart";
import "../../core/utils/download_error_display.dart";
import "../../core/utils/format_bytes_ui.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/branded_loading.dart";
import "../../core/widgets/branded_progress.dart";
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
  bool _localSaved = false;
  bool _localLookupDone = false;

  @override
  void initState() {
    super.initState();
    _tickOnce();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tickOnce());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocalSaved());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshLocalSaved() async {
    final session = AppScope.read(context).session;
    final desc = await session.savedDownloadForJob(widget.jobId);
    if (!mounted) return;
    setState(() {
      _localSaved = desc != null && desc.internalPath.trim().isNotEmpty;
      _localLookupDone = true;
    });
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
      if (next.status == "done") {
        await _refreshLocalSaved();
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
      await _refreshLocalSaved();
      final msg = outcome.mediaStorePublished == true && outcome.publicUri != null
          ? l10n.downloadSavedToDownloads
          : (Platform.isAndroid ? l10n.downloadSavedInAppOnly : l10n.downloadSavedGeneric);
      if (!mounted) return;
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

  bool _showServerProgress(DownloadDetailResponse d) =>
      d.status == "queued" || d.status == "analyzing" || d.status == "running";

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = _detail;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadStatusTitle)),
      body: RefreshIndicator(
        onRefresh: _tickOnce,
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_err != null && d == null) ...[
              Icon(LucideIcons.triangleAlert, size: 48, color: scheme.error),
              const SizedBox(height: 10),
              Text(localizedApiErrorMessage(l10n, _err!), style: theme.textTheme.titleMedium),
              const SizedBox(height: 14),
              AppPrimaryButton(label: l10n.downloadRetry, loading: false, onPressed: _retry),
            ],
            if (d == null && _err == null) ...[
              const SizedBox(height: 72),
              BrandedLoadingPanel(message: l10n.downloadStatusLoadingJob),
            ],
            if (d != null) ...[
              if (_err != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.triangleAlert, color: scheme.error, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            localizedApiErrorMessage(l10n, _err!),
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              DecoratedBox(
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
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
                      Text(
                        (() {
                          final t = (d.title ?? "").trim();
                          return t.isEmpty ? l10n.untitledVideo : t;
                        })(),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Align(
                          key: ValueKey<String>("${d.status}|$_localSaved|$_localLookupDone"),
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _headlineLabel(l10n, d),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_showServerProgress(d)) ...[
                        Builder(
                          builder: (context) {
                            final indeterminate = d.status == "queued" && d.progress <= 0;
                            final pct = d.progress.clamp(0, 100);
                            return BrandedProgressBar(
                              indeterminate: indeterminate,
                              value: indeterminate ? null : pct / 100.0,
                              percentLabel: indeterminate ? null : l10n.downloadPercentValue(pct),
                              stageLabel: downloadStageTitle(l10n, d.status),
                            );
                          },
                        ),
                        if ((d.speedText ?? "").trim().isNotEmpty || (d.etaText ?? "").trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              if ((d.speedText ?? "").trim().isNotEmpty)
                                Text(
                                  l10n.downloadSpeed(d.speedText!.trim()),
                                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              if ((d.etaText ?? "").trim().isNotEmpty)
                                Text(
                                  l10n.downloadEta(d.etaText!.trim()),
                                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ],
                      ],
                      if ((d.status == "failed" || d.status == "canceled") && (d.error ?? "").trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          formatDownloadJobError(l10n, d.error!),
                          style: TextStyle(color: scheme.error, height: 1.35),
                        ),
                      ],
                      if (d.status == "failed" || d.status == "canceled") ...[
                        const SizedBox(height: 18),
                        AppPrimaryButton(label: l10n.downloadRetry, loading: false, onPressed: _retry),
                      ],
                      if (d.status == "done") ...[
                        if (!_localLookupDone)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: BrandedLoadingPanel(compact: true),
                          )
                        else ...[
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: _localSaved
                                ? Column(
                                    key: const ValueKey<String>("saved"),
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const SizedBox(height: 6),
                                      Icon(LucideIcons.circleCheck, size: 48, color: AppTheme.successGreen),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.downloadStatusSavedOnDeviceTitle,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                  )
                                : Column(
                                    key: const ValueKey<String>("ready"),
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        l10n.downloadVideoReadyHint,
                                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                  ),
                          ),
                          if (_fileBusy) ...[
                            BrandedProgressBar(
                              indeterminate: _totalBytes <= 0,
                              value: _totalBytes > 0 ? (_receiveBytes / _totalBytes).clamp(0.0, 1.0) : null,
                              percentLabel: _totalBytes > 0
                                  ? l10n.downloadPercentValue(
                                      (100 * _receiveBytes / _totalBytes).clamp(0, 100).round(),
                                    )
                                  : null,
                              stageLabel: l10n.loadingSavingToDeviceDot,
                              bytesSubtitle: _totalBytes > 0 ? "${formatBytesUi(_receiveBytes)} / ${formatBytesUi(_totalBytes)}" : null,
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (!_localSaved)
                            AppPrimaryButton(
                              label: l10n.downloadSaveToDevice,
                              loading: _fileBusy,
                              icon: const Icon(LucideIcons.smartphone),
                              onPressed: _fileBusy ? null : _downloadToDevice,
                            ),
                          if (!_localSaved) const SizedBox(height: 10),
                          AppOutlinedButton(
                            label: l10n.downloadOpen,
                            icon: Icon(LucideIcons.externalLink, color: scheme.primary),
                            onPressed: _openLocal,
                          ),
                          const SizedBox(height: 10),
                          AppOutlinedButton(
                            label: l10n.downloadShare,
                            icon: Icon(LucideIcons.share2, color: scheme.primary),
                            onPressed: _shareLocal,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
    );
  }

  String _headlineLabel(AppLocalizations l10n, DownloadDetailResponse d) {
    if (d.status == "done" && _localLookupDone && _localSaved) {
      return l10n.downloadStatusSavedOnDeviceTitle;
    }
    return localizedDownloadJobStatus(l10n, d.status);
  }

  Widget _ph(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(LucideIcons.video, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
