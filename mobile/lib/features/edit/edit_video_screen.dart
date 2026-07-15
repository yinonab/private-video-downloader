import "dart:async";
import "dart:io";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";
import "package:open_filex/open_filex.dart";
import "package:path/path.dart" as p;
import "package:share_plus/share_plus.dart";

import "../../core/app_scope.dart";
import "../../core/config/media_export_constants.dart";
import "../../core/edit_history/edit_history_thumbnail_cache.dart";
import "../../core/media/media_output_preview_source.dart";
import "../../core/media/media_output_preview_thumbnail.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/media_export_display_path.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/edit/caption_look_summary.dart";
import "../../core/edit/edit_preview_state.dart";
import "../../core/edit/edit_progress_display.dart";
import "../../core/operation_wakelock.dart";
import "../../core/operations/active_operation.dart";
import "../../core/operations/operation_controller.dart";
import "../../core/models/quick_edit_models.dart";
import "caption_look_editor_screen.dart";
import "../../core/network/api_client.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/media/backend_media_expired.dart";
import "../../core/widgets/internet_download_expired_sheet.dart";
import "../../core/widgets/keep_app_open_hint.dart";
import "../../core/widgets/linkclip_app_bar.dart";
import "../../l10n/app_localizations.dart";
import "widgets/compression_selector.dart";
import "widgets/format_editor.dart";
import "widgets/crop_preview_overlay.dart";
import "edit_video_source_ref.dart";
import "widgets/edit_processing_animation.dart";
import "widgets/edit_video_preview.dart";
import "widgets/edit_video_preview_source.dart";
import "widgets/edit_preview_overlay_builder.dart";
import "quick_edit_source_expired_sheet.dart";
import "caption_draft_editor_screen.dart";
import "widgets/captions_editor_panel.dart";
import "widgets/speed_editor.dart";
import "widgets/trim_editor.dart";

enum _FlowPhase { composing, working, done, failed }

String? _firstNonEmptyTrimmed(String? a, String? b) {
  final x = a?.trim();
  if (x != null && x.isNotEmpty) return x;
  final y = b?.trim();
  if (y != null && y.isNotEmpty) return y;
  return null;
}

/// Quick Edit: compose ops → POST `/edits` → poll → download MP4.
///
/// **Phase C3:** after `ApiClient.uploadVideo`, open the editor with [EditVideoScreen.upload].
class EditVideoScreen extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables
  EditVideoScreen({
    super.key,
    required this.source,
  });

  factory EditVideoScreen.download({
    Key? key,
    required String sourceDownloadJobId,
    double? videoDurationSec,
  }) {
    return EditVideoScreen(
      key: key,
      source: EditVideoSourceRef.download(
        sourceDownloadJobId: sourceDownloadJobId,
        videoDurationSec: videoDurationSec,
      ),
    );
  }

  factory EditVideoScreen.upload({
    Key? key,
    required String sourceUploadId,
    String? localPreviewPath,
    String? title,
    String? thumbnailUrl,
    int? durationSeconds,
    int? width,
    int? height,
    double? videoDurationSec,
  }) {
    return EditVideoScreen(
      key: key,
      source: EditVideoSourceRef.upload(
        sourceUploadId: sourceUploadId,
        localPreviewPath: localPreviewPath,
        title: title,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: durationSeconds,
        width: width,
        height: height,
        videoDurationSec: videoDurationSec,
      ),
    );
  }

  final EditVideoSourceRef source;

  static const double fallbackDurationSec = 180;

  @override
  State<EditVideoScreen> createState() => _EditVideoScreenState();
}

class _EditVideoScreenState extends State<EditVideoScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _kFallback = EditVideoScreen.fallbackDurationSec;

  DownloadDetailResponse? _detail;
  Object? _detailError;
  bool _detailLoading = true;

  late double _durationSec;
  double _startSec = 0;
  late double _endSec;
  QuickEditCropAspect _crop = QuickEditCropAspect.original;
  QuickEditFormatMode _formatFitMode = QuickEditFormatMode.fill;
  QuickEditRotation _rotation = QuickEditRotation.deg0;
  QuickEditSpeedFactor _speed = QuickEditSpeedFactor.x1;
  bool _mute = false;
  QuickEditCompressPreset _compress = QuickEditCompressPreset.original;

  /// Auto captions burn-in (**V1.5**); off unless user enables.
  bool _captionsAuto = false;
  QuickEditCaptionsStylePreset _captionsStyle = QuickEditCaptionsStylePreset.cleanPro;
  QuickEditCaptionFontSize _captionsFontSize = QuickEditCaptionFontSize.extraSmall;
  QuickEditCaptionFontFamily _captionsFontFamily = QuickEditCaptionFontFamily.defaultFamily;
  QuickEditCaptionPosition _captionsPosition = QuickEditCaptionPosition.bottom;
  QuickEditCaptionColor _captionsColor = QuickEditCaptionColor.white;
  QuickEditCaptionWordHighlight _captionsWordHighlight =
      QuickEditCaptionWordHighlight.none;
  QuickEditCaptionColor? _captionsNormalTextColor;
  QuickEditCaptionColor? _captionsActiveTextColor;
  QuickEditCaptionColor? _captionsBoxColor;
  QuickEditCaptionBoxShape _captionsBoxShape = QuickEditCaptionBoxShape.pill;
  bool _captionsOutlineEnabled = false;
  QuickEditCaptionColor? _captionsOutlineColor;
  QuickEditCaptionOutlineWidth _captionsOutlineWidth =
      QuickEditCaptionOutlineWidth.medium;
  int _captionsOffsetX = 0;
  int _captionsOffsetY = 0;

  List<CaptionDraftSegment>? _captionsDraftSegments;
  bool _captionsDraftGenerating = false;
  bool _workingWakelockHeld = false;
  bool _captionDraftWakelockHeld = false;
  bool _captionsDraftRegenHint = false;

  _FlowPhase _phase = _FlowPhase.composing;
  DateTime? _workingStartedAt;
  Timer? _pollTimer;
  bool _pollBusy = false;

  String? _editJobId;
  EditJobDetailResponse? _latestJob;
  OperationController? _operations;
  Object? _lastError;
  bool _downloadingFile = false;
  String? _outputPath;
  ResolvedMediaOutputPreview? _outputPreview;

  late final TabController _tabController;
  double _playbackSec = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 6, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _durationSec = widget.source.videoDurationSec ??
        widget.source.durationSeconds?.toDouble() ??
        _kFallback;
    _endSec = _durationSec;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ops = AppScope.read(context).operations;
      _operations = ops;
      ops.addListener(_onOperationsChanged);
      ops.pauseBackgroundPolling();
      await _loadDetail();
      await _tryResumeActiveEdit();
    });
  }

  void _onOperationsChanged() {
    if (!mounted) return;
    final active = _operations?.active;
    final id = _editJobId?.trim();
    if (id == null || id.isEmpty || active == null || active.backendJobId != id) {
      return;
    }
    final cached = _operations?.lastEditDetail;
    if (cached == null || cached.id != id) return;
    if (_phase != _FlowPhase.working) return;
    setState(() => _latestJob = cached);
    if (cached.isTerminalDone && !_downloadingFile) {
      _pollTimer?.cancel();
      unawaited(_finalizeDownload(cached));
    } else if (cached.isTerminalFailed) {
      _pollTimer?.cancel();
      unawaited(_handleEditTerminalFailed(cached));
    }
  }

  Future<void> _handleEditTerminalFailed(EditJobDetailResponse d) async {
    await _endWorkingPhase();
    if (!mounted) return;
    unawaited(_operations?.markFailed(errorCode: d.errorCode));
    setState(() {
      _phase = _FlowPhase.failed;
      _lastError = null;
    });
  }

  Future<void> _tryResumeActiveEdit() async {
    if (!mounted || _phase != _FlowPhase.composing) return;
    final ops = AppScope.read(context).operations;
    final active = ops.active;
    if (active == null || active.type != OperationType.editExport) return;
    if (!ops.editPayloadMatchesSource(
      payload: active.payload,
      sourceKind: widget.source.kind.name,
      sourceDownloadJobId: widget.source.sourceDownloadJobId,
      sourceUploadId: widget.source.sourceUploadId,
    )) {
      return;
    }

    final jobId = active.backendJobId?.trim();
    if (jobId == null || jobId.isEmpty) return;

    if (active.status == OperationStatus.downloadingResult ||
        active.payload?["serverStatus"] == "done") {
      _beginWorkingPhase();
      setState(() {
        _editJobId = jobId;
        _phase = _FlowPhase.working;
        _downloadingFile = false;
      });
      ops.pauseBackgroundPolling();
      try {
        final d = await AppScope.read(context).api.getEditJob(jobId);
        if (!mounted) return;
        setState(() => _latestJob = d);
        await _finalizeDownload(d);
      } catch (e) {
        if (!mounted) return;
        await _endWorkingPhase();
        setState(() {
          _phase = _FlowPhase.failed;
          _lastError = e;
        });
        unawaited(ops.markFailed(errorCode: e is ApiError ? e.code : null));
      }
      return;
    }

    if (!active.isNonTerminal) return;

    _beginWorkingPhase();
    setState(() {
      _editJobId = jobId;
      _phase = _FlowPhase.working;
      _lastError = null;
      _downloadingFile = false;
    });
    ops.pauseBackgroundPolling();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_resumeEditAfterForeground());
  }

  Future<void> _resumeEditAfterForeground() async {
    if (!mounted) return;
    _pollBusy = false;
    if (_phase == _FlowPhase.working && (_editJobId?.trim().isNotEmpty ?? false)) {
      await _operations?.pollNow(force: true);
      final cached = _operations?.lastEditDetail;
      final id = _editJobId?.trim();
      if (cached != null && id != null && cached.id == id) {
        setState(() => _latestJob = cached);
        if (cached.isTerminalDone && !_downloadingFile) {
          _pollTimer?.cancel();
          await _finalizeDownload(cached);
          return;
        }
        if (cached.isTerminalFailed) {
          _pollTimer?.cancel();
          await _handleEditTerminalFailed(cached);
          return;
        }
      }
      _startPolling();
      return;
    }
    if (_phase == _FlowPhase.composing) {
      await _tryResumeActiveEdit();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _operations?.removeListener(_onOperationsChanged);
    _operations = null;
    _pollTimer?.cancel();
    if (_phase == _FlowPhase.working && (_editJobId?.trim().isNotEmpty ?? false)) {
      unawaited(AppScope.read(context).operations.ensureBackgroundPolling());
    }
    unawaited(_endWorkingPhase());
    unawaited(_releaseCaptionDraftWakelockIfHeld());
    _tabController.dispose();
    super.dispose();
  }

  void _beginWorkingPhase() {
    _workingStartedAt = DateTime.now();
    if (_workingWakelockHeld) return;
    _workingWakelockHeld = true;
    unawaited(OperationWakelock.acquire());
  }

  Future<void> _endWorkingPhase() async {
    _workingStartedAt = null;
    if (!_workingWakelockHeld) return;
    _workingWakelockHeld = false;
    await OperationWakelock.release();
  }

  Future<void> _releaseCaptionDraftWakelockIfHeld() async {
    if (!_captionDraftWakelockHeld) return;
    _captionDraftWakelockHeld = false;
    await OperationWakelock.release();
  }

  @override
  void didUpdateWidget(covariant EditVideoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.captionsTimelineIdentityKey != widget.source.captionsTimelineIdentityKey) {
      final had = _captionsDraftSegments != null;
      setState(() {
        _captionsDraftSegments = null;
        _captionsDraftGenerating = false;
        if (had) _captionsDraftRegenHint = true;
      });
      unawaited(_releaseCaptionDraftWakelockIfHeld());
    }
  }

  void _clearCaptionsDraftAfterTimingEdit(VoidCallback apply) {
    final hadDraft = _captionsDraftSegments != null;
    setState(() {
      apply();
      if (hadDraft) {
        _captionsDraftSegments = null;
        _captionsDraftRegenHint = true;
      }
    });
  }

  void _applyCaptionDraftWorkingCopy(List<CaptionDraftSegment> segments) {
    setState(() {
      _captionsDraftSegments = List<CaptionDraftSegment>.from(segments);
    });
  }

  Future<void> _generateCaptionsDraft() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final api = AppScope.read(context).api;
    FocusScope.of(context).unfocus();
    if (!_captionDraftWakelockHeld) {
      _captionDraftWakelockHeld = true;
      await OperationWakelock.acquire();
    }
    setState(() {
      _captionsDraftGenerating = true;
      _captionsDraftRegenHint = false;
    });
    try {
      final timingOps = buildCaptionsDraftRequestOperations(
        videoDurationSec: _durationSec,
        trimStartSec: _startSec,
        trimEndSec: _endSec,
        speedFactor: _speed,
      );
      final GenerateCaptionsDraftRequest req =
          widget.source.kind == EditVideoSourceKind.download
              ? GenerateCaptionsDraftRequest.download(
                  sourceDownloadJobId: widget.source.sourceDownloadJobId!,
                  operations: timingOps,
                )
              : GenerateCaptionsDraftRequest.upload(
                  sourceUploadId: widget.source.sourceUploadId!,
                  operations: timingOps,
                );
      final res = await api.generateCaptionsDraft(req);
      if (!mounted) return;
      if (res.segments.isEmpty) {
        setState(() {
          _captionsDraftGenerating = false;
          _captionsDraftSegments = null;
        });
        messenger.showSnackBar(SnackBar(content: Text(l10n.errorCaptionsDraftUnavailable)));
        return;
      }
      setState(() {
        _captionsDraftGenerating = false;
        _captionsDraftSegments = List<CaptionDraftSegment>.from(res.segments);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _captionsDraftGenerating = false);
      final msg = e is ApiError ? localizedApiErrorMessage(l10n, e) : l10n.errorUnexpected;
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      await _releaseCaptionDraftWakelockIfHeld();
    }
  }

  Future<void> _confirmAndRegenerateCaptionsDraft() async {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editCaptionsDraftRegenerateTitle),
        content: Text(l10n.editCaptionsDraftRegenerateBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.homeCancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface.withValues(alpha: 0.92),
              side: BorderSide(color: scheme.outline.withValues(alpha: 0.42)),
            ),
            child: Text(l10n.editCaptionsDraftRegenerateConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _generateCaptionsDraft();
  }

  Future<void> _openCaptionDraftEditor() async {
    final segments = _captionsDraftSegments;
    if (segments == null ||
        segments.isEmpty ||
        _captionsDraftRegenHint ||
        _captionsDraftGenerating) {
      return;
    }
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.88,
          minChildSize: 0.42,
          maxChildSize: 0.94,
          expand: false,
          builder: (_, scrollController) {
            return CaptionDraftEditorScreen(
              embeddedInSheet: true,
              scrollController: scrollController,
              initialSegments: segments,
              videoDurationSec: _durationSec,
              onDraftChanged: _applyCaptionDraftWorkingCopy,
            );
          },
        );
      },
    );
  }

  Future<void> _loadDetail() async {
    if (widget.source.kind == EditVideoSourceKind.upload) {
      setState(() {
        _detailLoading = false;
        _detailError = null;
        _detail = null;
        final sec = widget.source.videoDurationSec ??
            widget.source.durationSeconds?.toDouble();
        if (sec != null && sec > 0.5) {
          _durationSec = sec;
          _startSec = 0;
          _endSec = _durationSec;
        } else {
          _durationSec = _kFallback;
          _startSec = 0;
          _endSec = _durationSec;
        }
      });
      return;
    }

    setState(() {
      _detailLoading = true;
      _detailError = null;
    });
    try {
      final d = await AppScope.read(context)
          .downloadService
          .detail(widget.source.sourceDownloadJobId!);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _detailLoading = false;
        _detailError = null;
        if (widget.source.videoDurationSec == null) {
          _durationSec = _kFallback;
          _startSec = 0;
          _endSec = _durationSec;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailLoading = false;
        _detailError = e;
      });
    }
  }

  CaptionLookSnapshot get _captionLookSnapshot => captionLookSnapshotFrom(
        style: _captionsStyle,
        fontSize: _captionsFontSize,
        fontFamily: _captionsFontFamily,
        position: _captionsPosition,
        color: _captionsColor,
        wordHighlight: _captionsWordHighlight,
        offsetX: _captionsOffsetX,
        offsetY: _captionsOffsetY,
        normalTextColor: _captionsNormalTextColor,
        activeTextColor: _captionsActiveTextColor,
        boxColor: _captionsBoxColor,
        boxShape: _captionsBoxShape,
        outlineEnabled: _captionsOutlineEnabled,
        outlineColor: _captionsOutlineColor,
        outlineWidth: _captionsOutlineWidth,
      );

  void _applyCaptionLookSnapshot(CaptionLookSnapshot snapshot) {
    setState(() {
      _captionsStyle = snapshot.style;
      _captionsFontSize = snapshot.fontSize;
      _captionsFontFamily = snapshot.fontFamily;
      _captionsPosition = snapshot.position;
      _captionsColor = snapshot.color;
      _captionsWordHighlight = snapshot.wordHighlight;
      _captionsNormalTextColor = snapshot.normalTextColor;
      _captionsActiveTextColor = snapshot.activeTextColor;
      _captionsBoxColor = snapshot.boxColor;
      _captionsBoxShape = snapshot.boxShape;
      _captionsOutlineEnabled = snapshot.outlineEnabled;
      _captionsOutlineColor = snapshot.outlineColor;
      _captionsOutlineWidth = snapshot.outlineWidth;
      _captionsOffsetX = clampQuickEditCaptionOffsetX(snapshot.offsetX);
      _captionsOffsetY = clampQuickEditCaptionOffsetY(snapshot.offsetY);
    });
  }

  Future<void> _openCaptionLookEditor() async {
    final initial = captionLookSnapshotFrom(
      style: _captionsStyle,
      fontSize: _captionsFontSize,
      fontFamily: _captionsFontFamily,
      position: _captionsPosition,
      color: _captionsColor,
      wordHighlight: _captionsWordHighlight,
      offsetX: _captionsOffsetX,
      offsetY: _captionsOffsetY,
      normalTextColor: _captionsNormalTextColor,
      activeTextColor: _captionsActiveTextColor,
      boxColor: _captionsBoxColor,
      boxShape: _captionsBoxShape,
      outlineEnabled: _captionsOutlineEnabled,
      outlineColor: _captionsOutlineColor,
      outlineWidth: _captionsOutlineWidth,
    );
    final result = await Navigator.of(context).push<CaptionLookSnapshot>(
      MaterialPageRoute(
        builder: (_) => CaptionLookEditorScreen(initial: initial),
      ),
    );
    if (!mounted || result == null) return;
    _applyCaptionLookSnapshot(result);
  }

  String _captionLookStyleDetailLine(AppLocalizations l10n) {
    return buildCaptionLookStyleDetailLine(
      l10n,
      color: _captionsColor,
      wordHighlight: _captionsWordHighlight,
      fontFamily: _captionsFontFamily,
      normalTextColor: _captionsNormalTextColor,
      boxColor: _captionsBoxColor,
      boxShape: _captionsBoxShape,
    );
  }

  bool get _showDurationApproxHint {
    if (_detailLoading || _detailError != null) return false;
    if (widget.source.kind == EditVideoSourceKind.download) {
      return widget.source.videoDurationSec == null;
    }
    return widget.source.videoDurationSec == null &&
        widget.source.durationSeconds == null;
  }

  String? _resolveThumbnailUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final t = raw.trim();
    if (t.startsWith("http://") || t.startsWith("https://")) return t;
    final base = ApiClient.normalizeServerInput(
      AppScope.read(context).session.serverUrl,
    ).trimRight().replaceAll(RegExp(r"/+$"), "");
    if (t.startsWith("/")) return "$base$t";
    return t;
  }

  bool get _hasChanges {
    return quickEditHasChanges(
      videoDurationSec: _durationSec,
      trimStartSec: _startSec,
      trimEndSec: _endSec,
      cropAspect: _crop,
      formatFitMode: _formatFitMode,
      rotation: _rotation,
      speedFactor: _speed,
      captionsAutoEnabled: _captionsAuto,
      captionsStyle: _captionsStyle,
      captionsFontSize: _captionsFontSize,
      captionsFontFamily: _captionsFontFamily,
      captionsPosition: _captionsPosition,
      captionsColor: _captionsColor,
      captionsWordHighlight: _captionsWordHighlight,
      captionsOffsetX: _captionsOffsetX,
      captionsOffsetY: _captionsOffsetY,
      mute: _mute,
      compressPreset: _compress,
    );
  }

  void _resetTrim() {
    setState(() {
      _startSec = 0;
      _endSec = _durationSec;
    });
  }

  String _trimUxMessage(String raw, int maxChars) {
    final t = raw.trim();
    if (t.length <= maxChars) return t;
    return "${t.substring(0, maxChars - 1)}…";
  }

  String _messageForFailure(AppLocalizations l10n) {
    final err = _lastError;
    if (err is ApiError) return localizedApiErrorMessage(l10n, err);
    final job = _latestJob;
    if (job != null && job.isTerminalFailed) {
      final code = (job.errorCode ?? "").trim();
      final msg = (job.errorMessage ?? "").trim();
      if (code.isNotEmpty) {
        return localizedApiErrorMessage(
            l10n, ApiError(code: code, message: msg.isEmpty ? code : msg));
      }
      if (msg.isNotEmpty) return _trimUxMessage(msg, 280);
    }
    if (err != null) return l10n.errorEditFailed;
    return l10n.editFailedTitle;
  }

  Future<bool> _confirmLeaveWorking(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.editLeaveWhileProcessingTitle),
        content: Text(loc.editLeaveWhileProcessingBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.editLeaveWhileProcessingStay)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.editLeaveWhileProcessingExit)),
        ],
      ),
    );
    return result == true;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollOnce());
    _pollOnce();
  }

  Future<void> _pollOnce() async {
    final id = _editJobId;
    if (!mounted || id == null || _phase != _FlowPhase.working || _pollBusy) {
      return;
    }
    _pollBusy = true;
    try {
      final d = await AppScope.read(context).api.getEditJob(id);
      if (!mounted || _phase != _FlowPhase.working) return;
      setState(() => _latestJob = d);
      unawaited(AppScope.read(context).operations.updateFromEditDetail(d));
      if (d.isTerminalDone) {
        _pollTimer?.cancel();
        await _finalizeDownload(d);
      } else if (d.isTerminalFailed) {
        _pollTimer?.cancel();
        await _handleEditTerminalFailed(d);
      }
    } catch (e) {
      if (!mounted) return;
      assert(() {
        debugPrint(
          "### EDIT_POLL ### transient error editJobId=$id type=${e.runtimeType}",
        );
        return true;
      }());
    } finally {
      _pollBusy = false;
    }
  }

  Future<void> _finalizeDownload(EditJobDetailResponse d) async {
    final id = _editJobId;
    if (!mounted || id == null) return;
    setState(() => _downloadingFile = true);
    unawaited(AppScope.read(context).operations.markClientDownloadingResult());
    try {
      final path = await AppScope.read(context).files.downloadEditedOutput(
            editJobId: id,
            suggestedBasename: d.outputFilename,
          );
      if (!mounted) return;

      final outputBasename = p.basename(path);

      final String? originalTitleDl = widget.source.kind == EditVideoSourceKind.download
          ? _firstNonEmptyTrimmed(_detail?.title, widget.source.title)
          : null;

      final String? uploadDisplayName = widget.source.kind == EditVideoSourceKind.upload
          ? _firstNonEmptyTrimmed(
              widget.source.title,
              widget.source.localPreviewPath != null
                  ? p.basename(widget.source.localPreviewPath!)
                  : null,
            )
          : null;

      final sourceKindStr =
          widget.source.kind == EditVideoSourceKind.download ? "download" : "upload";

      final scope = AppScope.read(context);
      await scope.editHistory.recordCompletedEdit(
        editJobId: id,
        localFilePath: path,
        sourceKind: sourceKindStr,
        title: outputBasename,
        completedAtIso: d.completedAt,
        durationSeconds: widget.source.durationSeconds,
        width: widget.source.width,
        height: widget.source.height,
        originalSourceTitle: originalTitleDl,
        sourceDisplayFilename: uploadDisplayName,
        platform: widget.source.kind == EditVideoSourceKind.download ? _detail?.platform : null,
      );

      String? outputThumb;
      if (!path.toLowerCase().endsWith(".mp3")) {
        outputThumb = await generateEditHistoryThumbnailFile(
          videoPath: path,
          editJobId: id,
        );
        if (outputThumb != null && outputThumb.isNotEmpty) {
          await scope.editHistory.updateThumbnailPath(id, outputThumb);
        }
      }

      final sourceThumb = widget.source.kind == EditVideoSourceKind.download
          ? _detail?.thumbnail
          : _resolveThumbnailUrl(widget.source.thumbnailUrl);
      final outputPreview = await resolveMediaOutputPreview(
        outputThumbnailPath: outputThumb,
        outputVideoPath: path,
        sourceThumbnailUrl: sourceThumb,
      );

      if (!mounted) return;
      await _endWorkingPhase();
      if (!mounted) return;
      await AppScope.read(context).operations.markSuccess();
      setState(() {
        _outputPath = path;
        _outputPreview = outputPreview;
        _phase = _FlowPhase.done;
        _downloadingFile = false;
      });
    } catch (e) {
      if (!mounted) return;
      await _endWorkingPhase();
      if (!mounted) return;
      unawaited(AppScope.read(context).operations.markFailed(
            errorCode: e is ApiError ? e.code : null,
          ));
      final mapped = e is ApiError && isMissingBackendBinaryError(e)
          ? ApiError(
              code: "EDIT_OUTPUT_UNAVAILABLE",
              message: "missing_output",
              hebrewSummary: context.l10n.editServerOutputUnavailable,
            )
          : e;
      setState(() {
        _phase = _FlowPhase.failed;
        _lastError = mapped;
        _downloadingFile = false;
      });
    }
  }

  Future<void> _submitEdit() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (!_hasChanges) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.editChooseAtLeastOneChange)));
      return;
    }
    FocusScope.of(context).unfocus();
    final operationCtrl = AppScope.read(context).operations;
    if (operationCtrl.hasActiveNonTerminalEdit) {
      final activeId = operationCtrl.active?.backendJobId?.trim();
      if (activeId != null && activeId.isNotEmpty && activeId != _editJobId) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.operationEditAlreadyInProgress)),
        );
        return;
      }
    }
    _beginWorkingPhase();
    setState(() {
      _phase = _FlowPhase.working;
      _lastError = null;
      _latestJob = null;
      _downloadingFile = false;
      _editJobId = null;
      _outputPath = null;
      _outputPreview = null;
    });
    try {
      final editOps = buildQuickEditOperations(
        videoDurationSec: _durationSec,
        trimStartSec: _startSec,
        trimEndSec: _endSec,
        cropAspect: _crop,
        formatFitMode: _formatFitMode,
        rotation: _rotation,
        speedFactor: _speed,
        captionsAutoEnabled: _captionsAuto,
        captionsStyle: _captionsStyle,
        captionsFontSize: _captionsFontSize,
        captionsFontFamily: _captionsFontFamily,
        captionsPosition: _captionsPosition,
        captionsColor: _captionsColor,
        captionsWordHighlight: _captionsWordHighlight,
        captionsOffsetX: _captionsOffsetX,
        captionsOffsetY: _captionsOffsetY,
        captionsNormalTextColor: _captionsNormalTextColor,
        captionsActiveTextColor: _captionsActiveTextColor,
        captionsBoxColor: _captionsBoxColor,
        captionsBoxShape: _captionsBoxShape,
        captionsOutlineEnabled: _captionsOutlineEnabled,
        captionsOutlineColor: _captionsOutlineColor,
        captionsOutlineWidth: _captionsOutlineWidth,
        captionsDraftForBurn: (_captionsDraftSegments != null && _captionsDraftSegments!.isNotEmpty)
            ? _captionsDraftSegments
            : null,
        mute: _mute,
        compressPreset: _compress,
      );
      final api = AppScope.read(context).api;
      final CreateEditJobResponse created;
      if (widget.source.kind == EditVideoSourceKind.download) {
        created = await api.createEditJob(
          CreateEditJobRequest.download(
            sourceDownloadJobId: widget.source.sourceDownloadJobId!,
            operations: editOps,
          ),
        );
      } else {
        created = await api.createEditJob(
          CreateEditJobRequest.upload(
            sourceUploadId: widget.source.sourceUploadId!,
            operations: editOps,
          ),
        );
      }
      final id = created.editJobId.trim();
      if (id.isEmpty) {
        throw ApiError(code: "EDIT_FAILED", message: "missing editJobId");
      }
      if (!mounted) return;
      setState(() => _editJobId = id);
      await operationCtrl.registerEditJob(
        editJobId: id,
        sourceTitle: _firstNonEmptyTrimmed(_detail?.title, widget.source.title),
        sourceThumbnailUrl: widget.source.kind == EditVideoSourceKind.download
            ? _detail?.thumbnail
            : widget.source.thumbnailUrl,
        payload: {
          "sourceKind": widget.source.kind.name,
          if (widget.source.kind == EditVideoSourceKind.download)
            "sourceDownloadJobId": widget.source.sourceDownloadJobId,
          if (widget.source.kind == EditVideoSourceKind.upload)
            "sourceUploadId": widget.source.sourceUploadId,
        },
      );
      operationCtrl.pauseBackgroundPolling();
      _startPolling();
    } catch (e) {
      await _endWorkingPhase();
      if (_editJobId != null) {
        unawaited(operationCtrl.markFailed(errorCode: e is ApiError ? e.code : null));
      }
      if (!mounted) return;
      if (e is ApiError && e.code == "EDIT_INVALID_SOURCE") {
        if (widget.source.kind == EditVideoSourceKind.download) {
          setState(() {
            _phase = _FlowPhase.composing;
            _lastError = null;
          });
          await showQuickEditSourceExpiredSheet(
            context,
            sourceDownloadJobId: widget.source.sourceDownloadJobId!,
          );
          return;
        }
        setState(() {
          _phase = _FlowPhase.composing;
          _lastError = null;
        });
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorUploadSourceUnavailable)),
        );
        return;
      }
      if (widget.source.kind == EditVideoSourceKind.upload && e is ApiError) {
        if (isMissingUploadEditSourceError(e)) {
          setState(() {
            _phase = _FlowPhase.composing;
            _lastError = null;
          });
          await showUploadSourceExpiredDialog(context);
          return;
        }
      }
      setState(() {
        _phase = _FlowPhase.failed;
        _lastError = e;
      });
    }
  }

  Future<void> _retryFailed() async {
    final id = _editJobId?.trim();
    if (id == null || id.isEmpty) {
      setState(() {
        _phase = _FlowPhase.composing;
        _lastError = null;
      });
      return;
    }

    if (_latestJob?.isTerminalDone == true) {
      _beginWorkingPhase();
      setState(() {
        _phase = _FlowPhase.working;
        _lastError = null;
        _downloadingFile = false;
        _outputPath = null;
      });
      await _finalizeDownload(_latestJob!);
      return;
    }

    _beginWorkingPhase();
    setState(() {
      _phase = _FlowPhase.working;
      _lastError = null;
      _downloadingFile = false;
      _outputPath = null;
    });
    try {
      await AppScope.read(context).api.retryEditJob(id);
      if (!mounted) return;
      _startPolling();
    } catch (e) {
      await _endWorkingPhase();
      if (!mounted) return;
      setState(() {
        _phase = _FlowPhase.failed;
        _lastError = e;
      });
    }
  }

  Future<void> _openOutput() async {
    final path = _outputPath?.trim();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (!await f.exists()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
      return;
    }
    try {
      final r = await OpenFilex.open(path);
      if (!mounted) return;
      if (r.type != ResultType.done) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
    }
  }

  Future<void> _shareOutput() async {
    final path = _outputPath?.trim();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (path == null || path.isEmpty) return;
    final f = File(path);
    if (!await f.exists()) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.savedCannotShareFile)));
      return;
    }
    final name = p.basename(path);
    try {
      final xf = XFile(path, mimeType: "video/mp4", name: name);
      final result = await Share.shareXFiles([xf]);
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        messenger
            .showSnackBar(SnackBar(content: Text(l10n.savedShareFailedHint)));
      }
    } on PlatformException {
      if (!mounted) return;
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.savedShareFailedHint)));
    }
  }

  Future<void> _saveToDownloadsFolder() async {
    final path = _outputPath?.trim();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (path == null || path.isEmpty) return;
    final displayPath = MediaExportDisplayPath.downloadsThenFolder(
        l10n, kLinkClipMediaStoreFolderName);
    final internalFile = File(path);
    final ok = await AppScope.read(context).files.publishMp4ToAndroidDownloads(
          internalAbsolutePath: path,
          shareDisplayName: p.basename(path),
        );
    if (!mounted) return;
    final jid = _editJobId?.trim();
    if (ok && jid != null && jid.isNotEmpty) {
      await AppScope.read(context).editHistory.markPublishedToPublicDownloads(jid);
    }
    final stillOnDisk = await internalFile.exists();
    final messengerText =
        ok || stillOnDisk ? l10n.editSavedToDownloads(displayPath) : l10n.editSaveFailed;
    messenger.showSnackBar(SnackBar(content: Text(messengerText)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget body;
    switch (_phase) {
      case _FlowPhase.composing:
        body = _buildComposerBody(theme, scheme, l10n);
      case _FlowPhase.working:
        body = _buildWorkingBody(theme, scheme, l10n);
      case _FlowPhase.done:
        body = _buildDoneBody(theme, scheme, l10n);
      case _FlowPhase.failed:
        body = _buildFailedBody(theme, scheme, l10n);
    }

    return PopScope(
      canPop: _phase != _FlowPhase.working,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          await _endWorkingPhase();
          return;
        }
        if (_phase != _FlowPhase.working || !context.mounted) return;
        final leave = await _confirmLeaveWorking(context);
        if (!context.mounted) return;
        if (leave) {
          _pollTimer?.cancel();
          await _endWorkingPhase();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: DecoratedBox(
        decoration: linkClipPageGradientDecoration(context),
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          appBar: LinkClipPremiumAppBar(title: Text(l10n.editScreenTitle)),
          body: SafeArea(child: body),
        ),
      ),
    );
  }

  Widget _composerPanelShell(
      ThemeData theme, ColorScheme scheme, Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      physics: const ClampingScrollPhysics(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.34 : 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.26),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAudioMutePanel(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    return MergeSemantics(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          l10n.editMuteLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l10n.editMuteDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
        trailing: Theme(
          data: theme.copyWith(
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return scheme.onPrimary;
                }
                return scheme.outline;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return scheme.primary.withValues(alpha: 0.42);
                }
                return scheme.surfaceContainerHighest;
              }),
            ),
          ),
          child: Switch.adaptive(
            value: _mute,
            onChanged: (v) => setState(() => _mute = v),
          ),
        ),
      ),
    );
  }

  Widget _buildEditToolStrip(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final accent = context.lcPalette.tiktokAccent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: _EditorToolbarScrollLane(
        scheme: scheme,
        accent: accent,
        l10n: l10n,
        selectedTabIndex: _tabController.index,
        onSelectTab: (i) {
          if (_tabController.index != i) {
            _tabController.animateTo(i);
          }
        },
      ),
    );
  }

  Widget _buildComposerBody(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final scope = AppScope.read(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final previewState = buildEditVideoPreviewState(
      playbackSec: _playbackSec,
      activeToolTabIndex: _tabController.index,
      trimStartSec: _startSec,
      trimEndSec: _endSec,
      rotation: _rotation,
      formatMode: _formatFitMode,
      cropAspect: _crop,
      speedFactor: _speed,
      muted: _mute,
      captionsAutoEnabled: _captionsAuto,
      captionDraftSegments: _captionsDraftSegments,
      captionStyle: _captionLookSnapshot,
    );

    Widget previewStack;
    if (_detailLoading) {
      previewStack = AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: ColoredBox(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    } else if (_detailError != null) {
      previewStack = _buildPreview(context, l10n, scheme);
    } else {
      previewStack = ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.loose,
          children: [
            EditVideoPreview(
              key: ValueKey<String>(widget.source.previewIdentityKey),
              previewSource: widget.source.kind == EditVideoSourceKind.download
                  ? EditVideoPreviewDownloadSource(
                      jobId: widget.source.sourceDownloadJobId!,
                    )
                  : EditVideoPreviewUploadSource(
                      uploadId: widget.source.sourceUploadId!,
                      localPreviewPath: widget.source.localPreviewPath,
                    ),
              session: scope.session,
              apiBaseForUrl: scope.session.serverUrl,
              previewRotation: _rotation,
              trimStartSec: _startSec,
              trimEndSec: _endSec,
              videoDurationSec: _durationSec,
              playbackSpeed: previewState.playbackSpeed,
              muted: previewState.muted,
              thumbnailUrl: widget.source.kind == EditVideoSourceKind.download
                  ? _detail?.thumbnail
                  : _resolveThumbnailUrl(widget.source.thumbnailUrl),
              onDurationResolved: (sec) {
                if (!mounted || sec <= 0.5) return;
                setState(() {
                  _durationSec = sec;
                  _startSec = _startSec.clamp(0.0, sec - 0.05);
                  _endSec = _endSec.clamp(_startSec + 0.05, sec);
                });
              },
              onPlaybackSeconds: (pos) {
                if (!mounted) return;
                setState(() => _playbackSec = pos);
              },
              captionsPreviewOverlay: buildEditCaptionPreviewOverlay(
                l10n: l10n,
                state: previewState.captionOnVideo,
              ),
            ),
            if (previewState.showCropOverlay)
              Positioned.fill(
                child: CropPreviewOverlay(
                    aspect: _crop, primaryColor: scheme.primary),
              ),
          ],
        ),
      );
    }

    final previewCard = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outline.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: previewStack,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: previewCard,
              ),
              if (_showDurationApproxHint)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Text(
                    l10n.editDurationApproxHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              _buildEditToolStrip(theme, scheme, l10n),
              Expanded(
                child: IndexedStack(
                  index: _tabController.index,
                  sizing: StackFit.expand,
                  children: [
                    _composerPanelShell(
                      theme,
                      scheme,
                      TrimEditor(
                        durationSec: _durationSec,
                        startSec: _startSec,
                        endSec: _endSec,
                        playbackSec: _playbackSec,
                        onChanged: (a, b) => _clearCaptionsDraftAfterTimingEdit(() {
                          _startSec = a;
                          _endSec = b;
                        }),
                        onReset: _resetTrim,
                      ),
                    ),
                    _composerPanelShell(
                      theme,
                      scheme,
                      SpeedEditor(
                        selected: _speed,
                        onSelected: (s) =>
                            _clearCaptionsDraftAfterTimingEdit(() => _speed = s),
                      ),
                    ),
                    _composerPanelShell(
                      theme,
                      scheme,
                      FormatEditor(
                        aspect: _crop,
                        fitMode: _formatFitMode,
                        rotation: _rotation,
                        onAspectChanged: (c) => setState(() {
                          _crop = c;
                          if (c == QuickEditCropAspect.original) {
                            _formatFitMode = QuickEditFormatMode.fill;
                          }
                        }),
                        onFitModeChanged: (m) =>
                            setState(() => _formatFitMode = m),
                        onRotationChanged: (r) =>
                            setState(() => _rotation = r),
                      ),
                    ),
                    _composerPanelShell(
                      theme,
                      scheme,
                      CaptionsEditorPanel(
                        autoCaptionsEnabled: _captionsAuto,
                        effectiveCaptionPreset: inferQuickEditCaptionPreset(
                          fontSize: _captionsFontSize,
                          fontFamily: _captionsFontFamily,
                          position: _captionsPosition,
                          color: _captionsColor,
                          style: _captionsStyle,
                          wordHighlight: _captionsWordHighlight,
                          offsetX: _captionsOffsetX,
                          offsetY: _captionsOffsetY,
                          normalTextColor: _captionsNormalTextColor,
                          activeTextColor: _captionsActiveTextColor,
                          boxColor: _captionsBoxColor,
                          boxShape: _captionsBoxShape,
                        ),
                        lookStyleDetailLine: _captionLookStyleDetailLine(l10n),
                        lookColor: _captionsColor,
                        lookWordHighlight: _captionsWordHighlight,
                        lookFontFamily: _captionsFontFamily,
                        lookNormalTextColor: _captionsNormalTextColor,
                        lookActiveTextColor: _captionsActiveTextColor,
                        lookBoxColor: _captionsBoxColor,
                        lookBoxShape: _captionsBoxShape,
                        onCustomizeLook: _openCaptionLookEditor,
                        onGenerateCaptionsDraft: _generateCaptionsDraft,
                        onRegenerateCaptionsDraftRequested:
                            _confirmAndRegenerateCaptionsDraft,
                        captionDraftSegments: _captionsDraftSegments,
                        onEditCaptionsDraft: _openCaptionDraftEditor,
                        isCaptionDraftGenerating: _captionsDraftGenerating,
                        showCaptionDraftTimingStaleHint: _captionsDraftRegenHint,
                        onAutoCaptionsChanged: (v) {
                          setState(() {
                            _captionsAuto = v;
                            if (!v) {
                              _captionsOffsetX = 0;
                              _captionsOffsetY = 0;
                              _captionsWordHighlight = QuickEditCaptionWordHighlight.none;
                              _captionsNormalTextColor = null;
                              _captionsActiveTextColor = null;
                              _captionsBoxColor = null;
                              _captionsDraftSegments = null;
                              _captionsDraftRegenHint = false;
                              _captionsDraftGenerating = false;
                            }
                          });
                          if (!v) unawaited(_releaseCaptionDraftWakelockIfHeld());
                        },
                      ),
                    ),
                    _composerPanelShell(
                      theme,
                      scheme,
                      _buildAudioMutePanel(theme, scheme, l10n),
                    ),
                    _composerPanelShell(
                      theme,
                      scheme,
                      CompressionSelector(
                        selected: _compress,
                        onSelected: (p) => setState(() => _compress = p),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (keyboardInset < 8)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_hasChanges)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.editChooseAtLeastOneChange,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                        height: 1.35,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.maybePop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.onSurfaceVariant,
                          side: BorderSide(
                            color: scheme.outline.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(l10n.editExit),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _hasChanges ? _submitEdit : null,
                        style: FilledButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor:
                              scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.95),
                          backgroundColor:
                              scheme.primary.withValues(alpha: 0.88),
                          foregroundColor: scheme.onPrimary,
                        ),
                        child: Text(l10n.editCreateEdit),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWorkingBody(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final palette = context.lcPalette;
    final hasCaptions = _captionsAuto &&
        _captionsDraftSegments != null &&
        _captionsDraftSegments!.isNotEmpty;
    final display = resolveEditProgressDisplay(
      l10n: l10n,
      downloadingFile: _downloadingFile,
      hasCaptions: hasCaptions,
      job: _latestJob,
      workingStartedAt: _workingStartedAt,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.22),
                ),
                color:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: EditProcessingAnimation(
                  size: 220,
                  color: scheme.primary,
                  accentGlow: palette.loaderBubble,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            display.headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (display.subtitle != null) ...[
            Text(
              display.subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
            ),
            const SizedBox(height: 8),
          ],
          KeepAppOpenHint(l10n.keepAppOpenUntilEditFinished),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: display.progress.clamp(0.0, 1.0),
            ),
          ),
          if (display.isEstimated) ...[
            const SizedBox(height: 8),
            Text(
              l10n.editProgressEstimatedNote,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.78),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoneBody(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final preview = _outputPreview;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview != null &&
              preview.kind != MediaOutputPreviewKind.placeholder) ...[
            MediaOutputPreviewThumbnail(
              preview: preview,
              editJobId: _editJobId,
              borderRadius: BorderRadius.circular(16),
              onThumbnailGenerated: (path) {
                final id = _editJobId?.trim();
                if (id != null && id.isNotEmpty) {
                  unawaited(
                    AppScope.read(context)
                        .editHistory
                        .updateThumbnailPath(id, path),
                  );
                }
                if (mounted) {
                  setState(() {
                    _outputPreview = ResolvedMediaOutputPreview(
                      kind: MediaOutputPreviewKind.localThumbnail,
                      localThumbnailPath: path,
                    );
                  });
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          const Spacer(),
          Icon(LucideIcons.circleCheck,
              size: 56, color: scheme.primary.withValues(alpha: 0.88)),
          const SizedBox(height: 18),
          Text(
            l10n.editDoneTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.editDoneSubtitle(
              MediaExportDisplayPath.downloadsThenFolder(
                  l10n, kLinkClipMediaStoreFolderName),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _DoneExportChip(
                  icon: LucideIcons.externalLink,
                  label: l10n.editExportOpen,
                  onTap: _openOutput,
                  dense: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DoneExportChip(
                  icon: LucideIcons.share2,
                  label: l10n.editExportShare,
                  onTap: _shareOutput,
                  dense: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DoneExportChip(
                  icon: LucideIcons.download,
                  label: l10n.editExportSave,
                  onTap: _saveToDownloadsFolder,
                  dense: true,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              backgroundColor: scheme.primary.withValues(alpha: 0.88),
              foregroundColor: scheme.onPrimary,
            ),
            child: Text(l10n.editDoneButton),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedBody(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final msg = _messageForFailure(l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(LucideIcons.triangleAlert, size: 64, color: scheme.error),
          const SizedBox(height: 20),
          Text(
            l10n.editFailedTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(l10n.editExit),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _retryFailed,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(l10n.editTryAgain),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(
      BuildContext context, AppLocalizations l10n, ColorScheme scheme) {
    if (_detailLoading) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.editPreviewLoading,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_detailError != null) {
      final msg = _detailError is ApiError
          ? localizedApiErrorMessage(l10n, _detailError! as ApiError)
          : l10n.editPreviewError;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: scheme.errorContainer.withValues(alpha: 0.35),
              border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(LucideIcons.triangleAlert, color: scheme.error),
                  const SizedBox(width: 12),
                  Expanded(child: Text(msg)),
                  TextButton(
                      onPressed: _loadDetail, child: Text(l10n.homeRetry)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final thumb = _detail?.thumbnail;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: thumb != null && thumb.isNotEmpty
            ? Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _previewFallback(scheme),
              )
            : _previewFallback(scheme),
      ),
    );
  }

  Widget _previewFallback(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
      child: Center(
        child: Icon(Icons.play_circle_outline_rounded,
            size: 64, color: scheme.outline),
      ),
    );
  }
}

class _EditorToolbarScrollLane extends StatefulWidget {
  const _EditorToolbarScrollLane({
    required this.selectedTabIndex,
    required this.scheme,
    required this.l10n,
    required this.accent,
    required this.onSelectTab,
  });

  final int selectedTabIndex;
  final ColorScheme scheme;
  final AppLocalizations l10n;
  final Color accent;
  final ValueChanged<int> onSelectTab;

  @override
  State<_EditorToolbarScrollLane> createState() =>
      _EditorToolbarScrollLaneState();
}

class _EditorToolbarScrollLaneState extends State<_EditorToolbarScrollLane> {
  final ScrollController _scroll = ScrollController();

  static const double _laneH = 44;
  static const double _inlinePad = 40;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scroll.removeListener(_sync);
    _scroll.dispose();
    super.dispose();
  }

  void _nudgeTowardMaxExtent(bool forward) {
    if (!_scroll.hasClients) return;
    final vw = math.max(MediaQuery.sizeOf(context).width, 260);
    final step = math.min(148.0, math.max(88.0, vw * 0.32));
    final p = _scroll.position;
    final targetRaw = forward ? p.pixels + step : p.pixels - step;
    final target =
        math.min(math.max(targetRaw, p.minScrollExtent), p.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 218),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _pastStart =>
      _scroll.hasClients &&
      (_scroll.offset - _scroll.position.minScrollExtent > 2);
  bool get _beforeEnd =>
      _scroll.hasClients &&
      (_scroll.position.maxScrollExtent - _scroll.offset > 2);

  @override
  Widget build(BuildContext context) {
    final rtl =
        Directionality.of(context) == TextDirection.rtl;
    /** Min scroll = “physical start” chips; semantics stay “previous / more”. */
    final iconPrev =
        rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded;
    final iconNext =
        rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Color fadeWall = Theme.of(context).colorScheme.surface;
    fadeWall = fadeWall.withValues(alpha: dark ? 0.99 : 0.995);

    final tabs = <(int, IconData, String)>[
      (
        0,
        Icons.content_cut_rounded,
        widget.l10n.editTabTrim,
      ),
      (1, Icons.speed_rounded, widget.l10n.editTabSpeed),
      (2, Icons.aspect_ratio_rounded, widget.l10n.editTabAspectRatio),
      (
        3,
        Icons.closed_caption_rounded,
        widget.l10n.editTabCaptions,
      ),
      (
        4,
        Icons.volume_up_rounded,
        widget.l10n.editTabAudio,
      ),
      (
        5,
        Icons.high_quality_rounded,
        widget.l10n.editTabCompression,
      ),
    ];

    final double arrowTop = (_laneH - _ToolbarLaneArrowChip.kSize) / 2;

    return SizedBox(
      height: _laneH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _inlinePad,
                end: _inlinePad,
              ),
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (_, __) {
                  return NotificationListener<ScrollMetricsNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _sync());
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.hardEdge,
                      child: Row(
                        children: [
                          for (final t in tabs) ...[
                            _EditToolChip(
                              icon: t.$2,
                              label: t.$3,
                              selected: widget.selectedTabIndex == t.$1,
                              accentColor: widget.accent,
                              onTap: () => widget.onSelectTab(t.$1),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          /** Gutter fades (ignore pointer — chips remain tappable underneath). */
          if (_pastStart)
            PositionedDirectional(
              start: 0,
              width: _inlinePad,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [fadeWall, fadeWall.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          if (_beforeEnd)
            PositionedDirectional(
              end: 0,
              width: _inlinePad,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerEnd,
                      end: AlignmentDirectional.centerStart,
                      colors: [fadeWall, fadeWall.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          if (_pastStart)
            PositionedDirectional(
              start: 8,
              top: arrowTop,
              child: Semantics(
                label: widget.l10n.editToolbarPreviousTools,
                button: true,
                child: _ToolbarLaneArrowChip(
                  icon: iconPrev,
                  accent: widget.accent,
                  scheme: widget.scheme,
                  onTap: () => _nudgeTowardMaxExtent(false),
                ),
              ),
            ),
          if (_beforeEnd)
            PositionedDirectional(
              end: 8,
              top: arrowTop,
              child: Semantics(
                label: widget.l10n.editToolbarMoreTools,
                button: true,
                child: _ToolbarLaneArrowChip(
                  icon: iconNext,
                  accent: widget.accent,
                  scheme: widget.scheme,
                  onTap: () => _nudgeTowardMaxExtent(true),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarLaneArrowChip extends StatelessWidget {
  const _ToolbarLaneArrowChip({
    required this.icon,
    required this.accent,
    required this.scheme,
    required this.onTap,
  });

  static const double kSize = 29;

  final IconData icon;
  final Color accent;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final fill = scheme.surface.withValues(alpha: dark ? 0.86 : 0.9);
    final borderSide = accent.withValues(alpha: dark ? 0.21 : 0.17);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashColor: accent.withValues(alpha: 0.1),
        child: Ink(
          width: kSize,
          height: kSize,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: borderSide, width: 1),
          ),
          child: Icon(
            icon,
            size: 17,
            color: scheme.onSurface.withValues(alpha: 0.52),
          ),
        ),
      ),
    );
  }
}

class _EditToolChip extends StatelessWidget {
  const _EditToolChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: selected
          ? accentColor.withValues(alpha: dark ? 0.18 : 0.11)
          : scheme.surfaceContainerHighest
              .withValues(alpha: dark ? 0.32 : 0.48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected
              ? accentColor.withValues(alpha: 0.45)
              : scheme.outline.withValues(alpha: 0.28),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? accentColor.withValues(alpha: 0.95)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.82),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? accentColor.withValues(alpha: 0.96)
                      : scheme.onSurface.withValues(alpha: 0.84),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoneExportChip extends StatelessWidget {
  const _DoneExportChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color:
          scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.42 : 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: dense ? 9 : 11, horizontal: dense ? 4 : 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: dense ? 17 : 19,
                  color: scheme.onSurface.withValues(alpha: 0.82)),
              SizedBox(height: dense ? 5 : 7),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w600,
                      height: 1.05,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
