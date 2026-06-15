import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/app_scope.dart";
import "../../core/operation_wakelock.dart";
import "../../core/downloads/redownload_request_resolution.dart";
import "../../core/config/media_export_constants.dart";
import "../../core/config/build_flags.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/download_job_ui_state.dart";
import "../../core/l10n/media_export_display_path.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/models/quick_edit_models.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/utils/download_error_display.dart";
import "../../core/utils/format_bytes_ui.dart";
import "../../core/utils/video_title_split.dart";
import "../../core/widgets/app_button.dart";
import "../../core/widgets/branded_loading.dart";
import "../../core/widgets/branded_progress.dart";
import "widgets/download_progress_hero_animation.dart";
import "widgets/initial_download_loading_animation.dart";
import "../../core/widgets/expandable_description.dart";
import "../../core/widgets/linkclip_app_bar.dart";
import "../../core/widgets/linkclip_network_thumbnail.dart";
import "../../core/media/backend_media_expired.dart";
import "../../core/widgets/internet_download_expired_sheet.dart";
import "../../core/widgets/keep_app_open_hint.dart";
import "../../services/saved_media_actions.dart";
import "../edit/quick_edit_launch.dart";

class DownloadStatusScreen extends StatefulWidget {
  /// Poll an existing job (opened from history / after creation resolved elsewhere).
  DownloadStatusScreen({super.key, required this.jobId})
      : pendingCreateRequest = null,
        expiredRedownloadPriorJobId = null,
        assert(jobId.trim().isNotEmpty);

  /// Navigate here immediately; creates the job via API then polls like [DownloadStatusScreen].
  // ignore: prefer_const_constructors_in_immutables — [CreateDownloadRequest] is never a const value.
  DownloadStatusScreen.pendingCreate({
    super.key,
    required CreateDownloadRequest request,
    this.expiredRedownloadPriorJobId,
  })  : jobId = "",
        pendingCreateRequest = request;

  final String jobId;
  final CreateDownloadRequest? pendingCreateRequest;

  /// When non-null, [pendingCreate] was opened from Quick Edit expired-sheet redownload (debug only).
  final String? expiredRedownloadPriorJobId;

  @override
  State<DownloadStatusScreen> createState() => _DownloadStatusScreenState();
}

class _DownloadStatusScreenState extends State<DownloadStatusScreen> {
  static const Duration _minimumInitialLoadingDuration = Duration(seconds: 3);

  Timer? _timer;
  Timer? _pendingCreateMinLoadingTimer;
  /// While true (pending-create only), UI keeps [InitialDownloadLoadingAnimation] even if [_detail]/[_err] already arrived.
  bool _pendingCreateRevealHeld = false;

  DownloadDetailResponse? _detail;
  ApiError? _err;
  /// Job id once [DownloadStatusScreen.pendingCreate] finishes POST /downloads.
  String? _resolvedJobId;
  bool _polling = false;
  bool _fileBusy = false;
  bool _expiredRedownloadOfferInFlight = false;
  int _receiveBytes = 0;
  int _totalBytes = 0;
  bool _localSaved = false;
  bool _localLookupDone = false;
  bool _downloadWakelockHeld = false;

  bool _wantsDownloadWakelock() {
    if (_fileBusy) return true;
    final pollId = _pollJobId;
    if (pollId.isEmpty) {
      return widget.pendingCreateRequest != null && _err == null;
    }
    final d = _detail;
    if (d == null) return true;
    return !d.terminal;
  }

  Future<void> _syncDownloadWakelock() async {
    final want = _wantsDownloadWakelock();
    if (want == _downloadWakelockHeld) return;
    if (want) {
      await OperationWakelock.acquire();
      _downloadWakelockHeld = true;
    } else {
      await OperationWakelock.release();
      _downloadWakelockHeld = false;
    }
  }

  Future<void> _releaseDownloadWakelockIfHeld() async {
    if (!_downloadWakelockHeld) return;
    _downloadWakelockHeld = false;
    await OperationWakelock.release();
  }

  bool get _pendingCreateMinHoldActive =>
      widget.pendingCreateRequest != null && _pendingCreateRevealHeld;

  /// Values shown in [build]; gated only for UX minimum splash on [pendingCreate].
  DownloadDetailResponse? get _displayDetail =>
      _pendingCreateMinHoldActive ? null : _detail;

  ApiError? get _displayErr => _pendingCreateMinHoldActive ? null : _err;

  String get _pollJobId {
    if (widget.pendingCreateRequest != null) {
      return (_resolvedJobId ?? "").trim();
    }
    return widget.jobId.trim();
  }

  void _startPollingTimer() {
    _timer?.cancel();
    final id = _pollJobId;
    if (id.isEmpty) return;
    assert(() {
      if (kDebugMode) debugPrint("### JOB_STATUS_DEBUG ### polling start jobId=$id");
      return true;
    }());
    _tickOnce();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tickOnce());
  }

  @override
  void initState() {
    super.initState();
    if (widget.pendingCreateRequest != null) {
      _pendingCreateRevealHeld = true;
      _pendingCreateMinLoadingTimer = Timer(_minimumInitialLoadingDuration, () {
        if (!mounted) return;
        setState(() => _pendingCreateRevealHeld = false);
        unawaited(_syncDownloadWakelock());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapPendingCreate());
    } else {
      _startPollingTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocalSaved());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_syncDownloadWakelock()));
  }

  @override
  void dispose() {
    assert(() {
      if (kDebugMode) debugPrint("### JOB_STATUS_DEBUG ### polling dispose jobId=$_pollJobId");
      return true;
    }());
    _pendingCreateMinLoadingTimer?.cancel();
    _timer?.cancel();
    unawaited(_releaseDownloadWakelockIfHeld());
    super.dispose();
  }

  Future<void> _bootstrapPendingCreate() async {
    final req = widget.pendingCreateRequest;
    if (req == null || !mounted) return;
    assert(() {
      if (kDebugMode && widget.expiredRedownloadPriorJobId != null) {
        debugPrint(
          "expired_redownload_start priorJobId=${widget.expiredRedownloadPriorJobId} forceNew=${req.forceNew}",
        );
      }
      return true;
    }());
    final svc = AppScope.read(context).downloadService;
    downloadDebugPrint("POST /downloads (pending screen) body=${req.toJson()}");
    try {
      final res = await svc.create(req);
      downloadDebugPrint(
        "POST /downloads response selectedJobId=${res.jobId} status=${res.status} cached=${res.cached}",
      );
      assert(() {
        if (kDebugMode && widget.expiredRedownloadPriorJobId != null) {
          debugPrint(
            "expired_redownload_response priorJobId=${widget.expiredRedownloadPriorJobId} "
            "responseJobId=${res.jobId} cached=${res.cached}",
          );
          if (widget.expiredRedownloadPriorJobId == res.jobId) {
            debugPrint(
              "WARNING: expired redownload returned original expired job id "
              "(prior=${widget.expiredRedownloadPriorJobId} response=${res.jobId})",
            );
          }
        }
        return true;
      }());
      if (!mounted) return;
      setState(() {
        _resolvedJobId = res.jobId.trim();
        _err = null;
      });
      unawaited(_syncDownloadWakelock());
      if (_pollJobId.isEmpty) {
        if (!mounted) return;
        setState(() => _err = ApiError(code: "MISSING_JOB", message: "empty job id"));
        unawaited(_syncDownloadWakelock());
        return;
      }
      await AppScope.read(context).session.rememberDownloadCreateRequest(_pollJobId, req);
      _startPollingTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocalSaved());
    } catch (e, st) {
      downloadDebugPrint("catch download_status_screen._bootstrapPendingCreate type=${e.runtimeType} message=$e");
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
      downloadDebugStackTrace("download_status_screen._bootstrapPendingCreate", st);
      if (!mounted) return;
      if (e is ApiError && e.code == "CONFLICT") {
        final existingId = e.existingJobId?.trim();
        if (existingId != null && existingId.isNotEmpty) {
          assert(() {
            if (kDebugMode) {
              debugPrint("### JOB_STATUS_DEBUG ### pendingCreate CONFLICT — using existing jobId=$existingId");
            }
            return true;
          }());
          setState(() {
            _resolvedJobId = existingId;
            _err = null;
          });
          unawaited(_syncDownloadWakelock());
          _startPollingTimer();
          WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocalSaved());
          return;
        }
      }
      setState(() => _err = e is ApiError ? e : ApiError.fromUnknown(e));
      unawaited(_syncDownloadWakelock());
    }
  }

  Future<void> _refreshLocalSaved() async {
    final id = _pollJobId;
    if (id.isEmpty) return;
    final session = AppScope.read(context).session;
    final desc = await session.savedDownloadForJob(id);
    if (!mounted) return;
    setState(() {
      _localSaved = desc != null && desc.internalPath.trim().isNotEmpty;
      _localLookupDone = true;
    });
  }

  Future<void> _maybeOfferRedownloadForMissingFile(ApiError err) async {
    if (!mounted) return;
    if (!isMissingBackendBinaryError(err)) return;
    if (_expiredRedownloadOfferInFlight) return;
    final id = _pollJobId;
    if (id.isEmpty) return;
    _expiredRedownloadOfferInFlight = true;
    try {
      await showInternetDownloadExpiredSheet(
        context,
        jobId: id,
        prefetchedDetail: _detail,
      );
    } finally {
      _expiredRedownloadOfferInFlight = false;
    }
  }

  /// When the user has not saved locally yet, pull from server once (Open/Share/Save-to-device path).
  Future<bool> _ensureLocalCopyFromServerForActions() async {
    final d = _detail;
    if (d == null || d.status != "done") return false;
    if (_localSaved) return true;
    if (_fileBusy) return false;

    setState(() {
      _fileBusy = true;
      _receiveBytes = 0;
      _totalBytes = 0;
    });
    try {
      final scope = AppScope.read(context);
      await scope.files.downloadJobMedia(
        jobId: _pollJobId,
        detail: d,
        onProgress: (r, t) {
          if (!mounted) return;
          setState(() {
            _receiveBytes = r;
            _totalBytes = t;
          });
        },
      );
      if (!mounted) return false;
      await _refreshLocalSaved();
      return _localSaved;
    } catch (e, st) {
      downloadDebugPrint(
        "catch download_status_screen._ensureLocalCopyFromServerForActions type=${e.runtimeType} message=$e",
      );
      if (e is DioException) {
        downloadDebugPrint(
          "DioException dioType=${e.type} responseStatus=${e.response?.statusCode} "
          "cancelTokenCancelled=${e.requestOptions.cancelToken?.isCancelled}",
        );
      }
      downloadDebugStackTrace("download_status_screen._ensureLocalCopyFromServerForActions", st);
      if (!mounted) return false;
      if (e is ApiError && isMissingBackendBinaryError(e)) {
        await _maybeOfferRedownloadForMissingFile(e);
      } else {
        final msg =
            e is ApiError ? localizedApiErrorMessage(context.l10n, e) : "$e";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _fileBusy = false);
      unawaited(_syncDownloadWakelock());
    }
  }

  Future<void> _tickOnce() async {
    if (_polling) return;
    final id = _pollJobId;
    if (id.isEmpty) return;
    _polling = true;
    try {
      final svc = AppScope.read(context).downloadService;
      final next = await svc.detail(id);
      if (!mounted) return;
      setState(() {
        _detail = next;
        _err = null;
      });
      unawaited(_syncDownloadWakelock());
      unawaited(
        tryBackfillStoredRequestFromDetail(AppScope.read(context).session, next),
      );
      assert(() {
        if (kDebugMode) {
          debugPrint(
            "### JOB_STATUS_DEBUG ### poll tick jobId=$id "
            "status=${next.status} stage=${next.processingStage} progress=${next.progressPercent} terminal=${next.terminal}",
          );
        }
        return true;
      }());
      if (next.terminal) {
        assert(() {
          if (kDebugMode) {
            debugPrint(
              "### JOB_STATUS_DEBUG ### polling stop jobId=$id reason=terminal status=${next.status}",
            );
          }
          return true;
        }());
        _timer?.cancel();
      }
      if (next.status == "done") {
        await _refreshLocalSaved();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = e is ApiError ? e : ApiError.fromUnknown(e));
      unawaited(_syncDownloadWakelock());
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
      "pressed הורד למכשיר jobId=$_pollJobId "
      "baseUrl=${scope.session.serverUrl.trim()} finalFileUrl=${scope.api.downloadFileUrl(_pollJobId)} "
      "tokenExists=${scope.session.deviceToken.trim().isNotEmpty}",
    );
    setState(() {
      _fileBusy = true;
      _receiveBytes = 0;
      _totalBytes = 0;
    });
    unawaited(_syncDownloadWakelock());
    try {
      final files = scope.files;
      final outcome = await files.downloadJobMedia(
        jobId: _pollJobId,
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
      final displayPath = MediaExportDisplayPath.downloadsThenFolder(
          l10n, kLinkClipMediaStoreFolderName);
      final msg = outcome.mediaStorePublished == true && outcome.publicUri != null
          ? l10n.downloadSavedToDownloads(displayPath)
          : (Platform.isAndroid
              ? l10n.downloadSavedInAppOnly(displayPath)
              : l10n.downloadSavedGeneric);
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
      if (e is ApiError && isMissingBackendBinaryError(e)) {
        await _maybeOfferRedownloadForMissingFile(e);
        return;
      }
      final msg = e is ApiError ? localizedApiErrorMessage(l10n, e) : "$e";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _fileBusy = false);
      unawaited(_syncDownloadWakelock());
    }
  }

  Future<void> _openLocal() async {
    final ok = await _ensureLocalCopyFromServerForActions();
    if (!mounted || !ok) return;
    await openSavedDownload(
      context: context,
      session: AppScope.read(context).session,
      jobId: _pollJobId,
    );
  }

  Future<void> _shareLocal() async {
    final ok = await _ensureLocalCopyFromServerForActions();
    if (!mounted || !ok) return;
    await shareSavedDownload(
      context: context,
      session: AppScope.read(context).session,
      jobId: _pollJobId,
      title: _detail?.title,
    );
  }

  Future<void> _retry() async {
    final l10n = context.l10n;
    setState(() => _err = null);
    unawaited(_syncDownloadWakelock());
    if (widget.pendingCreateRequest != null && _pollJobId.isEmpty) {
      await _bootstrapPendingCreate();
      return;
    }
    try {
      await AppScope.read(context).downloadService.retry(_pollJobId);
      if (!mounted) return;
      _startPollingTimer();
      unawaited(_syncDownloadWakelock());
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiError ? localizedApiErrorMessage(l10n, e) : "$e";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  bool _showServerProgress(DownloadDetailResponse d) => !d.terminal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = _displayDetail;

    DownloadJobUiState? headlineUi;
    DownloadJobUiState? progressUi;
    if (d != null) {
      final showProg = !d.terminal;
      headlineUi = mapDownloadJobUi(
        l10n,
        jobId: d.id,
        status: d.status,
        processingStage: d.processingStage,
        progressPercent: d.progressPercent,
        requestedFormat: d.requestedFormat,
        forDoneSavedLocallyHeadline: d.status == "done" && _localLookupDone && _localSaved,
        compactProgressCard: false,
        debugLog: !showProg,
      );
      if (showProg) {
        progressUi = mapDownloadJobUi(
          l10n,
          jobId: d.id,
          status: d.status,
          processingStage: d.processingStage,
          progressPercent: d.progressPercent,
          requestedFormat: d.requestedFormat,
          compactProgressCard: false,
          debugLog: true,
        );
      }
    }

    return DecoratedBox(
      decoration: linkClipPageGradientDecoration(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LinkClipPremiumAppBar(title: Text(l10n.downloadStatusTitle)),
      body: RefreshIndicator(
        onRefresh: _tickOnce,
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_displayErr != null && d == null) ...[
              Icon(LucideIcons.triangleAlert, size: 48, color: scheme.error),
              const SizedBox(height: 10),
              Text(localizedApiErrorMessage(l10n, _displayErr!), style: theme.textTheme.titleMedium),
              const SizedBox(height: 14),
              AppPrimaryButton(label: l10n.downloadRetry, loading: false, onPressed: _retry),
            ],
            if (d == null && _displayErr == null) ...[
              InitialDownloadLoadingAnimation(
                title: l10n.downloadStatusLoadingJob,
                subtitle: l10n.downloadLoadingSubtitle,
              ),
              KeepAppOpenHint(l10n.keepAppOpenUntilDownloadFinished),
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
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: theme.brightness == Brightness.dark ? const <BoxShadow>[] : context.lcPalette.cardShadows,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: scheme.outline.withValues(alpha: theme.brightness == Brightness.dark ? 0.55 : 0.45)),
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
                              ? LinkClipNetworkThumbnail(
                                  imageUrl: d.thumbnail!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _ph(context),
                                )
                              : _ph(context),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Builder(
                        builder: (context) {
                          final split = splitVideoTitleForDisplay(d.title);
                          final headline = split.headlineTitle.trim().isEmpty ? l10n.untitledVideo : split.headlineTitle.trim();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                headline,
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              if (split.expandableDescription != null &&
                                  split.expandableDescription!.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                ExpandableDescription(text: split.expandableDescription!.trim()),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Align(
                          key: ValueKey<String>(
                            "${d.status}|${d.processingStage}|${d.progressPercent}|${d.requestedFormat}|$_localSaved|$_localLookupDone",
                          ),
                          alignment: AlignmentDirectional.centerStart,
                          child: headlineUi == null
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      headlineUi.screenHeadline,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    if ((headlineUi.screenHeadlineSubtitle ?? "").trim().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        headlineUi.screenHeadlineSubtitle!.trim(),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_showServerProgress(d)) ...[
                        DownloadProgressHeroAnimation(
                          processingStage: progressUi?.effectiveStageKey ?? (d.processingStage ?? ""),
                          status: d.status,
                          subtitle: l10n.downloadProcessingSubtitle,
                          progressPercent: d.progressPercent,
                          isTikTokReady: (d.requestedFormat ?? "").trim().toLowerCase() == "tiktok_ready",
                        ),
                        const SizedBox(height: 14),
                        if (progressUi != null) ...[
                          BrandedProgressBar(
                            indeterminate: progressUi.showIndeterminateProgress,
                            value: progressUi.showDeterminateProgress ? (progressUi.determinatePercent ?? 0) / 100.0 : null,
                            percentLabel: progressUi.showDeterminateProgress
                                ? l10n.progressPercent(progressUi.determinatePercent ?? 0)
                                : null,
                            stageLabel: progressUi.progressStageTitle,
                            stageSubtitle: progressUi.progressStageSubtitle,
                          ),
                        ],
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
                        KeepAppOpenHint(l10n.keepAppOpenUntilDownloadFinished),
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
                                      Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: context.lcPalette.successState.withValues(alpha: 0.14),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            LucideIcons.circleCheck,
                                            size: 44,
                                            color: context.lcPalette.successState,
                                          ),
                                        ),
                                      ),
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
                          ],
                          if (_fileBusy) ...[
                            BrandedProgressBar(
                              indeterminate: _totalBytes <= 0,
                              value: _totalBytes > 0 ? (_receiveBytes / _totalBytes).clamp(0.0, 1.0) : null,
                              percentLabel: _totalBytes > 0
                                  ? l10n.progressPercent(
                                      (100 * _receiveBytes / _totalBytes).clamp(0, 100).round(),
                                    )
                                  : null,
                              stageLabel: l10n.loadingSavingToDeviceDot,
                              bytesSubtitle: _totalBytes > 0 ? "${formatBytesUi(_receiveBytes)} / ${formatBytesUi(_totalBytes)}" : null,
                            ),
                            KeepAppOpenHint(l10n.keepAppOpenUntilDownloadFinished),
                            const SizedBox(height: 14),
                          ],
                          if (!_localSaved)
                            AppPrimaryButton(
                              label: l10n.downloadSaveToDevice,
                              loading: _fileBusy,
                              icon: const Icon(LucideIcons.smartphone),
                              onPressed: (_fileBusy || _expiredRedownloadOfferInFlight) ? null : _downloadToDevice,
                            ),
                          if (!_localSaved) const SizedBox(height: 10),
                          AppOutlinedButton(
                            label: l10n.downloadOpen,
                            icon: Icon(LucideIcons.externalLink, color: scheme.primary),
                            onPressed: () {
                              if (_fileBusy || _expiredRedownloadOfferInFlight) {
                                return;
                              }
                              unawaited(_openLocal());
                            },
                          ),
                          const SizedBox(height: 10),
                          AppOutlinedButton(
                            label: l10n.downloadShare,
                            icon: Icon(LucideIcons.share2, color: scheme.primary),
                            onPressed: () {
                              if (_fileBusy || _expiredRedownloadOfferInFlight) {
                                return;
                              }
                              unawaited(_shareLocal());
                            },
                          ),
                          if (downloadDetailEligibleForVideoEdit(d) ||
                              downloadDetailEligibleForAudioEdit(d)) ...[
                            const SizedBox(height: 10),
                            AppOutlinedButton(
                              label: downloadDetailIsAudioOnly(d)
                                  ? l10n.downloadCardEditAudio
                                  : l10n.downloadCardEdit,
                              icon: Icon(
                                downloadDetailIsAudioOnly(d)
                                    ? LucideIcons.audioLines
                                    : LucideIcons.scissors,
                                color: scheme.primary,
                              ),
                              onPressed: () async {
                                await launchQuickEditForJob(
                                  context,
                                  jobId: _pollJobId,
                                  serverRetentionReferenceUtc: d.createdAt,
                                  prefetchDetail: d,
                                );
                                if (!context.mounted) return;
                                await _tickOnce();
                                await _refreshLocalSaved();
                              },
                            ),
                          ],
                      ],
                    ],
                  ),
                ),
              ),
              ).animate().fadeIn(duration: 240.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _ph(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: Icon(LucideIcons.video, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
