import "dart:io";

import "package:flutter/material.dart";

import "../edit_history/edit_history_thumbnail_cache.dart";
import "media_output_preview_source.dart";

/// Thumbnail for a completed output (edit done screen, history cards, etc.).
///
/// Does not use [EditPreviewState] — prefers final local output over source URLs.
class MediaOutputPreviewThumbnail extends StatefulWidget {
  const MediaOutputPreviewThumbnail({
    super.key,
    required this.preview,
    this.editJobId,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.aspectRatio = 16 / 9,
    this.fit = BoxFit.cover,
    this.onThumbnailGenerated,
  });

  final ResolvedMediaOutputPreview preview;
  final String? editJobId;
  final BorderRadius borderRadius;
  final double aspectRatio;
  final BoxFit fit;
  final ValueChanged<String>? onThumbnailGenerated;

  @override
  State<MediaOutputPreviewThumbnail> createState() =>
      _MediaOutputPreviewThumbnailState();
}

class _MediaOutputPreviewThumbnailState extends State<MediaOutputPreviewThumbnail> {
  String? _generatedPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _kick();
  }

  @override
  void didUpdateWidget(MediaOutputPreviewThumbnail old) {
    super.didUpdateWidget(old);
    if (old.preview.kind != widget.preview.kind ||
        old.preview.localThumbnailPath != widget.preview.localThumbnailPath ||
        old.preview.localVideoPath != widget.preview.localVideoPath ||
        old.preview.remoteThumbnailUrl != widget.preview.remoteThumbnailUrl ||
        old.editJobId != widget.editJobId) {
      _kick();
    }
  }

  Future<void> _kick() async {
    final p = widget.preview;
    if (p.kind == MediaOutputPreviewKind.localThumbnail) {
      setState(() {
        _generatedPath = p.localThumbnailPath;
        _busy = false;
      });
      return;
    }

    if (p.kind == MediaOutputPreviewKind.localVideoFrame) {
      final video = p.localVideoPath?.trim() ?? "";
      final jobId = widget.editJobId?.trim() ?? video;
      if (video.isEmpty) {
        setState(() {
          _generatedPath = null;
          _busy = false;
        });
        return;
      }
      setState(() {
        _busy = true;
        _generatedPath = null;
      });
      try {
        final gen = await generateEditHistoryThumbnailFile(
          videoPath: video,
          editJobId: jobId,
        );
        if (!mounted) return;
        if (gen != null && gen.isNotEmpty) {
          widget.onThumbnailGenerated?.call(gen);
        }
        setState(() {
          _generatedPath = gen;
          _busy = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() => _busy = false);
      }
      return;
    }

    setState(() {
      _generatedPath = null;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.preview;

    Widget child;
    if (p.kind == MediaOutputPreviewKind.localThumbnail ||
        (_generatedPath != null && _generatedPath!.isNotEmpty)) {
      final path = p.kind == MediaOutputPreviewKind.localThumbnail
          ? p.localThumbnailPath!
          : _generatedPath!;
      child = Image.file(
        File(path),
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(scheme),
      );
    } else if (p.kind == MediaOutputPreviewKind.remoteUrl) {
      child = Image.network(
        p.remoteThumbnailUrl!,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(scheme),
      );
    } else if (_busy) {
      child = Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.primary,
          ),
        ),
      );
    } else {
      child = _placeholder(scheme);
    }

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
          child: child,
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme scheme) {
    return Center(
      child: Icon(
        Icons.movie_creation_outlined,
        size: 48,
        color: scheme.outline.withValues(alpha: 0.7),
      ),
    );
  }
}
