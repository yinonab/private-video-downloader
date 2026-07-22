import "dart:io";

import "package:flutter/material.dart";
import "package:lucide_icons_flutter/lucide_icons.dart";

import "../../../core/edit_history/edit_history_thumbnail_cache.dart";
import "../../../core/edit_history/local_edit_history_item.dart";
import "../../../core/edit_history/local_edit_history_store.dart";
import "../../../core/media/linkclip_media_thumbnail.dart";
import "../../../core/media/media_aspect.dart";
import "../../../core/theme/linkclip_design_system.dart";

/// Lazily generates a JPEG thumbnail from the local edited MP4 (platform extractor).
///
/// Display uses aspect-aware [LinkClipMediaThumbnail] tiles (never stretch).
class EditHistoryThumbnail extends StatefulWidget {
  const EditHistoryThumbnail({
    super.key,
    required this.item,
    required this.fileExists,
    required this.editHistory,
    this.borderRadius,
    this.durationLabel,
    this.overlay,
  });

  final LocalEditHistoryItem item;
  final bool fileExists;
  final LocalEditHistoryStore editHistory;
  final BorderRadius? borderRadius;
  final String? durationLabel;
  final Widget? overlay;

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
    final known = MediaAspect.ratioFromSize(
      width: widget.item.width,
      height: widget.item.height,
    );
    return LinkClipMediaThumbnail(
      filePath: _path,
      layout: LinkClipMediaThumbnailLayout.tile,
      fitStrategy: LinkClipMediaThumbnailFit.cover,
      aspectRatio: known,
      resolveImageAspect: known == null && !widget.item.isAudioOutput,
      borderRadius: widget.borderRadius ?? BorderRadius.circular(LcRadius.medium),
      durationLabel: widget.durationLabel,
      isAudio: widget.item.isAudioOutput,
      isLoading: _busy,
      placeholderIcon: widget.item.isAudioOutput ? LucideIcons.audioLines : LucideIcons.film,
      overlay: widget.overlay,
    );
  }
}
