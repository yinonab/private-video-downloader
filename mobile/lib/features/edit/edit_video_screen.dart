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
import "../../core/widgets/app_button.dart";
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
import "widgets/trim_editor.dart";

enum _FlowPhase { composing, working, done, failed }

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
    _tabController = TabController(length: 4, vsync: this)
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

  String _localizedStage(AppLocalizations l10n, String? stage) {
    switch ((stage ?? "").trim().toLowerCase()) {
      case "queued":
      case "running":
        return l10n.editStageQueued;
      case "validating_source":
      case "validating":
        return l10n.editStageValidating;
      case "probing":
        return l10n.editStageProbing;
      case "processing":
        return l10n.editStageProcessing;
      case "finalizing":
        return l10n.editStageFinalizing;
      case "done":
        return l10n.editStageDone;
      case "failed":
        return l10n.editStageFailed;
      default:
        return l10n.editStageQueued;
    }
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
      setState(() {
        _outputPath = path;
        _phase = _FlowPhase.done;
        _downloadingFile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _FlowPhase.failed;
        _lastError = e;
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
        const uploadMissing = <String>{
          "EDIT_UPLOAD_NOT_FOUND",
          "EDIT_SOURCE_FILE_MISSING",
          "UPLOAD_NOT_FOUND",
        };
        if (uploadMissing.contains(e.code)) {
          setState(() {
            _phase = _FlowPhase.composing;
            _lastError = null;
          });
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.errorUploadSourceUnavailable)),
          );
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

  Widget _buildEditTabSelector(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final idx = _tabController.index;
    final tabs = <(int, IconData, String)>[
      (0, Icons.content_cut_rounded, l10n.editTabTrim),
      (1, Icons.aspect_ratio_rounded, l10n.editTabAspectRatio),
      (2, Icons.compress_rounded, l10n.editTabCompression),
      (3, Icons.volume_up_rounded, l10n.editTabAudio),
    ];
    const spacing = 10.0;
    const tileHeight = 74.0;

    Widget tile((int, IconData, String) item) {
      final i = item.$1;
      final icon = item.$2;
      final label = item.$3;
      final sel = idx == i;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_tabController.index != i) _tabController.animateTo(i);
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: sel
                  ? scheme.primary.withValues(alpha: 0.26)
                  : scheme.surfaceContainerHighest.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.38 : 0.72),
              border: Border.all(
                color: sel
                    ? scheme.primary
                    : scheme.outline.withValues(alpha: 0.42),
                width: sel ? 2.5 : 1,
              ),
            ),
            child: SizedBox(
              height: tileHeight,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: sel ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: sel ? scheme.primary : scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.42 : 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.outline.withValues(alpha: 0.38),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, c) {
              final tileW = (c.maxWidth - spacing) / 2;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SizedBox(width: tileW, child: tile(tabs[0])),
                      SizedBox(width: spacing),
                      SizedBox(width: tileW, child: tile(tabs[1])),
                    ],
                  ),
                  SizedBox(height: spacing),
                  Row(
                    children: [
                      SizedBox(width: tileW, child: tile(tabs[2])),
                      SizedBox(width: spacing),
                      SizedBox(width: tileW, child: tile(tabs[3])),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildComposerBody(
      ThemeData theme, ColorScheme scheme, AppLocalizations l10n) {
    final scope = AppScope.read(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final showCropOverlay =
        _tabController.index == 1 && _crop != QuickEditCropAspect.original;

    Widget previewStack;
    if (_detailLoading) {
      previewStack = AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
        borderRadius: BorderRadius.circular(24),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outline.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.48 : 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.14),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: previewCard,
              ),
              if (_showDurationApproxHint)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    l10n.editDurationApproxHint,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              _buildEditTabSelector(theme, scheme, l10n),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: TrimEditor(
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
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: CropEditor(
                        selected: _crop,
                        onSelected: (c) => setState(() => _crop = c),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: CompressionSelector(
                        selected: _compress,
                        onSelected: (p) => setState(() => _compress = p),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.editTabAudio,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.editMuteDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant, height: 1.35),
                          ),
                          const SizedBox(height: 18),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              l10n.editMuteLabel,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            value: _mute,
                            onChanged: (v) => setState(() => _mute = v),
                          ),
                        ],
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
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      l10n.editChooseAtLeastOneChange,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
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
                      child: PremiumGradientCta(
                        label: l10n.editSave,
                        icon: const Icon(Icons.save_rounded),
                        onPressed: _hasChanges ? _submitEdit : null,
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
        : _localizedStage(l10n, _latestJob?.stage);
    final subtitle = _downloadingFile
        ? l10n.editProcessingSubtitle
        : l10n.editProcessingServerSubtitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: EditProcessingAnimation(
              size: 280,
              color: scheme.primary,
              accentGlow: palette.loaderBubble,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 18),
          if (!_downloadingFile)
            Text(
              "${l10n.editProcessingDontClose}\n${l10n.editProcessingSecondsHint}",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
            ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(LucideIcons.circleCheck, size: 72, color: scheme.primary),
          const SizedBox(height: 22),
          Text(
            l10n.editDoneTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.editDoneSubtitle(
              MediaExportDisplayPath.downloadsThenFolder(
                  l10n, kLinkClipMediaStoreFolderName),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 36),
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
              const SizedBox(width: 10),
              Expanded(
                child: _DoneExportChip(
                  icon: LucideIcons.share2,
                  label: l10n.editExportShare,
                  onTap: _shareOutput,
                  dense: true,
                ),
              ),
              const SizedBox(width: 10),
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
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: Text(l10n.homeContinue),
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
      color: scheme.primaryContainer.withValues(alpha: dark ? 0.35 : 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: dense ? 10 : 12, horizontal: dense ? 4 : 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: dense ? 18 : 20, color: scheme.primary),
              SizedBox(height: dense ? 6 : 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
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
