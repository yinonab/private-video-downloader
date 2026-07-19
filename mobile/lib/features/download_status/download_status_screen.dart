import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_animate/flutter_animate.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../core/app_scope.dart";
import "../../core/operation_wakelock.dart";
import "../../core/operations/operation_controller.dart";
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
import "../../core/theme/linkclip_design_system.dart";
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
import "../../core/widgets/linkclip_chips.dart";
import "../../core/widgets/linkclip_network_thumbnail.dart";
import "../../core/media/backend_media_expired.dart";
import "../../core/widgets/internet_download_expired_sheet.dart";
import "../../core/widgets/keep_app_open_hint.dart";
import "../../l10n/app_localizations.dart";
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

class _DownloadStatusScreenState extends State<DownloadStatusScreen>
    with WidgetsBindingObserver {
  static const Duration _minimumInitialLoadingDuration = Duration(seconds: 3);

  Timer? _timer;
  Timer? _pendingCreateMinLoadingTimer;
  OperationController? _operations;
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
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_onDownloadScreenReady()));
  }

  Future<void> _onDownloadScreenReady() async {
    if (!mounted) return;
    final ops = AppScope.read(context).operations;
    _operations = ops;
    ops.addListener(_onOperationsChanged);
    ops.pauseBackgroundPolling();
    final id = _pollJobId;
    if (id.isNotEmpty) {
      await ops.attachExistingDownloadJob(
        jobId: id,
        sourceTitle: _detail?.title,
        sourceThumbnailUrl: _detail?.thumbnail,
        payload: widget.pendingCreateRequest?.toJson(),
      );
    }
    unawaited(_syncDownloadWakelock());
  }

  void _onOperationsChanged() {
    if (!mounted) return;
    final active = _operations?.active;
    final id = _pollJobId;
    if (id.isEmpty || active == null || active.backendJobId != id) return;
    final cached = _operations?.lastDownloadDetail;
    if (cached != null && cached.id == id) {
      _applyDownloadDetail(cached);
      return;
    }
    unawaited(_tickOnce(force: true));
  }

  void _applyDownloadDetail(DownloadDetailResponse detail) {
    if (!mounted || detail.id != _pollJobId) return;
    setState(() {
      _detail = detail;
      _err = null;
    });
    unawaited(_syncDownloadWakelock());
    if (detail.terminal) {
      _timer?.cancel();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUiAfterForegroundReturn();
    }
  }

  void _refreshUiAfterForegroundReturn() {
    if (!mounted) return;
    final id = _pollJobId;
    if (id.isEmpty) return;
    final terminal = _detail?.terminal ?? false;
    if (terminal && !_fileBusy) return;
    _polling = false;
    unawaited(_operations?.pollNow(force: true));
    _startPollingTimer();
    unawaited(_syncDownloadWakelock());
  }

  @override
  void dispose() {
    assert(() {
      if (kDebugMode) debugPrint("### JOB_STATUS_DEBUG ### polling dispose jobId=$_pollJobId");
      return true;
    }());
    WidgetsBinding.instance.removeObserver(this);
    _operations?.removeListener(_onOperationsChanged);
    _operations = null;
    _pendingCreateMinLoadingTimer?.cancel();
    _timer?.cancel();
    unawaited(_releaseDownloadWakelockIfHeld());
    if (mounted) {
      unawaited(AppScope.read(context).operations.ensureBackgroundPolling());
    }
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
    final ops = AppScope.read(context).operations;
    final existingId = await ops.activeDownloadJobIdMatching(req);
    if (existingId != null && existingId.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _resolvedJobId = existingId;
        _err = null;
      });
      await AppScope.read(context).session.rememberDownloadCreateRequest(existingId, req);
      unawaited(_syncDownloadWakelock());
      _startPollingTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocalSaved());
      return;
    }
    if (existingId == null) {
      await ops.registerPendingDownloadCreate(req);
    }
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
      await ops.registerDownloadJob(
        jobId: _pollJobId,
        payload: req.toJson(),
      );
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
          await ops.registerDownloadJob(
            jobId: existingId,
            payload: req.toJson(),
          );
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
    unawaited(AppScope.read(context).operations.markClientDownloadingResult());
    final operations = AppScope.read(context).operations;
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
      await operations.markSuccess();
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

  Future<void> _tickOnce({bool force = false}) async {
    if (!force && _polling) return;
    final id = _pollJobId;
    if (id.isEmpty) return;
    _polling = true;
    try {
      final svc = AppScope.read(context).downloadService;
      final next = await svc.detail(id);
      if (!mounted) return;
      _applyDownloadDetail(next);
      unawaited(AppScope.read(context).operations.updateFromDownloadDetail(next));
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
      if (next.status == "done") {
        await _refreshLocalSaved();
      }
    } catch (e) {
      if (!mounted) return;
      assert(() {
        if (kDebugMode) {
          debugPrint(
            "### JOB_STATUS_DEBUG ### poll tick error jobId=$id type=${e.runtimeType}",
          );
        }
        return true;
      }());
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
    unawaited(scope.operations.markClientDownloadingResult());
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
      await scope.operations.markSuccess();
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
      unawaited(scope.operations.markFailed(errorCode: e is ApiError ? e.code : null));
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
          onRefresh: () => _tickOnce(force: true),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final previewH =
                  (constraints.maxHeight * 0.38).clamp(220.0, 360.0);
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  LcSpace.lg,
                  LcSpace.sm,
                  LcSpace.lg,
                  LcSpace.xl,
                ),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_displayErr != null && d == null) ...[
                    const SizedBox(height: LcSpace.xl),
                    Icon(LucideIcons.triangleAlert,
                        size: 48, color: scheme.error),
                    const SizedBox(height: LcSpace.md),
                    Text(
                      localizedApiErrorMessage(l10n, _displayErr!),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: LcSpace.lg),
                    AppPrimaryButton(
                      label: l10n.downloadRetry,
                      loading: false,
                      onPressed: _retry,
                    ),
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
                      LinkClipSectionCard(
                        padding: const EdgeInsets.all(LcSpace.lg),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(LucideIcons.triangleAlert,
                                color: scheme.error, size: 22),
                            const SizedBox(width: LcSpace.md),
                            Expanded(
                              child: Text(
                                localizedApiErrorMessage(l10n, _err!),
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: scheme.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: LcSpace.lg),
                    ],
                    _buildLargePreview(context, d, previewH),
                    const SizedBox(height: LcSpace.lg),
                    _buildTitleAndStatus(
                      context,
                      l10n: l10n,
                      theme: theme,
                      scheme: scheme,
                      detail: d,
                      headlineUi: headlineUi,
                    ),
                    if (_showServerProgress(d)) ...[
                      const SizedBox(height: LcSpace.lg),
                      LinkClipSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DownloadProgressHeroAnimation(
                              processingStage: progressUi?.effectiveStageKey ??
                                  (d.processingStage ?? ""),
                              status: d.status,
                              subtitle: l10n.downloadProcessingSubtitle,
                              progressPercent: d.progressPercent,
                              isTikTokReady:
                                  (d.requestedFormat ?? "")
                                          .trim()
                                          .toLowerCase() ==
                                      "tiktok_ready",
                            ),
                            const SizedBox(height: LcSpace.lg),
                            if (progressUi != null) ...[
                              BrandedProgressBar(
                                indeterminate:
                                    progressUi.showIndeterminateProgress,
                                value: progressUi.showDeterminateProgress
                                    ? (progressUi.determinatePercent ?? 0) /
                                        100.0
                                    : null,
                                percentLabel: progressUi.showDeterminateProgress
                                    ? l10n.progressPercent(
                                        progressUi.determinatePercent ?? 0)
                                    : null,
                                stageLabel: progressUi.progressStageTitle,
                                stageSubtitle:
                                    progressUi.progressStageSubtitle,
                              ),
                            ],
                            if ((d.speedText ?? "").trim().isNotEmpty ||
                                (d.etaText ?? "").trim().isNotEmpty) ...[
                              const SizedBox(height: LcSpace.sm),
                              Wrap(
                                spacing: LcSpace.md,
                                runSpacing: LcSpace.xs,
                                children: [
                                  if ((d.speedText ?? "").trim().isNotEmpty)
                                    Text(
                                      l10n.downloadSpeed(d.speedText!.trim()),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant),
                                    ),
                                  if ((d.etaText ?? "").trim().isNotEmpty)
                                    Text(
                                      l10n.downloadEta(d.etaText!.trim()),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant),
                                    ),
                                ],
                              ),
                            ],
                            KeepAppOpenHint(
                                l10n.keepAppOpenUntilDownloadFinished),
                          ],
                        ),
                      ),
                    ],
                    if ((d.status == "failed" || d.status == "canceled") &&
                        (d.error ?? "").trim().isNotEmpty) ...[
                      const SizedBox(height: LcSpace.md),
                      Text(
                        formatDownloadJobError(l10n, d.error!),
                        style: TextStyle(color: scheme.error, height: 1.35),
                      ),
                    ],
                    if (d.status == "failed" || d.status == "canceled") ...[
                      const SizedBox(height: LcSpace.xl),
                      AppPrimaryButton(
                        label: l10n.downloadRetry,
                        loading: false,
                        onPressed: _retry,
                      ),
                    ],
                    if (d.status == "done") ...[
                      const SizedBox(height: LcSpace.xl),
                      if (!_localLookupDone)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: LcSpace.md),
                          child: BrandedLoadingPanel(compact: true),
                        )
                      else
                        _buildDoneActions(
                          context,
                          l10n: l10n,
                          scheme: scheme,
                          detail: d,
                        ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLargePreview(
    BuildContext context,
    DownloadDetailResponse d,
    double height,
  ) {
    return LinkClipMediaPreviewCard(
      height: height,
      child: d.thumbnail != null && d.thumbnail!.isNotEmpty
          ? LinkClipNetworkThumbnail(
              imageUrl: d.thumbnail!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _ph(context),
            )
          : _ph(context),
    ).animate().fadeIn(duration: 220.ms).slideY(
          begin: 0.03,
          end: 0,
          curve: Curves.easeOut,
        );
  }

  Widget _buildTitleAndStatus(
    BuildContext context, {
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme scheme,
    required DownloadDetailResponse detail,
    required DownloadJobUiState? headlineUi,
  }) {
    final split = splitVideoTitleForDisplay(detail.title);
    final headline = split.headlineTitle.trim().isEmpty
        ? l10n.untitledVideo
        : split.headlineTitle.trim();
    final saved = detail.status == "done" && _localLookupDone && _localSaved;
    final badgeLabel = saved
        ? l10n.downloadStatusSavedOnDeviceTitle
        : (headlineUi?.statusChipLabel ??
            DownloadStatusParsed.fromRaw(detail.status).hebrew);
    final platform = (detail.platform ?? "").trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: -0.2,
          ),
        ),
        if (split.expandableDescription != null &&
            split.expandableDescription!.trim().isNotEmpty) ...[
          const SizedBox(height: LcSpace.sm),
          ExpandableDescription(text: split.expandableDescription!.trim()),
        ],
        const SizedBox(height: LcSpace.md),
        Wrap(
          spacing: LcSpace.sm,
          runSpacing: LcSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            LinkClipStatusChip(
              label: badgeLabel,
              semantic: DownloadStatusParsed.fromRaw(detail.status).label,
            ),
            if (platform.isNotEmpty) LinkClipPlatformChip(label: platform),
          ],
        ),
        if ((headlineUi?.screenHeadlineSubtitle ?? "").trim().isNotEmpty) ...[
          const SizedBox(height: LcSpace.sm),
          Text(
            headlineUi!.screenHeadlineSubtitle!.trim(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ] else if (detail.status == "done" &&
            _localLookupDone &&
            !_localSaved) ...[
          const SizedBox(height: LcSpace.sm),
          Text(
            l10n.downloadVideoReadyHint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDoneActions(
    BuildContext context, {
    required AppLocalizations l10n,
    required ColorScheme scheme,
    required DownloadDetailResponse detail,
  }) {
    final canEdit = downloadDetailEligibleForVideoEdit(detail) ||
        downloadDetailEligibleForAudioEdit(detail);
    final busy = _fileBusy || _expiredRedownloadOfferInFlight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_fileBusy) ...[
          BrandedProgressBar(
            indeterminate: _totalBytes <= 0,
            value: _totalBytes > 0
                ? (_receiveBytes / _totalBytes).clamp(0.0, 1.0)
                : null,
            percentLabel: _totalBytes > 0
                ? l10n.progressPercent(
                    (100 * _receiveBytes / _totalBytes).clamp(0, 100).round(),
                  )
                : null,
            stageLabel: l10n.loadingSavingToDeviceDot,
            bytesSubtitle: _totalBytes > 0
                ? "${formatBytesUi(_receiveBytes)} / ${formatBytesUi(_totalBytes)}"
                : null,
          ),
          KeepAppOpenHint(l10n.keepAppOpenUntilDownloadFinished),
          const SizedBox(height: LcSpace.lg),
        ],
        if (!_localSaved)
          AppPrimaryButton(
            label: l10n.downloadSaveToDevice,
            loading: _fileBusy,
            icon: const Icon(LucideIcons.smartphone),
            onPressed: busy ? null : _downloadToDevice,
          )
        else
          AppPrimaryButton(
            label: l10n.downloadOpen,
            loading: false,
            icon: Icon(LucideIcons.externalLink, color: scheme.onPrimary),
            onPressed: busy
                ? null
                : () {
                    unawaited(_openLocal());
                  },
          ),
        const SizedBox(height: LcSpace.md),
        if (!_localSaved) ...[
          AppOutlinedButton(
            label: l10n.downloadOpen,
            icon: Icon(LucideIcons.externalLink, color: scheme.primary),
            onPressed: () {
              if (busy) return;
              unawaited(_openLocal());
            },
          ),
          const SizedBox(height: LcSpace.sm),
        ],
        AppOutlinedButton(
          label: l10n.downloadShare,
          icon: Icon(LucideIcons.share2, color: scheme.primary),
          onPressed: () {
            if (busy) return;
            unawaited(_shareLocal());
          },
        ),
        if (canEdit) ...[
          const SizedBox(height: LcSpace.sm),
          AppOutlinedButton(
            label: downloadDetailIsAudioOnly(detail)
                ? l10n.downloadCardEditAudio
                : l10n.downloadCardEdit,
            icon: Icon(
              downloadDetailIsAudioOnly(detail)
                  ? LucideIcons.audioLines
                  : LucideIcons.scissors,
              color: scheme.primary,
            ),
            onPressed: () async {
              await launchQuickEditForJob(
                context,
                jobId: _pollJobId,
                serverRetentionReferenceUtc: detail.createdAt,
                prefetchDetail: detail,
              );
              if (!context.mounted) return;
              await _tickOnce();
              await _refreshLocalSaved();
            },
          ),
        ],
      ],
    );
  }

  Widget _ph(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            LucideIcons.video,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
