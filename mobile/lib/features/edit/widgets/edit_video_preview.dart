import "dart:async";
import "dart:io";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:video_player/video_player.dart";

import "../../../core/edit/caption_preview_layout.dart";
import "../../../core/models/quick_edit_models.dart";
import "../../../core/network/api_client.dart";
import "../../../core/storage/local_session.dart";
import "edit_video_preview_source.dart";

/// How the preview sizes itself in the parent.
enum EditVideoPreviewFit {
  /// Fixed 16:9 outer frame with letterboxed video (in-editor card).
  card16x9,

  /// Expands to parent; letterboxed video (fullscreen).
  expand,
}

/// In-editor video preview: prefers local file when available, otherwise authenticated
/// `GET /downloads/:id/file` or `GET /uploads/:id/file`.
///
/// Preview playback loops within [trimStartSec]..[trimEndSec] (approximation only;
/// final trim is still performed by the backend `/edits` pipeline).
class EditVideoPreview extends StatefulWidget {
  const EditVideoPreview({
    super.key,
    required this.previewSource,
    required this.session,
    required this.apiBaseForUrl,
    required this.previewRotation,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.videoDurationSec,
    required this.onDurationResolved,
    required this.onPlaybackSeconds,
    this.thumbnailUrl,
    this.captionsPreviewOverlay,
    this.minimalPlayChrome = false,
    this.fit = EditVideoPreviewFit.card16x9,
    this.clipBorderRadius = 22,
  });

  final EditVideoPreviewSource previewSource;
  final LocalSession session;
  final String apiBaseForUrl;
  final QuickEditRotation previewRotation;
  final double trimStartSec;
  final double trimEndSec;
  final double videoDurationSec;
  final ValueChanged<double> onDurationResolved;
  final ValueChanged<double> onPlaybackSeconds;
  final String? thumbnailUrl;
  final Widget? captionsPreviewOverlay;
  final bool minimalPlayChrome;
  final EditVideoPreviewFit fit;
  final double clipBorderRadius;

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

  void _disposeController() {
    final c = _controller;
    if (c != null) {
      c.removeListener(_onVideoTick);
      c.dispose();
      _controller = null;
    }
  }

  double _displayAspectRatio(VideoPlayerController c) {
    final w = c.value.size.width;
    final h = c.value.size.height;
    return videoPreviewDisplayAspectRatio(
      sourceWidth: w,
      sourceHeight: h,
      rotation: widget.previewRotation,
    );
  }

  @override
  void didUpdateWidget(covariant EditVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewSource.identityTag != widget.previewSource.identityTag) {
      _disposeController();
      setState(() {
        _initializing = true;
        _initError = null;
      });
      scheduleMicrotask(_initPlayer);
      return;
    }
    if (oldWidget.trimStartSec != widget.trimStartSec ||
        oldWidget.trimEndSec != widget.trimEndSec) {
      unawaited(_seekToTrimStart());
      _enforceTrimWindow();
    }
  }

  Future<void> _initPlayer() async {
    final token = widget.session.deviceToken.trim();
    final urlRoot = ApiClient.normalizeServerInput(widget.apiBaseForUrl)
        .trimRight()
        .replaceAll(RegExp(r"/+$"), "");

    VideoPlayerController? c;

    final ps = widget.previewSource;
    if (ps is EditVideoPreviewDownloadSource) {
      final id = ps.jobId.trim();
      if (id.isEmpty) {
        if (mounted) setState(() => _initializing = false);
        return;
      }
      try {
        final local = (await widget.session.localPathForJob(id))?.trim();
        if (local != null &&
            local.isNotEmpty &&
            !local.startsWith("content:") &&
            await File(local).exists()) {
          c = VideoPlayerController.file(File(local));
        } else {
          final fileUrl = "$urlRoot/downloads/$id/file";
          final headers = token.isEmpty
              ? <String, String>{}
              : <String, String>{"Authorization": "Bearer $token"};
          c = VideoPlayerController.networkUrl(
            Uri.parse(fileUrl),
            httpHeaders: headers,
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _initError = e;
        });
        return;
      }
    } else if (ps is EditVideoPreviewUploadSource) {
      final id = ps.uploadId.trim();
      if (id.isEmpty) {
        if (mounted) setState(() => _initializing = false);
        return;
      }
      try {
        final lp = ps.localPreviewPath?.trim();
        if (lp != null &&
            lp.isNotEmpty &&
            !lp.startsWith("content:") &&
            await File(lp).exists()) {
          c = VideoPlayerController.file(File(lp));
        } else {
          final fileUrl = "$urlRoot/uploads/$id/file";
          final headers = token.isEmpty
              ? <String, String>{}
              : <String, String>{"Authorization": "Bearer $token"};
          c = VideoPlayerController.networkUrl(
            Uri.parse(fileUrl),
            httpHeaders: headers,
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _initError = e;
        });
        return;
      }
    } else {
      if (mounted) setState(() => _initializing = false);
      return;
    }

    try {
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
      await c.dispose();
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

  Widget _playOverlayInk(VideoPlayerController c) {
    final playing = c.value.isPlaying;
    final minimal = widget.minimalPlayChrome;
    return Material(
      color: minimal && playing
          ? Colors.transparent
          : Colors.black.withValues(alpha: minimal ? 0.08 : 0.22),
      type: MaterialType.transparency,
      child: InkWell(
        onTap: _togglePlay,
        child: Center(
          child: (!minimal || !playing)
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: minimal ? 0.45 : 0.38),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(minimal ? 12 : 14),
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: minimal ? 32 : 36,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _videoPaint(VideoPlayerController c) {
    final w = c.value.size.width;
    final h = c.value.size.height;
    Widget core = SizedBox(
      width: w,
      height: h,
      child: VideoPlayer(c),
    );
    return switch (widget.previewRotation) {
      QuickEditRotation.deg180 => Transform.rotate(
          angle: math.pi,
          alignment: Alignment.center,
          child: core,
        ),
      QuickEditRotation.deg90 => Transform.rotate(
          angle: math.pi / 2,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          child: core,
        ),
      QuickEditRotation.deg270 => Transform.rotate(
          angle: 3 * math.pi / 2,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          child: core,
        ),
      QuickEditRotation.deg0 => core,
    };
  }

  Widget _containPreviewStack(VideoPlayerController c) {
    final displayAr = _displayAspectRatio(c);
    final radius = widget.clipBorderRadius;

    Widget inner = LayoutBuilder(
      builder: (context, constraints) {
        final container = Size(constraints.maxWidth, constraints.maxHeight);
        final videoRect = videoPreviewContainRect(
          containerSize: container,
          displayAspectWidthOverHeight: displayAr,
        );
        final overlay = widget.captionsPreviewOverlay;

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              Positioned.fromRect(
                rect: videoRect,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: _videoPaint(c),
                ),
              ),
              if (overlay != null)
                Positioned.fromRect(
                  rect: videoRect,
                  child: IgnorePointer(
                    ignoring: true,
                    child: overlay,
                  ),
                ),
              Positioned.fill(child: _playOverlayInk(c)),
            ],
          ),
        );
      },
    );

    if (widget.fit == EditVideoPreviewFit.card16x9) {
      return AspectRatio(aspectRatio: 16 / 9, child: inner);
    }
    return inner;
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
    _disposeController();
    super.dispose();
  }

  Widget _placeholderStack(Widget child) {
    final radius = widget.clipBorderRadius;
    Widget inner = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: child,
    );
    if (widget.fit == EditVideoPreviewFit.card16x9) {
      return AspectRatio(aspectRatio: 16 / 9, child: inner);
    }
    return inner;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thumb = widget.thumbnailUrl;

    if (_initializing) {
      return _placeholderStack(
        Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null && thumb.isNotEmpty)
              Image.network(thumb, fit: BoxFit.contain)
            else
              ColoredBox(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
              ),
            const Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }

    if (_initError != null ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return _placeholderStack(
        Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null && thumb.isNotEmpty)
              Image.network(
                thumb,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: scheme.surfaceContainerHighest),
              )
            else
              ColoredBox(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
              ),
            Center(
              child: Icon(
                Icons.play_circle_outline_rounded,
                size: 64,
                color: scheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return _containPreviewStack(_controller!);
  }
}
