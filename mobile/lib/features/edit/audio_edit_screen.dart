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
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/api_error.dart";
import "../../core/models/download_models.dart";
import "../../core/models/quick_edit_models.dart";
import "../../core/widgets/keep_app_open_hint.dart";
import "../../core/widgets/linkclip_app_bar.dart";
import "../../l10n/app_localizations.dart";
import "launch_audio_download.dart";

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
  bool _loading = true;

  VideoPlayerController? _player;
  bool _previewError = false;

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
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _localPath = path;
        _startSec = 0;
        _endSec = _durationSec;
        _loading = false;
      });
      await _initPreview(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _lastError = e;
      });
    }
  }

  Future<void> _initPreview(String? localPath) async {
    await _disposePlayer();
    final lp = localPath?.trim();
    if (lp == null || lp.isEmpty || !await File(lp).exists()) {
      if (mounted) setState(() => _previewError = true);
      return;
    }
    try {
      final c = VideoPlayerController.file(File(lp));
      await c.initialize();
      c.addListener(_onPlayerTick);
      if (!mounted) {
        await c.dispose();
        return;
      }
      final dur = c.value.duration.inMilliseconds / 1000.0;
      setState(() {
        _player = c;
        _previewError = false;
        if (dur > 0.5) {
          _durationSec = dur;
          _endSec = dur;
        }
        _positionSec = 0;
      });
    } catch (_) {
      if (mounted) setState(() => _previewError = true);
    }
  }

  void _onPlayerTick() {
    final c = _player;
    if (c == null || !c.value.isInitialized || !mounted) return;
    final pos = c.value.position.inMilliseconds / 1000.0;
    final dur = c.value.duration.inMilliseconds / 1000.0;
    setState(() {
      _positionSec = pos;
      if (dur > 0.5 && (_durationSec - dur).abs() > 0.25) {
        _durationSec = dur;
        if (_endSec > dur) _endSec = dur;
      }
    });
    if (pos >= _endSec - 0.05 && c.value.isPlaying) {
      unawaited(c.pause());
      unawaited(c.seekTo(Duration(milliseconds: (_startSec * 1000).round())));
    }
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

  void _nudgeTrimStart(double delta) {
    setState(() {
      _startSec = (_startSec + delta).clamp(0.0, _endSec - kAudioEditMinTrimSpanSec);
    });
  }

  void _nudgeTrimEnd(double delta) {
    setState(() {
      _endSec = (_endSec + delta).clamp(_startSec + kAudioEditMinTrimSpanSec, _durationSec);
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
    if (ops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.audioEditChooseOneChange)),
      );
      return;
    }
    setState(() {
      _phase = _FlowPhase.working;
      _editJobId = null;
      _latestJob = null;
      _lastError = null;
      _outputPath = null;
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
      if (e is ApiError &&
          (e.code == "EDIT_INVALID_SOURCE" || e.code == "EDIT_AUDIO_INVALID_SOURCE")) {
        await launchAudioDownloadForJob(context, jobId: widget.jobId);
        if (mounted) Navigator.maybePop(context);
        return;
      }
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
      await AppScope.read(context).editHistory.recordCompletedEdit(
        editJobId: id,
        localFilePath: path,
        sourceKind: "download",
        title: p.basename(path),
        completedAtIso: d.completedAt,
        durationSeconds: _selectedDurationSec.round(),
        originalSourceTitle: _detail?.title,
        platform: _detail?.platform,
        outputMediaKind: "audio",
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

  double get _selectedDurationSec {
    final span = _endSec - _startSec;
    final spd = _speed.factor;
    return spd > 0 ? span / spd : span;
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
                ? _workingBody(l10n, theme, scheme)
                : _phase == _FlowPhase.done
                    ? _doneBody(l10n, theme, scheme)
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
    final range =
        "${formatAudioEditTimeSec(_startSec)}–${formatAudioEditTimeSec(_endSec)}";

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.audioEditTrimTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text(
                      l10n.audioEditTrimRange(range),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    _trimRow(l10n, theme, scheme, l10n.audioEditTrimStart, _nudgeTrimStart),
                    const SizedBox(height: 8),
                    _trimRow(l10n, theme, scheme, l10n.audioEditTrimEnd, _nudgeTrimEnd),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _resetTrim,
                        child: Text(l10n.audioEditResetTrim),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                scheme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.editSpeedSectionTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: AudioEditSpeedFactor.values.map((s) {
                        final selected = _speed == s;
                        final label = s == AudioEditSpeedFactor.x1
                            ? "1x"
                            : "${s.factor}x".replaceAll(".0", "");
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) => setState(() => _speed = s),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                scheme,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.audioEditQualityTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 10),
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
    final dur = _durationSec > 0 ? _durationSec : 1.0;
    final progress = dur > 0 ? (_positionSec / dur).clamp(0.0, 1.0) : 0.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(LucideIcons.audioLines, size: 40, color: scheme.primary.withValues(alpha: 0.85)),
            const SizedBox(height: 12),
            if (_previewError)
              Text(
                l10n.editAudioSaveFileFirst,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              )
            else ...[
              IconButton.filled(
                onPressed: c != null && c.value.isInitialized ? _togglePlay : null,
                icon: Icon(c?.value.isPlaying == true ? LucideIcons.pause : LucideIcons.play),
              ),
              const SizedBox(height: 8),
              Text(
                "${formatAudioEditTimeSec(_positionSec)} / ${formatAudioEditTimeSec(dur)}",
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _trimRow(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme scheme,
    String label,
    void Function(double) nudge,
  ) {
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
        IconButton(
          tooltip: "-${kAudioEditTrimNudgeSec}s",
          onPressed: () {
            HapticFeedback.selectionClick();
            nudge(-kAudioEditTrimNudgeSec);
          },
          icon: const Icon(LucideIcons.minus),
        ),
        IconButton(
          tooltip: "+${kAudioEditTrimNudgeSec}s",
          onPressed: () {
            HapticFeedback.selectionClick();
            nudge(kAudioEditTrimNudgeSec);
          },
          icon: const Icon(LucideIcons.plus),
        ),
      ],
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

  Widget _workingBody(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    final pct = _latestJob?.progressPercent ?? 0;
    if (_downloadingFile) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.editProcessingTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(l10n.progressPercent(pct)),
            const SizedBox(height: 16),
            KeepAppOpenHint(l10n.keepAppOpenUntilDownloadFinished),
          ],
        ),
      ),
    );
  }

  Widget _doneBody(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    final path = _outputPath;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleCheck, size: 48, color: scheme.primary),
            const SizedBox(height: 12),
            Text(l10n.audioEditReadyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            if (path != null) ...[
              FilledButton(
                onPressed: () => OpenFilex.open(path),
                child: Text(l10n.downloadOpen),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Share.shareXFiles([XFile(path)]),
                child: Text(l10n.downloadShare),
              ),
            ],
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.editDoneButton),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failedBody(AppLocalizations l10n, ThemeData theme, ColorScheme scheme) {
    final err = _lastError;
    final msg = err is ApiError
        ? localizedApiErrorMessage(l10n, err)
        : (_latestJob?.errorMessage?.trim().isNotEmpty == true
            ? _latestJob!.errorMessage!
            : l10n.audioEditFailed);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() {
                _phase = _FlowPhase.composing;
                _lastError = null;
              }),
              child: Text(l10n.editTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
