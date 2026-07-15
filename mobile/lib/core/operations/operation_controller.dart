import "dart:async";

import "package:flutter/foundation.dart";

import "../models/download_models.dart";
import "../models/quick_edit_models.dart";
import "../network/api_client.dart";
import "../../services/download_service.dart";
import "active_operation.dart";
import "active_operation_store.dart";
import "operation_debug.dart";

/// Minimal V1 controller: persist and poll download/edit jobs by [backendJobId].
final class OperationController extends ChangeNotifier {
  OperationController({
    required ActiveOperationStore store,
    required DownloadService downloadService,
    required ApiClient api,
  })  : _store = store,
        _downloadService = downloadService,
        _api = api;

  final ActiveOperationStore _store;
  final DownloadService _downloadService;
  final ApiClient _api;

  static const Duration _downloadPollInterval = Duration(seconds: 2);
  static const Duration _editPollInterval = Duration(seconds: 1);

  ActiveOperation? _active;
  Timer? _pollTimer;
  bool _pollInFlight = false;

  DownloadDetailResponse? _lastDownloadDetail;
  EditJobDetailResponse? _lastEditDetail;

  /// Screens with a local poll timer call [pauseBackgroundPolling] on attach.
  int _foregroundPollOwners = 0;

  ActiveOperation? get active => _active;
  DownloadDetailResponse? get lastDownloadDetail => _lastDownloadDetail;
  EditJobDetailResponse? get lastEditDetail => _lastEditDetail;

  bool get hasActiveNonTerminalEdit =>
      _active?.type == OperationType.editExport && (_active?.isNonTerminal ?? false);

  bool get hasActiveNonTerminalDownload =>
      _active?.type == OperationType.sourceDownload && (_active?.isNonTerminal ?? false);

  Future<void> hydrate() async {
    _active = await _store.readAndExpireStale();
    operationDebugActive("hydrate", _active);
    notifyListeners();
  }

  Future<void> registerPendingDownloadCreate(CreateDownloadRequest req) async {
    final now = DateTime.now().toUtc();
    final op = ActiveOperation(
      localOperationId: ActiveOperationStore.newLocalOperationId(),
      type: OperationType.sourceDownload,
      status: OperationStatus.starting,
      startedAt: now,
      updatedAt: now,
      screenToRestore: "download_status",
      payload: req.toJson(),
    );
    _active = await _persist(op, event: "registerPendingDownloadCreate");
  }

  Future<void> registerDownloadJob({
    required String jobId,
    String? sourceTitle,
    String? sourceThumbnailUrl,
    Map<String, dynamic>? payload,
  }) async {
    final id = jobId.trim();
    if (id.isEmpty) return;
    final now = DateTime.now().toUtc();
    final existing = _active;
    final op = ActiveOperation(
      localOperationId: existing?.localOperationId ?? ActiveOperationStore.newLocalOperationId(),
      type: OperationType.sourceDownload,
      backendJobId: id,
      sourceTitle: sourceTitle ?? existing?.sourceTitle,
      sourceThumbnailUrl: sourceThumbnailUrl ?? existing?.sourceThumbnailUrl,
      status: OperationStatus.running,
      startedAt: existing?.startedAt ?? now,
      updatedAt: now,
      screenToRestore: "download_status",
      payload: payload ?? existing?.payload,
    );
    _active = await _persist(op, event: "registerDownloadJob");
    _maybeStartBackgroundPoll();
  }

  Future<void> attachExistingDownloadJob({
    required String jobId,
    String? sourceTitle,
    String? sourceThumbnailUrl,
    Map<String, dynamic>? payload,
  }) async {
    final id = jobId.trim();
    if (id.isEmpty) return;
    final existing = _active;
    if (existing != null &&
        existing.type == OperationType.sourceDownload &&
        existing.backendJobId == id) {
      operationDebugActive("attachExistingDownloadJob reuse", existing);
      return;
    }
    if (existing != null && existing.isNonTerminal && existing.type != OperationType.sourceDownload) {
      await clearActiveOperation();
    }
    await registerDownloadJob(
      jobId: id,
      sourceTitle: sourceTitle,
      sourceThumbnailUrl: sourceThumbnailUrl,
      payload: payload,
    );
  }

  Future<void> registerEditJob({
    required String editJobId,
    String? sourceTitle,
    String? sourceThumbnailUrl,
    required Map<String, dynamic> payload,
  }) async {
    final id = editJobId.trim();
    if (id.isEmpty) return;
    final now = DateTime.now().toUtc();
    final op = ActiveOperation(
      localOperationId: ActiveOperationStore.newLocalOperationId(),
      type: OperationType.editExport,
      backendJobId: id,
      sourceTitle: sourceTitle,
      sourceThumbnailUrl: sourceThumbnailUrl,
      status: OperationStatus.running,
      startedAt: now,
      updatedAt: now,
      screenToRestore: "edit_video",
      payload: payload,
    );
    _active = await _persist(op, event: "registerEditJob");
    _maybeStartBackgroundPoll();
  }

  Future<String?> activeDownloadJobIdMatching(CreateDownloadRequest req) async {
    await hydrate();
    final op = _active;
    if (op == null || op.type != OperationType.sourceDownload || !op.isNonTerminal) {
      return null;
    }
    if (op.hasBackendJobId) {
      return _payloadMatchesDownloadRequest(op.payload, req) ? op.backendJobId : null;
    }
    if (op.status == OperationStatus.starting) {
      return _payloadMatchesDownloadRequest(op.payload, req) ? "" : null;
    }
    return null;
  }

  bool _payloadMatchesDownloadRequest(Map<String, dynamic>? payload, CreateDownloadRequest req) {
    if (payload == null) return true;
    final url = "${payload["url"] ?? ""}".trim();
    final format = "${payload["format"] ?? ""}".trim();
    if (url.isEmpty) return true;
    return url == req.url.trim() && format == req.format.trim();
  }

  bool editPayloadMatchesSource({
    required Map<String, dynamic>? payload,
    required String sourceKind,
    String? sourceDownloadJobId,
    String? sourceUploadId,
  }) {
    if (payload == null) return false;
    if ("${payload["sourceKind"] ?? ""}" != sourceKind) return false;
    if (sourceKind == "download") {
      return "${payload["sourceDownloadJobId"] ?? ""}".trim() ==
          (sourceDownloadJobId ?? "").trim();
    }
    return "${payload["sourceUploadId"] ?? ""}".trim() ==
        (sourceUploadId ?? "").trim();
  }

  Future<void> updateFromDownloadDetail(DownloadDetailResponse detail) async {
    _lastDownloadDetail = detail;
    var op = _active;
    if (op == null || op.type != OperationType.sourceDownload) return;
    if (op.backendJobId != null && op.backendJobId != detail.id) return;

    final now = DateTime.now().toUtc();
    var status = OperationStatus.running;
    if (!detail.terminal) {
      status = OperationStatus.waitingForServer;
    } else if (detail.status == "done") {
      status = OperationStatus.success;
    } else if (detail.status == "failed") {
      status = OperationStatus.failed;
    } else if (detail.status == "canceled") {
      status = OperationStatus.cancelled;
    }

    op = op.copyWith(
      backendJobId: detail.id,
      sourceTitle: (detail.title?.trim().isNotEmpty ?? false) ? detail.title : op.sourceTitle,
      sourceThumbnailUrl: detail.thumbnail ?? op.sourceThumbnailUrl,
      status: status,
      progressPercent: detail.progressPercent,
      stage: detail.processingStage,
      errorCode: detail.status == "failed" ? (detail.error ?? "failed") : null,
      updatedAt: now,
      clearErrorCode: detail.status == "done",
    );

    if (status == OperationStatus.success) {
      _active = await _store.markSuccess(op);
    } else if (status == OperationStatus.failed) {
      _active = await _store.markFailed(op, errorCode: op.errorCode);
    } else if (status == OperationStatus.cancelled) {
      _active = await _store.markCancelled(op);
    } else {
      _active = await _store.update(op);
    }
    operationDebugActive("updateFromDownloadDetail", _active);
    notifyListeners();

    if (!op.isNonTerminal) {
      _stopBackgroundPoll();
      if (status == OperationStatus.success) {
        unawaited(_clearAfterTerminalDelay());
      }
    }
  }

  Future<void> updateFromEditDetail(EditJobDetailResponse detail) async {
    _lastEditDetail = detail;
    var op = _active;
    if (op == null || op.type != OperationType.editExport) return;
    if (op.backendJobId != null && op.backendJobId != detail.id) return;

    final now = DateTime.now().toUtc();
    OperationStatus status;
    if (detail.isTerminalDone) {
      status = OperationStatus.downloadingResult;
    } else if (detail.isTerminalFailed) {
      status = OperationStatus.failed;
    } else {
      status = OperationStatus.waitingForServer;
    }

    final payload = Map<String, dynamic>.from(op.payload ?? {});
    payload["serverStatus"] = detail.status;
    if (detail.outputFilename != null) {
      payload["outputFilename"] = detail.outputFilename;
    }

    op = op.copyWith(
      backendJobId: detail.id,
      status: status,
      progressPercent: detail.progressPercent,
      stage: detail.stage,
      errorCode: detail.errorCode,
      updatedAt: now,
      payload: payload,
      clearErrorCode: detail.isTerminalDone,
    );

    if (status == OperationStatus.failed) {
      _active = await _store.markFailed(op, errorCode: detail.errorCode);
      _stopBackgroundPoll();
    } else if (status == OperationStatus.downloadingResult) {
      _active = await _store.update(op);
      _stopBackgroundPoll();
    } else {
      _active = await _store.update(op);
    }
    operationDebugActive("updateFromEditDetail", _active);
    notifyListeners();
  }

  Future<void> markClientDownloadingResult() async {
    final op = _active;
    if (op == null || !op.isNonTerminal) return;
    final now = DateTime.now().toUtc();
    _active = await _store.update(
      op.copyWith(status: OperationStatus.downloadingResult, updatedAt: now),
    );
    notifyListeners();
  }

  Future<void> markClientSavingToDevice() async {
    final op = _active;
    if (op == null) return;
    final now = DateTime.now().toUtc();
    _active = await _store.update(
      op.copyWith(status: OperationStatus.savingToDevice, updatedAt: now),
    );
    notifyListeners();
  }

  Future<void> markSuccess() async {
    final op = _active;
    if (op == null) return;
    _active = await _store.markSuccess(op);
    operationDebugActive("markSuccess", _active);
    notifyListeners();
    _stopBackgroundPoll();
    unawaited(_clearAfterTerminalDelay());
  }

  Future<void> markFailed({String? errorCode}) async {
    final op = _active;
    if (op == null) return;
    _active = await _store.markFailed(op, errorCode: errorCode);
    operationDebugActive("markFailed", _active);
    notifyListeners();
    _stopBackgroundPoll();
    unawaited(_clearAfterTerminalDelay());
  }

  Future<void> clearActiveOperation() async {
    await _store.clear();
    _active = null;
    _lastDownloadDetail = null;
    _lastEditDetail = null;
    operationDebugPrint("clearActiveOperation");
    _stopBackgroundPoll();
    notifyListeners();
  }

  void pauseBackgroundPolling() {
    _foregroundPollOwners++;
    operationDebugPrint("pauseBackgroundPolling owners=$_foregroundPollOwners");
    _stopBackgroundPoll();
  }

  void releaseForegroundPolling() {
    if (_foregroundPollOwners > 0) _foregroundPollOwners--;
    operationDebugPrint("releaseForegroundPolling owners=$_foregroundPollOwners");
  }

  Future<void> ensureBackgroundPolling() async {
    releaseForegroundPolling();
    await hydrate();
    operationDebugPrint("ensureBackgroundPolling");
    _maybeStartBackgroundPoll();
  }

  /// Refreshes backend status once. [force] bypasses foreground-owner guard.
  Future<void> pollNow({bool force = false}) async {
    await hydrate();
    if (_active == null || !_active!.isNonTerminal) {
      operationDebugPrint("pollNow skip — no active non-terminal op");
      return;
    }
    if (!force && _foregroundPollOwners > 0) {
      operationDebugPrint("pollNow skip — foreground owner holds poll");
      return;
    }
    if (!_active!.hasBackendJobId) {
      operationDebugPrint("pollNow skip — awaiting backend jobId");
      return;
    }
    await _pollOnce(force: force);
  }

  Future<void> resumeActiveOperation() async {
    await hydrate();
    operationDebugActive("resumeActiveOperation", _active);
    if (_active == null || !_active!.isNonTerminal) return;
    await pollNow(force: true);
    if (_foregroundPollOwners == 0) {
      _maybeStartBackgroundPoll();
    }
    notifyListeners();
  }

  void _maybeStartBackgroundPoll() {
    if (_foregroundPollOwners > 0) return;
    final op = _active;
    if (op == null || !op.isNonTerminal || !op.hasBackendJobId) return;
    if (_pollTimer != null) return;

    final interval = op.type == OperationType.editExport
        ? _editPollInterval
        : _downloadPollInterval;
    operationDebugPrint(
      "backgroundPoll start type=${op.type.name} jobId=${op.backendJobId} interval=${interval.inSeconds}s",
    );
    _pollTimer = Timer.periodic(interval, (_) => unawaited(_pollOnce(force: false)));
    unawaited(_pollOnce(force: false));
  }

  void _stopBackgroundPoll() {
    if (_pollTimer != null) {
      operationDebugPrint("backgroundPoll stop");
    }
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollOnce({required bool force}) async {
    if (_pollInFlight) return;
    if (!force && _foregroundPollOwners > 0) return;
    final op = _active;
    if (op == null || !op.isNonTerminal || !op.hasBackendJobId) return;

    _pollInFlight = true;
    try {
      switch (op.type) {
        case OperationType.sourceDownload:
          final detail = await _downloadService.detail(op.backendJobId!);
          await updateFromDownloadDetail(detail);
        case OperationType.editExport:
          if (op.status == OperationStatus.downloadingResult) {
            _stopBackgroundPoll();
            return;
          }
          final detail = await _api.getEditJob(op.backendJobId!);
          await updateFromEditDetail(detail);
      }
    } catch (e) {
      operationDebugPrint(
        "pollOnce error type=${op.type.name} jobId=${op.backendJobId} ${e.runtimeType}",
      );
    } finally {
      _pollInFlight = false;
    }
  }

  Future<ActiveOperation> _persist(ActiveOperation op, {required String event}) async {
    final saved = await _store.save(op);
    operationDebugActive(event, saved);
    notifyListeners();
    return saved;
  }

  Future<void> _clearAfterTerminalDelay() async {
    await Future<void>.delayed(const Duration(hours: 24));
    final current = _active;
    if (current == null || current.isNonTerminal) return;
    await clearActiveOperation();
  }

  @override
  void dispose() {
    _stopBackgroundPoll();
    super.dispose();
  }
}
