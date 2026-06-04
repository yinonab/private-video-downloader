import "dart:io";

import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/edit_history/edit_history_thumbnail_cache.dart";
import "../../../core/edit_history/local_edit_history_item.dart";
import "../../../core/edit_history/local_edit_history_store.dart";

/// Lazily generates a JPEG thumbnail from the local edited MP4 (platform extractor).
class EditHistoryThumbnail extends StatefulWidget {
  const EditHistoryThumbnail({
    super.key,
    required this.item,
    required this.fileExists,
    required this.editHistory,
    required this.borderRadius,
    required this.size,
  });

  final LocalEditHistoryItem item;
  final bool fileExists;
  final LocalEditHistoryStore editHistory;
  final BorderRadius borderRadius;
  final double size;

  @override
  State<EditHistoryThumbnail> createState() => _EditHistoryThumbnailState();
}

class _EditHistoryThumbnailState extends State<EditHistoryThumbnail> {
  String? _path;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _kick();
  }

  @override
  void didUpdateWidget(EditHistoryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.editJobId != widget.item.editJobId ||
        oldWidget.item.thumbnailPath != widget.item.thumbnailPath ||
        oldWidget.item.localFilePath != widget.item.localFilePath ||
        oldWidget.fileExists != widget.fileExists) {
      _kick();
    }
  }

  Future<void> _kick() async {
    if (widget.item.isAudioOutput) {
      setState(() {
        _busy = false;
        _path = null;
      });
      return;
    }
    if (!widget.fileExists) {
      setState(() {
        _busy = false;
        _path = null;
      });
      return;
    }

    final cached = widget.item.thumbnailPath?.trim();
    if (cached != null && cached.isNotEmpty && await File(cached).exists()) {
      setState(() {
        _path = cached;
        _busy = false;
      });
      return;
    }

    setState(() {
      _busy = true;
      _path = null;
    });

    try {
      final videoPath = widget.item.localFilePath.trim();
      if (videoPath.isEmpty) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final gen = await generateEditHistoryThumbnailFile(
        videoPath: videoPath,
        editJobId: widget.item.editJobId,
      );
      if (!mounted) return;
      if (gen != null && gen.isNotEmpty) {
        await widget.editHistory.updateThumbnailPath(widget.item.editJobId, gen);
      }
      if (!mounted) return;
      setState(() {
        _path = gen;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final Widget child;
    if (_path != null && _path!.isNotEmpty) {
      child = Image.file(
        File(_path!),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        cacheWidth: (widget.size * dpr).round(),
        cacheHeight: (widget.size * dpr).round(),
        errorBuilder: (_, __, ___) => _fallback(scheme),
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
      child = _fallback(scheme);
    }

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        child: SizedBox(width: widget.size, height: widget.size, child: child),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) {
    final icon = widget.item.isAudioOutput ? LucideIcons.audioLines : LucideIcons.film;
    return Icon(icon, color: scheme.primary, size: widget.size * 0.44);
  }
}
