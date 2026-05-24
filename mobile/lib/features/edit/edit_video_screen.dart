import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";
import "package:open_filex/open_filex.dart";
import "package:path/path.dart" as p;
import "package:share_plus/share_plus.dart";

import "../../core/app_scope.dart";
import "../../core/config/media_export_constants.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/l10n/media_export_display_path.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/models/quick_edit_models.dart";
import "../../core/network/api_client.dart";
import "../../core/theme/linkclip_palette.dart";
import "../../core/media/backend_media_expired.dart";
import "../../core/widgets/internet_download_expired_sheet.dart";
import "../../core/widgets/keep_app_open_hint.dart";
import "../../core/widgets/linkclip_app_bar.dart";
import "../../l10n/app_localizations.dart";
import "widgets/compression_selector.dart";
import "widgets/crop_editor.dart";
import "widgets/crop_preview_overlay.dart";
import "edit_video_source_ref.dart";
import "widgets/edit_processing_animation.dart";
import "widgets/edit_video_preview.dart";
import "widgets/edit_video_preview_source.dart";
import "quick_edit_source_expired_sheet.dart";
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
    with SingleTickerProviderStateMixin {
  static const double _kFallback = EditVideoScreen.fallbackDurationSec;

  DownloadDetailResponse? _detail;
  Object? _detailError;
  bool _detailLoading = true;

  late double _durationSec;
  double _startSec = 0;
  late double _endSec;
  QuickEditCropAspect _crop = QuickEditCropAspect.original;
  QuickEditSpeedFactor _speed = QuickEditSpeedFactor.x1;
  bool _mute = false;
  QuickEditCompressPreset _compress = QuickEditCompressPreset.original;

  _FlowPhase _phase = _FlowPhase.composing;
  Timer? _pollTimer;
  bool _pollBusy = false;

  String? _editJobId;
  EditJobDetailResponse? _latestJob;
  Object? _lastError;
  bool _downloadingFile = false;
  String? _outputPath;

  late final TabController _tabController;
  double _playbackSec = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _durationSec = widget.source.videoDurationSec ??
        widget.source.durationSeconds?.toDouble() ??
        _kFallback;
    _endSec = _durationSec;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetail());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
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
      speedFactor: _speed,
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
      if (d.isTerminalDone) {
        _pollTimer?.cancel();
        await _finalizeDownload(d);
      } else if (d.isTerminalFailed) {
        _pollTimer?.cancel();
        setState(() {
          _phase = _FlowPhase.failed;
          _lastError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _pollTimer?.cancel();
      setState(() {
        _phase = _FlowPhase.failed;
        _lastError = e;
      });
    } finally {
      _pollBusy = false;
    }
  }

  Future<void> _finalizeDownload(EditJobDetailResponse d) async {
    final id = _editJobId;
    if (!mounted || id == null) return;
    setState(() => _downloadingFile = true);
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

      await AppScope.read(context).editHistory.recordCompletedEdit(
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

      if (!mounted) return;
      setState(() {
        _outputPath = path;
        _phase = _FlowPhase.done;
        _downloadingFile = false;
      });
    } catch (e) {
      if (!mounted) return;
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
    setState(() {
      _phase = _FlowPhase.working;
      _lastError = null;
      _latestJob = null;
      _downloadingFile = false;
      _editJobId = null;
      _outputPath = null;
    });
    try {
      final ops = buildQuickEditOperations(
        videoDurationSec: _durationSec,
        trimStartSec: _startSec,
        trimEndSec: _endSec,
        cropAspect: _crop,
        speedFactor: _speed,
        mute: _mute,
        compressPreset: _compress,
      );
      final api = AppScope.read(context).api;
      final CreateEditJobResponse created;
      if (widget.source.kind == EditVideoSourceKind.download) {
        created = await api.createEditJob(
          CreateEditJobRequest.download(
            sourceDownloadJobId: widget.source.sourceDownloadJobId!,
            operations: ops,
          ),
        );
      } else {
        created = await api.createEditJob(
          CreateEditJobRequest.upload(
            sourceUploadId: widget.source.sourceUploadId!,
            operations: ops,
          ),
        );
      }
      final id = created.editJobId.trim();
      if (id.isEmpty) {
        throw ApiError(code: "EDIT_FAILED", message: "missing editJobId");
      }
      if (!mounted) return;
      setState(() => _editJobId = id);
      _startPolling();
    } catch (e) {
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
      setState(() {
        _phase = _FlowPhase.working;
        _lastError = null;
        _downloadingFile = false;
        _outputPath = null;
      });
      await _finalizeDownload(_latestJob!);
      return;
    }

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
        if (didPop) return;
        if (_phase != _FlowPhase.working || !context.mounted) return;
        final leave = await _confirmLeaveWorking(context);
        if (!context.mounted) return;
        if (leave) {
          _pollTimer?.cancel();
          Navigator.of(context).pop();
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
    final idx = _tabController.index;
    final tabs = <(int, IconData, String)>[
      (0, Icons.content_cut_rounded, l10n.editTabTrim),
      (1, Icons.speed_rounded, l10n.editTabSpeed),
      (2, Icons.aspect_ratio_rounded, l10n.editTabAspectRatio),
      (3, Icons.volume_up_rounded, l10n.editTabAudio),
      (4, Icons.high_quality_rounded, l10n.editTabCompression),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in tabs) ...[
              _EditToolChip(
                icon: t.$2,
                label: t.$3,
                selected: idx == t.$1,
                onTap: () {
                  if (_tabController.index != t.$1) {
                    _tabController.animateTo(t.$1);
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComposerBody(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final scope = AppScope.read(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final showCropOverlay =
        _tabController.index == 2 && _crop != QuickEditCropAspect.original;

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
              trimStartSec: _startSec,
              trimEndSec: _endSec,
              videoDurationSec: _durationSec,
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
            ),
            if (showCropOverlay)
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
                        onChanged: (a, b) => setState(() {
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
                        onSelected: (s) => setState(() => _speed = s),
                      ),
                    ),
                    _composerPanelShell(
                      theme,
                      scheme,
                      CropEditor(
                        selected: _crop,
                        onSelected: (c) => setState(() => _crop = c),
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
    final pct = _latestJob?.progressPercent;
    final palette = context.lcPalette;
    final headline = _downloadingFile
        ? l10n.editProcessingDownloading
        : l10n.editCreatingEdit;
    final subtitle = _downloadingFile
        ? l10n.editProcessingSubtitle
        : l10n.editCreatingEditKeepOpen;

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
            headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          if (_downloadingFile)
            KeepAppOpenHint(l10n.keepAppOpenUntilDownloadFinished),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: pct != null ? (pct.clamp(0, 100) / 100.0) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneBody(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

class _EditToolChip extends StatelessWidget {
  const _EditToolChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: selected
          ? scheme.primary.withValues(alpha: dark ? 0.18 : 0.11)
          : scheme.surfaceContainerHighest
              .withValues(alpha: dark ? 0.32 : 0.48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected
              ? scheme.primary.withValues(alpha: 0.45)
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
                    ? scheme.primary.withValues(alpha: 0.95)
                    : scheme.onSurfaceVariant.withValues(alpha: 0.82),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.95)
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
