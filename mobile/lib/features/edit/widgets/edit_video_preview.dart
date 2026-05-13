import "dart:async";
import "dart:io";

import "package:flutter/material.dart";
import "package:video_player/video_player.dart";

import "../../../core/network/api_client.dart";
import "../../../core/storage/local_session.dart";

/// In-editor video preview: prefers local saved file, otherwise authenticated `GET /downloads/:id/file`.
///
/// Preview playback loops within [trimStartSec]..[trimEndSec] (approximation only;
/// final trim is still performed by the backend `/edits` pipeline).
class EditVideoPreview extends StatefulWidget {
  const EditVideoPreview({
    super.key,
    required this.jobId,
    required this.session,
    required this.apiBaseForUrl,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.videoDurationSec,
    required this.onDurationResolved,
    required this.onPlaybackSeconds,
    this.thumbnailUrl,
  });

  final String jobId;
  final LocalSession session;
  final String apiBaseForUrl;
  final double trimStartSec;
  final double trimEndSec;
  final double videoDurationSec;
  final ValueChanged<double> onDurationResolved;
  final ValueChanged<double> onPlaybackSeconds;
  final String? thumbnailUrl;

  @override
  State<EditVideoPreview> createState() => _EditVideoPreviewState();
}

class _EditVideoPreviewState extends State<EditVideoPreview> {
  VideoPlayerController? _controller;
  Object? _initError;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_initPlayer);
  }

  @override
  void didUpdateWidget(covariant EditVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trimStartSec != widget.trimStartSec ||
        oldWidget.trimEndSec != widget.trimEndSec ||
        oldWidget.jobId != widget.jobId) {
      unawaited(_seekToTrimStart());
      _enforceTrimWindow();
    }
  }

  Future<void> _initPlayer() async {
    final id = widget.jobId.trim();
    if (id.isEmpty) {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    try {
      final local = (await widget.session.localPathForJob(id))?.trim();
      VideoPlayerController? c;
      if (local != null &&
          local.isNotEmpty &&
          !local.startsWith("content:") &&
          await File(local).exists()) {
        c = VideoPlayerController.file(File(local));
      } else {
        final token = widget.session.deviceToken.trim();
        final url = ApiClient.normalizeServerInput(widget.apiBaseForUrl)
            .trimRight()
            .replaceAll(RegExp(r"/+$"), "");
        final fileUrl = "$url/downloads/$id/file";
        final headers = token.isEmpty
            ? <String, String>{}
            : <String, String>{"Authorization": "Bearer $token"};
        // Authenticated streaming preview when no local copy exists yet.
        c = VideoPlayerController.networkUrl(
          Uri.parse(fileUrl),
          httpHeaders: headers,
        );
      }

      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }

      c.addListener(_onVideoTick);
      _controller = c;
      final dur = c.value.duration.inMicroseconds / 1e6;
      if (dur > 0.5) {
        widget.onDurationResolved(dur);
      }
      await c.setLooping(false);
      await c.pause();
      await _seekToTrimStart();
      if (mounted) {
        setState(() {
          _initializing = false;
          _initError = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = e;
      });
    }
  }

  void _onVideoTick() {
    final c = _controller;
    if (!mounted || c == null || !c.value.isInitialized) return;
    final pos = c.value.position.inMicroseconds / 1e6;
    widget.onPlaybackSeconds(pos);
    _enforceTrimWindow();
  }

  void _enforceTrimWindow() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dur = widget.videoDurationSec > 0
        ? widget.videoDurationSec
        : (c.value.duration.inMicroseconds / 1e6);
    if (dur <= 0) return;

    final start = widget.trimStartSec.clamp(0.0, dur);
    final end = widget.trimEndSec.clamp(start + 0.05, dur);
    final pos = c.value.position.inMicroseconds / 1e6;

    if (pos < start - 0.03) {
      c.seekTo(Duration(milliseconds: (start * 1000).round()));
      return;
    }
    if (pos >= end - 0.04) {
      c.seekTo(Duration(milliseconds: (start * 1000).round()));
      return;
    }
  }

  Future<void> _seekToTrimStart() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final dur = widget.videoDurationSec > 0
        ? widget.videoDurationSec
        : (c.value.duration.inMicroseconds / 1e6);
    if (dur <= 0) return;
    final start = widget.trimStartSec.clamp(0.0, dur);
    await c.seekTo(Duration(milliseconds: (start * 1000).round()));
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await _seekToTrimStart();
      await c.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onVideoTick);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = widget.thumbnailUrl;

    if (_initializing) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb != null && thumb.isNotEmpty)
                Image.network(thumb, fit: BoxFit.cover)
              else
                ColoredBox(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.95)),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      );
    }

    if (_initError != null ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb != null && thumb.isNotEmpty)
                Image.network(
                  thumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      ColoredBox(color: scheme.surfaceContainerHighest),
                )
              else
                ColoredBox(
                    color:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.95)),
              Center(
                child: Icon(Icons.play_circle_outline_rounded,
                    size: 64, color: scheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    final c = _controller!;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
            Material(
              color: Colors.black.withValues(alpha: 0.28),
              type: MaterialType.transparency,
              child: InkWell(
                onTap: _togglePlay,
                child: Center(
                  child: Icon(
                    c.value.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_filled_rounded,
                    size: 72,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
