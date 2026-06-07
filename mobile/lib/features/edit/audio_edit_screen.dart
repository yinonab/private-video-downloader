import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";
import "package:open_filex/open_filex.dart";
import "package:path/path.dart" as p;
import "package:share_plus/share_plus.dart";
import "package:video_player/video_player.dart";

import "../../core/app_scope.dart";
import "../../core/config/media_export_constants.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/models/quick_edit_models.dart";
import "../../core/widgets/linkclip_app_bar.dart";
import "../../l10n/app_localizations.dart";
import "widgets/audio_trim_editor.dart";
import "widgets/edit_done_body.dart";
import "widgets/edit_working_panel.dart";

enum _FlowPhase { composing, working, done, failed }

/// Server-side MP3 edit: trim, speed, quality → poll → download.
class AudioEditScreen extends StatefulWidget {
  const AudioEditScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<AudioEditScreen> createState() => _AudioEditScreenState();
}

class _AudioEditScreenState extends State<AudioEditScreen> {
  DownloadDetailResponse? _detail;
  String? _localPath;

  VideoPlayerController? _player;

  double _durationSec = 60;
  double _startSec = 0;
  double _endSec = 60;
  double _positionSec = 0;
  AudioEditSpeedFactor _speed = AudioEditSpeedFactor.x1;
  AudioEditQuality _quality = kAudioEditDefaultQuality;

  _FlowPhase _phase = _FlowPhase.composing;
  String? _editJobId;
  EditJobDetailResponse? _latestJob;
  Object? _lastError;
  Timer? _pollTimer;
  bool _pollBusy = false;
  String? _outputPath;
  bool _downloadingFile = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _disposePlayer();
    super.dispose();
  }

  Future<void> _disposePlayer() async {
    final c = _player;
    _player = null;
    await c?.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final scope = AppScope.read(context);
      final detail = await scope.api.downloadDetail(widget.jobId);
      final path = await scope.session.localPathForJob(widget.jobId);
      final lp = path?.trim();
      if (lp == null || lp.isEmpty || !await File(lp).exists()) {
        if (mounted) Navigator.maybePop(context);
        return;
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _localPath = lp;
        _startSec = 0;
        _endSec = _durationSec;
        _loading = false;
      });
      await _initPreview(lp);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = e;
        _phase = _FlowPhase.failed;
      });
    }
  }

  Future<void> _initPreview(String localPath) async {
    await _disposePlayer();
    try {
      final c = VideoPlayerController.file(File(localPath));
      await c.initialize();
      c.addListener(_onPlayerTick);
      if (!mounted) {
        await c.dispose();
        return;
      }
      final dur = c.value.duration.inMilliseconds / 1000.0;
      setState(() {
        _player = c;
        if (dur > 0) {
          _durationSec = dur;
          _endSec = dur;
        }
        _positionSec = 0;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _lastError = "preview_failed");
      }
    }
  }

  void _onPlayerTick() {
    final c = _player;
    if (c == null || !c.value.isInitialized || !mounted) return;
    final pos = c.value.position.inMilliseconds / 1000.0;
    final dur = c.value.duration.inMilliseconds / 1000.0;
    setState(() {
      _positionSec = pos;
      if (dur > 0 && (_durationSec <= 0 || (_durationSec - dur).abs() > 0.25)) {
        _durationSec = dur;
        if (_endSec > dur) _endSec = dur;
      }
    });
    if (pos >= _endSec - 0.05 && c.value.isPlaying) {
      unawaited(c.pause());
      unawaited(c.seekTo(Duration(milliseconds: (_startSec * 1000).round())));
    }
  }

  bool get _trimApplied {
    const eps = 0.05;
    final dur = _durationSec <= 0 ? 1.0 : _durationSec;
    return _startSec > eps || _endSec < dur - eps;
  }

  bool get _hasChanges => audioEditHasChanges(
        durationSec: _durationSec,
        trimStartSec: _startSec,
        trimEndSec: _endSec,
        speed: _speed,
        quality: _quality,
      );

  void _resetTrim() {
    setState(() {
      _startSec = 0;
      _endSec = _durationSec;
    });
  }

  Future<void> _togglePlay() async {
    final c = _player;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      if (_positionSec < _startSec || _positionSec >= _endSec - 0.05) {
        await c.seekTo(Duration(milliseconds: (_startSec * 1000).round()));
      }
      await c.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.audioEditChooseOneChange)),
      );
      return;
    }
    final ops = buildAudioEditOperations(
      durationSec: _durationSec,
      trimStartSec: _startSec,
      trimEndSec: _endSec,
      speed: _speed,
      quality: _quality,
    );
    setState(() {
      _phase = _FlowPhase.working;
      _editJobId = null;
      _latestJob = null;
      _lastError = null;
      _outputPath = null;
      _downloadingFile = false;
    });
    try {
      final created = await AppScope.read(context).api.createEditJob(
            CreateEditJobRequest.download(
              sourceDownloadJobId: widget.jobId,
              operations: ops,
            ),
          );
      final id = created.editJobId.trim();
      if (id.isEmpty) throw ApiError(code: "EDIT_FAILED", message: "missing editJobId");
      if (!mounted) return;
      setState(() => _editJobId = id);
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _FlowPhase.failed;
        _lastError = e;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollOnce());
    unawaited(_pollOnce());
  }

  Future<void> _pollOnce() async {
    final id = _editJobId;
    if (!mounted || id == null || _phase != _FlowPhase.working || _pollBusy) return;
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

  Future<bool> _verifyOutputFile(String path) async {
    final f = File(path);
    if (!await f.exists()) return false;
    final len = await f.length();
    if (len <= 0) return false;
    return path.toLowerCase().endsWith(".mp3");
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
      if (!await _verifyOutputFile(path)) {
        throw ApiError(code: "EDIT_OUTPUT_UNAVAILABLE", message: "invalid_output");
      }
      if (!mounted) return;
      final span = _endSec - _startSec;
      final outDur = (_speed.factor > 0 ? span / _speed.factor : span).round();
      await AppScope.read(context).editHistory.recordCompletedEdit(
        editJobId: id,
        localFilePath: path,
        sourceKind: "download",
        title: p.basename(path),
        completedAtIso: d.completedAt,
        sizeBytes: d.outputSizeBytes ?? await File(path).length(),
        durationSeconds: outDur,
        originalSourceTitle: _detail?.title,
        platform: _detail?.platform,
        outputMediaKind: "audio",
        audioTrimApplied: _trimApplied,
        audioSpeedFactor: _speed.factor,
        audioQualityPreset: _quality.apiPreset,
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

  String _friendlySavedPath(AppLocalizations l10n) {
    return "\u200e$kLinkClipMediaStoreFolderName > ${l10n.editsFolderName}\u200e";
  }

  Future<void> _openOutput() async {
    final path = _outputPath?.trim();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    if (path == null || !await _verifyOutputFile(path)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
      return;
    }
    try {
      final r = await OpenFilex.open(path);
      if (!mounted) return;
      if (r.type != ResultType.done) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotOpenFile)));
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
    if (path == null || !await _verifyOutputFile(path)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedCannotShareFile)));
      return;
    }
    final name = p.basename(path);
    try {
      final xf = XFile(path, mimeType: "audio/mpeg", name: name);
      final result = await Share.shareXFiles([xf]);
      if (!mounted) return;
      if (result.status == ShareResultStatus.unavailable) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.savedShareFailedHint)));
      }
    } on PlatformException {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.savedShareFailedHint)));
    }
  }

  Future<void> _saveToDownloadsFolder() async {
    if (!mounted) return;
    final path = _outputPath?.trim();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final files = AppScope.read(context).files;
    final editHistory = AppScope.read(context).editHistory;
    final displayPath = _friendlySavedPath(l10n);
    if (path == null || !await _verifyOutputFile(path)) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.editSaveFailed)));
      return;
    }
    final ok = await files.publishMp4ToAndroidDownloads(
          internalAbsolutePath: path,
          shareDisplayName: p.basename(path),
        );
    if (!mounted) return;
    final jid = _editJobId?.trim();
    if (ok && jid != null && jid.isNotEmpty) {
      await editHistory.markPublishedToPublicDownloads(jid);
    }
    final still = await File(path).exists();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok || still ? l10n.audioEditSavedLocationLine(displayPath) : l10n.editSaveFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            scheme.surfaceContainerLowest.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: LinkClipPremiumAppBar(title: Text(l10n.editAudioScreenTitle)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _phase == _FlowPhase.working
                ? _workingBody(l10n)
                : _phase == _FlowPhase.done
                    ? _doneBody(l10n)
                    : _phase == _FlowPhase.failed
                        ? _failedBody(l10n, theme, scheme)
                        : _composeBody(l10n, theme, scheme),
      ),
    );
  }

  Widget _composeBody(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    var rawTitle = (_detail?.title ?? "").trim();
    if (rawTitle.isEmpty) {
      final lp = _localPath?.trim();
      if (lp != null && lp.isNotEmpty) rawTitle = p.basename(lp);
    }
    final title = rawTitle.isEmpty ? l10n.untitledVideo : rawTitle;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _sectionCard(
                scheme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.audioEditPreviewTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 12),
                    _previewBlock(l10n, theme, scheme),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                scheme,
                child: AudioTrimEditor(
                  durationSec: _durationSec,
                  startSec: _startSec,
                  endSec: _endSec,
                  onChanged: (s, e) => setState(() {
                    _startSec = s;
                    _endSec = e;
                  }),
                  onReset: _resetTrim,
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                scheme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.audioEditSpeedAndQualityTitle,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.editSpeedSectionTitle,
                      style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AudioEditSpeedFactor.values.map((s) {
                        final selected = _speed == s;
                        final label = s == AudioEditSpeedFactor.x1
                            ? "1x"
                            : "${s.factor}x".replaceAll(".0", "");
                        return _AudioSpeedChip(
                          label: label,
                          selected: selected,
                          onTap: () => setState(() => _speed = s),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.audioEditQualityTitle,
                      style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<AudioEditQuality>(
                      segments: [
                        ButtonSegment(
                          value: AudioEditQuality.standard,
                          label: Text(l10n.audioEditQualityStandard),
                        ),
                        ButtonSegment(
                          value: AudioEditQuality.high,
                          label: Text(l10n.audioEditQualityHigh),
                        ),
                        ButtonSegment(
                          value: AudioEditQuality.best,
                          label: Text(l10n.audioEditQualityBest),
                        ),
                      ],
                      selected: {_quality},
                      onSelectionChanged: (s) {
                        if (s.isEmpty) return;
                        setState(() => _quality = s.first);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_hasChanges)
                  Text(
                    l10n.audioEditNoChangesYet,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _hasChanges ? _submit : null,
                  child: Text(l10n.audioEditCreate),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewBlock(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    final c = _player;
    final playerDur = c != null && c.value.isInitialized
        ? c.value.duration.inMilliseconds / 1000.0
        : 0.0;
    final dur = _durationSec > 0 ? _durationSec : (playerDur > 0 ? playerDur : 1.0);
    final progress = dur > 0 ? (_positionSec / dur).clamp(0.0, 1.0) : 0.0;
    final timeLine = "${formatAudioEditTimeSec(_positionSec)} / ${formatAudioEditTimeSec(dur)}";

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              LucideIcons.audioLines,
              size: 28,
              color: scheme.primary.withValues(alpha: 0.82),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        onPressed: c != null && c.value.isInitialized ? _togglePlay : null,
                        icon: Icon(
                          c?.value.isPlaying == true ? LucideIcons.pause : LucideIcons.play,
                          size: 20,
                        ),
                      ),
                      const Spacer(),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(timeLine, style: theme.textTheme.labelMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress, minHeight: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(ColorScheme scheme, {required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }

  Widget _workingBody(AppLocalizations l10n) {
    final pct = _latestJob?.progressPercent;
    if (_downloadingFile) {
      return EditWorkingPanel(
        headline: l10n.editProcessingDownloading,
        subtitle: l10n.editProcessingSubtitle,
        progressPercent: null,
        showKeepOpenHint: true,
        leadingIcon: LucideIcons.audioLines,
      );
    }
    return EditWorkingPanel(
      headline: l10n.audioEditCreatingTitle,
      subtitle: l10n.audioEditCreatingKeepOpen,
      progressPercent: pct,
      leadingIcon: LucideIcons.audioLines,
    );
  }

  Widget _doneBody(AppLocalizations l10n) {
    final savedPath = _friendlySavedPath(l10n);
    return EditDoneBody(
      title: l10n.audioEditReadyTitle,
      subtitle: "${l10n.audioEditReadySubtitle}\n\n${l10n.audioEditSavedLocationLine(savedPath)}",
      onOpen: _openOutput,
      onShare: _shareOutput,
      onSave: _saveToDownloadsFolder,
      openLabel: l10n.editExportOpen,
      shareLabel: l10n.editExportShare,
      saveLabel: l10n.editExportSave,
      doneLabel: l10n.editDoneButton,
      successIcon: LucideIcons.circleCheck,
    );
  }

  Widget _failedBody(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    final err = _lastError;
    final msg = err is ApiError
        ? localizedApiErrorMessage(l10n, err)
        : (_latestJob?.errorMessage?.trim().isNotEmpty == true
            ? _latestJob!.errorMessage!
            : l10n.audioEditFailed);
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
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center),
          const Spacer(),
          FilledButton(
            onPressed: () => setState(() {
              _phase = _FlowPhase.composing;
              _lastError = null;
            }),
            child: Text(l10n.editTryAgain),
          ),
        ],
      ),
    );
  }
}

class _AudioSpeedChip extends StatelessWidget {
  const _AudioSpeedChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final mutedBlue = scheme.primary.withValues(alpha: dark ? 0.42 : 0.72);
    final borderColor =
        selected ? mutedBlue : scheme.outline.withValues(alpha: 0.32);
    final bg = selected
        ? scheme.primary.withValues(alpha: dark ? 0.12 : 0.08)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.38 : 0.5);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: selected ? 1.2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.93),
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}
