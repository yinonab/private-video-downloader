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
import "../../core/utils/download_perf_log.dart";
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
import "../../services/file_download_service.dart";
import "../../services/saved_media_actions.dart";
import "../edit/launch_audio_edit.dart";
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
  /// Action-specific Stage B label while [_fileBusy] (save / share / open / auto-finalize).
  String? _fileBusyStageLabel;
  /// Backend done; transferring final file into local cache before showing ready.
  bool _finalizingLocal = false;
  bool _expiredRedownloadOfferInFlight = false;
  int _receiveBytes = 0;
  int _totalBytes = 0;
  bool _localSaved = false;
  /// True when a public MediaStore / Downloads URI is recorded for this job.
  bool _devicePublished = false;
  bool _localLookupDone = false;
  bool _downloadWakelockHeld = false;
  /// Wall time from job create / attach until backend `done` (perf only).
  Stopwatch? _backendWaitSw;
  bool _backendWaitLogged = false;

  bool _wantsDownloadWakelock() {
    if (_fileBusy || _finalizingLocal) return true;
    final pollId = _pollJobId;
    if (pollId.isEmpty) {
      return widget.pendingCreateRequest != null && _err == null;
    }
    final d = _detail;
    if (d == null) return true;
    // Keep awake while backend runs, or while backend-done but local file not ready yet.
    if (!d.terminal) return true;
    if (d.status == "done" && !_localSaved) return true;
    return false;
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
      _startBackendWaitTimer(reason: "open_existing_job");
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

  void _startBackendWaitTimer({String reason = "start"}) {
    // [reason] reserved for future debug; timer starts once per screen session.
    assert(() {
      if (kDebugMode && reason.isNotEmpty) {
        // no-op: keep reason referenced for call sites
      }
      return true;
    }());
    _backendWaitSw ??= Stopwatch()..start();
    _backendWaitLogged = false;
  }

  void _maybeLogBackendWaitDone(DownloadDetailResponse detail) {
    if (detail.status != "done") return;
    if (_backendWaitLogged) return;
    final sw = _backendWaitSw;
    if (sw == null) return;
    sw.stop();
    _backendWaitLogged = true;
    logMobileDownloadPerf(
      stage: "poll_until_backend_done",
      durationMs: sw.elapsedMilliseconds,
      jobId: detail.id,
      platform: detail.platform,
      quality: detail.requestedFormat,
      result: "done",
    );
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
    if (detail.status == "done") {
      _maybeLogBackendWaitDone(detail);
      assert(() {
        if (kDebugMode) {
          debugPrint(
            "### FINAL_FILE ### backend done jobId=${detail.id} — starting local ensure if needed",
          );
        }
        return true;
      }());
      unawaited(_maybeStartLocalFinalize());
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
    // Resume polling / local finalize when not fully locally ready.
    if (terminal && _localSaved && !_fileBusy && !_finalizingLocal) return;
    _polling = false;
    unawaited(_operations?.pollNow(force: true));
    if (!terminal) {
      _startPollingTimer();
    } else if (_detail?.status == "done" && !_localSaved) {
      unawaited(_maybeStartLocalFinalize());
    }
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
      _startBackendWaitTimer(reason: "reuse_existing");
      _startPollingTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocalSaved());
      return;
    }
    if (existingId == null) {
      await ops.registerPendingDownloadCreate(req);
    }
    downloadDebugPrint("POST /downloads (pending screen) body=${req.toJson()}");
    final createSw = Stopwatch()..start();
    try {
      final res = await svc.create(req);
      createSw.stop();
      logMobileDownloadPerf(
        stage: "create_job",
        durationMs: createSw.elapsedMilliseconds,
        jobId: res.jobId,
        quality: req.format,
        result: res.cached ? "cached" : "created",
      );
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
      _startBackendWaitTimer(reason: "after_create");
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
    final ok = await validateSavedDownload(session, id);
    final desc = ok ? await session.savedDownloadForJob(id) : null;
    final published =
        desc?.publicUri != null && desc!.publicUri!.trim().isNotEmpty;
    if (!mounted) return;
    setState(() {
      _localSaved = ok;
      _devicePublished = published;
      _localLookupDone = true;
    });
  }

  /// After backend `done`, pull the final file into **app cache only** (no MediaStore).
  Future<void> _maybeStartLocalFinalize() async {
    final d = _detail;
    if (d == null || d.status != "done") return;
    final jobId = _pollJobId;
    if (jobId.isEmpty) return;
    if (_finalizingLocal) return;

    final scope = AppScope.read(context);
    if (await validateSavedDownload(scope.session, jobId)) {
      if (!mounted) return;
      await _refreshLocalSaved();
      debugPrint(
        "[FinalFile] autoFinalize result=reused_cache jobId=$jobId",
      );
      return;
    }
    if (!mounted) return;

    final l10n = context.l10n;
    setState(() {
      _finalizingLocal = true;
      _fileBusy = true;
      _fileBusyStageLabel = l10n.loadingPreparingFileForUseDot;
      _receiveBytes = 0;
      _totalBytes = 0;
      _localLookupDone = true;
    });
    unawaited(_syncDownloadWakelock());
    unawaited(scope.operations.markClientDownloadingResult());
    debugPrint("[FinalFile] autoFinalize cacheOnly start jobId=$jobId");

    try {
      await scope.files.ensureLocalJobMedia(
        jobId: jobId,
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
      await _refreshLocalSaved();
      await scope.operations.markSuccess();
      debugPrint(
        "[FinalFile] autoFinalize result=downloaded_to_cache jobId=$jobId "
        "localSaved=$_localSaved devicePublished=$_devicePublished",
      );
    } catch (e, st) {
      downloadDebugPrint(
        "catch download_status_screen._maybeStartLocalFinalize type=${e.runtimeType} message=$e",
      );
      downloadDebugStackTrace("download_status_screen._maybeStartLocalFinalize", st);
      if (!mounted) return;
      if (e is ApiError && isMissingBackendBinaryError(e)) {
        await _maybeOfferRedownloadForMissingFile(e);
      } else {
        final msg =
            e is ApiError ? localizedApiErrorMessage(context.l10n, e) : "$e";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        unawaited(
          scope.operations.markFailed(errorCode: e is ApiError ? e.code : null),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _finalizingLocal = false;
          _fileBusy = false;
          _fileBusyStageLabel = null;
        });
      }
      unawaited(_syncDownloadWakelock());
    }
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

  /// Stage B actions after local ready (or join in-flight finalize).
  Future<bool> _ensureLocalCopyForAction(_LocalFileAction kind) async {
    final d = _detail;
    if (d == null || d.status != "done") return false;
    final scope = AppScope.read(context);
    final l10n = context.l10n;
    final jobId = _pollJobId;

    if (await validateSavedDownload(scope.session, jobId)) {
      if (!mounted) return false;
      await _refreshLocalSaved();
      debugPrint(
        "[FinalFile] action=$kind result=reused_cache jobId=$jobId (no transfer UI)",
      );
      return true;
    }
    if (!mounted) return false;

    debugPrint(
      "[FinalFile] action=$kind cacheMissing=true willEnsure jobId=$jobId "
      "finalizing=$_finalizingLocal fileBusy=$_fileBusy",
    );

    // Prefer joining auto-finalize / in-flight ensure rather than a second transfer.
    final owningBusyUi = !_fileBusy && !_finalizingLocal;
    if (owningBusyUi) {
      setState(() {
        _fileBusy = true;
        _fileBusyStageLabel = switch (kind) {
          // Cache ensure only — MediaStore publish has its own “saving” UI.
          _LocalFileAction.save => l10n.loadingPreparingFileForUseDot,
          _LocalFileAction.share => l10n.loadingPreparingForShareDot,
          _LocalFileAction.open => l10n.loadingPreparingForOpenDot,
        };
        _receiveBytes = 0;
        _totalBytes = 0;
      });
      unawaited(_syncDownloadWakelock());
      unawaited(scope.operations.markClientDownloadingResult());
    }

    try {
      await scope.files.ensureLocalJobMedia(
        jobId: jobId,
        detail: d,
        onProgress: (r, t) {
          if (!mounted || !owningBusyUi) return;
          setState(() {
            _receiveBytes = r;
            _totalBytes = t;
          });
        },
      );
      if (!mounted) return false;
      await _refreshLocalSaved();
      if (owningBusyUi) {
        await scope.operations.markSuccess();
      }
      return _localSaved;
    } catch (e, st) {
      downloadDebugPrint(
        "catch download_status_screen._ensureLocalCopyForAction kind=$kind "
        "type=${e.runtimeType} message=$e",
      );
      if (e is DioException) {
        downloadDebugPrint(
          "DioException dioType=${e.type} responseStatus=${e.response?.statusCode} "
          "cancelTokenCancelled=${e.requestOptions.cancelToken?.isCancelled}",
        );
      }
      downloadDebugStackTrace("download_status_screen._ensureLocalCopyForAction", st);
      if (!mounted) return false;
      if (e is ApiError && isMissingBackendBinaryError(e)) {
        await _maybeOfferRedownloadForMissingFile(e);
      } else {
        final msg =
            e is ApiError ? localizedApiErrorMessage(context.l10n, e) : "$e";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        if (owningBusyUi) {
          unawaited(
            scope.operations.markFailed(errorCode: e is ApiError ? e.code : null),
          );
        }
      }
      return false;
    } finally {
      if (owningBusyUi && mounted) {
        setState(() {
          _fileBusy = false;
          _fileBusyStageLabel = null;
        });
      }
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
        unawaited(_maybeStartLocalFinalize());
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
    debugPrint("[FinalFile] save tapped jobId=$_pollJobId");

    // Ensure app cache first (join in-flight finalize if needed) — no MediaStore yet.
    final cacheOk = await _ensureLocalCopyForAction(_LocalFileAction.save);
    if (!mounted || !cacheOk) return;

    final descBefore = await scope.session.savedDownloadForJob(_pollJobId);
    final alreadyPublished = descBefore?.publicUri != null &&
        descBefore!.publicUri!.trim().isNotEmpty;

    DownloadSaveOutcome outcome;
    if (alreadyPublished) {
      outcome = DownloadSaveOutcome(
        internalPath: descBefore.internalPath,
        publicUri: descBefore.publicUri,
        mediaStorePublished: true,
      );
      debugPrint(
        "[FinalFile] save result=already_published_to_device jobId=$_pollJobId",
      );
    } else if (Platform.isAndroid) {
      setState(() {
        _fileBusy = true;
        _fileBusyStageLabel = l10n.loadingSavingToDeviceDot;
      });
      unawaited(_syncDownloadWakelock());
      try {
        outcome = await scope.files.publishLocalJobMediaToDevice(
              jobId: _pollJobId,
            ) ??
            DownloadSaveOutcome(
              internalPath: descBefore?.internalPath ?? "",
              publicUri: null,
              mediaStorePublished: false,
            );
      } finally {
        if (mounted) {
          setState(() {
            _fileBusy = false;
            _fileBusyStageLabel = null;
          });
        }
        unawaited(_syncDownloadWakelock());
      }
    } else {
      outcome = DownloadSaveOutcome(
        internalPath: descBefore?.internalPath ?? "",
        publicUri: null,
        mediaStorePublished: false,
      );
    }

    if (!mounted) return;
    await _refreshLocalSaved();
    if (!mounted) return;
    final displayPath = MediaExportDisplayPath.downloadsThenFolder(
      l10n,
      kLinkClipMediaStoreFolderName,
    );
    final msg = outcome.mediaStorePublished && outcome.publicUri != null
        ? l10n.downloadSavedToDownloads(displayPath)
        : (Platform.isAndroid
            ? l10n.downloadSavedInAppOnly(displayPath)
            : l10n.downloadSavedGeneric);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openLocal() async {
    final sw = Stopwatch()..start();
    final ok = await _ensureLocalCopyForAction(_LocalFileAction.open);
    if (!mounted || !ok) return;
    debugPrint("[FinalFile] open result=opened_cache jobId=$_pollJobId");
    await openSavedDownload(
      context: context,
      session: AppScope.read(context).session,
      jobId: _pollJobId,
    );
    sw.stop();
    logMobileDownloadPerf(
      stage: "open",
      durationMs: sw.elapsedMilliseconds,
      jobId: _pollJobId,
      result: "opened_cache",
    );
  }

  Future<void> _shareLocal() async {
    debugPrint(
      "[FinalFile] share tapped jobId=$_pollJobId localSaved=$_localSaved "
      "devicePublished=$_devicePublished finalizing=$_finalizingLocal",
    );
    logMobileDownloadPerf(
      stage: "share_tap",
      durationMs: 0,
      jobId: _pollJobId,
      result: "user_action",
    );
    // Total includes ensure + shareSavedDownload + await Share.shareXFiles return
    // (native sheet / user interaction time after the sheet opens).
    final totalSw = Stopwatch()..start();
    final ok = await _ensureLocalCopyForAction(_LocalFileAction.share);
    if (!mounted || !ok) return;
    debugPrint("[FinalFile] share result=shared_cache jobId=$_pollJobId");
    await shareSavedDownload(
      context: context,
      session: AppScope.read(context).session,
      jobId: _pollJobId,
      title: _detail?.title,
    );
    totalSw.stop();
    logMobileDownloadPerf(
      stage: "share_total",
      durationMs: totalSw.elapsedMilliseconds,
      jobId: _pollJobId,
      result: "shared_cache_includes_native_sheet_return",
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
        forDoneSavedLocallyHeadline: d.status == "done" &&
            _localLookupDone &&
            _devicePublished,
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
    final locallyReady =
        detail.status == "done" && _localLookupDone && _localSaved;
    final finalizingLocal = detail.status == "done" &&
        _localLookupDone &&
        !_localSaved;
    final badgeLabel = _devicePublished && locallyReady
        ? l10n.downloadStatusSavedOnDeviceTitle
        : locallyReady
            ? l10n.stageDone
            : finalizingLocal
                ? l10n.downloadFinalizingLocalChip
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
        if (finalizingLocal) ...[
          const SizedBox(height: LcSpace.sm),
          Text(
            l10n.downloadFinalizingLocalHeadline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ] else if ((headlineUi?.screenHeadlineSubtitle ?? "").trim().isNotEmpty) ...[
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
        ] else if (locallyReady) ...[
          const SizedBox(height: LcSpace.sm),
          Text(
            l10n.downloadVideoReadyLocalHint,
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
    final busy = _fileBusy || _finalizingLocal || _expiredRedownloadOfferInFlight;
    final locallyReady = _localSaved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_fileBusy || _finalizingLocal) ...[
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
            stageLabel: _fileBusyStageLabel ??
                l10n.loadingPreparingFileForUseDot,
            bytesSubtitle: _totalBytes > 0
                ? "${formatBytesUi(_receiveBytes)} / ${formatBytesUi(_totalBytes)}"
                : null,
          ),
          KeepAppOpenHint(l10n.keepAppOpenUntilSaveFinished),
          const SizedBox(height: LcSpace.lg),
        ],
        // Ready actions only after local file exists.
        if (locallyReady) ...[
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
          AppOutlinedButton(
            label: l10n.downloadShare,
            icon: Icon(LucideIcons.share2, color: scheme.primary),
            onPressed: () {
              if (busy) return;
              unawaited(_shareLocal());
            },
          ),
          const SizedBox(height: LcSpace.sm),
          AppOutlinedButton(
            label: l10n.downloadSaveToDevice,
            icon: Icon(LucideIcons.smartphone, color: scheme.primary),
            onPressed: () {
              if (busy) return;
              unawaited(_downloadToDevice());
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
              onPressed: () {
                if (busy) return;
                unawaited(_openEdit());
              },
            ),
          ],
        ] else ...[
          // Still finalizing — allow Share/Open/Save to attach to the same in-flight transfer.
          AppOutlinedButton(
            label: l10n.downloadShare,
            icon: Icon(LucideIcons.share2, color: scheme.primary),
            onPressed: () {
              unawaited(_shareLocal());
            },
          ),
          const SizedBox(height: LcSpace.sm),
          AppOutlinedButton(
            label: l10n.downloadOpen,
            icon: Icon(LucideIcons.externalLink, color: scheme.primary),
            onPressed: () {
              unawaited(_openLocal());
            },
          ),
          const SizedBox(height: LcSpace.sm),
          AppOutlinedButton(
            label: l10n.downloadSaveToDevice,
            icon: Icon(LucideIcons.smartphone, color: scheme.primary),
            onPressed: () {
              unawaited(_downloadToDevice());
            },
          ),
        ],
      ],
    );
  }

  Future<void> _openEdit() async {
    final detail = _detail;
    if (detail == null) return;
    if (downloadDetailEligibleForAudioEdit(detail)) {
      await launchAudioEditForJob(
        context,
        jobId: _pollJobId,
        prefetchedDetail: detail,
      );
    } else {
      await launchQuickEditForJob(
        context,
        jobId: _pollJobId,
        serverRetentionReferenceUtc: detail.createdAt,
        prefetchDetail: detail,
      );
    }
    if (!mounted) return;
    await _tickOnce();
    await _refreshLocalSaved();
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

enum _LocalFileAction { save, open, share }
