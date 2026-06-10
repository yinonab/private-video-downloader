import "package:flutter/material.dart";

import "../../core/edit/caption_preview_layout.dart";
import "../../core/models/quick_edit_models.dart";
import "../../core/storage/local_session.dart";
import "../../l10n/app_localizations.dart";
import "widgets/edit_captions_preview_overlay.dart";
import "widgets/edit_video_preview.dart";
import "widgets/edit_video_preview_source.dart";

/// Near-final caption preview over the actual edit video (visual only — no export).
class CaptionFullscreenPreviewScreen extends StatefulWidget {
  const CaptionFullscreenPreviewScreen({
    super.key,
    required this.previewSource,
    required this.session,
    required this.apiBaseForUrl,
    required this.look,
    required this.previewRotation,
    required this.trimStartSec,
    required this.trimEndSec,
    required this.videoDurationSec,
    this.thumbnailUrl,
    this.draftSegments,
    this.initialPlaybackSec = 0,
  });

  final EditVideoPreviewSource previewSource;
  final LocalSession session;
  final String apiBaseForUrl;
  final CaptionLookSnapshot look;
  final QuickEditRotation previewRotation;
  final double trimStartSec;
  final double trimEndSec;
  final double videoDurationSec;
  final String? thumbnailUrl;
  final List<CaptionDraftSegment>? draftSegments;
  final double initialPlaybackSec;

  @override
  State<CaptionFullscreenPreviewScreen> createState() =>
      _CaptionFullscreenPreviewScreenState();
}

class _CaptionFullscreenPreviewScreenState
    extends State<CaptionFullscreenPreviewScreen> {
  double _playbackSec = 0;

  @override
  void initState() {
    super.initState();
    _playbackSec = widget.initialPlaybackSec;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final captionText = captionPreviewDisplayText(
      l10n: l10n,
      draftSegments: widget.draftSegments,
      playbackSec: _playbackSec,
    );
    final highlightIdx = captionPreviewActiveWordIndex(
      text: captionText,
      draftSegments: widget.draftSegments,
      playbackSec: _playbackSec,
    );
    final s = widget.look;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.editCaptionsV36FullscreenPreviewTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: EditVideoPreview(
                    key: ValueKey<String>("fs-${widget.previewSource.identityTag}"),
                    previewSource: widget.previewSource,
                    session: widget.session,
                    apiBaseForUrl: widget.apiBaseForUrl,
                    previewRotation: widget.previewRotation,
                    trimStartSec: widget.trimStartSec,
                    trimEndSec: widget.trimEndSec,
                    videoDurationSec: widget.videoDurationSec,
                    thumbnailUrl: widget.thumbnailUrl,
                    minimalPlayChrome: true,
                    onDurationResolved: (_) {},
                    onPlaybackSeconds: (sec) {
                      if (!mounted) return;
                      setState(() => _playbackSec = sec);
                    },
                    captionsPreviewOverlay: EditCaptionsPreviewOverlay(
                      l10n: l10n,
                      layout: CaptionPreviewLayout.fullscreen,
                      showPreviewLabel: false,
                      stylePreset: s.style,
                      fontSize: s.fontSize,
                      fontFamily: s.fontFamily,
                      position: s.position,
                      color: s.color,
                      wordHighlight: s.wordHighlight,
                      normalTextColor: s.normalTextColor,
                      activeTextColor: s.activeTextColor,
                      boxColor: s.boxColor,
                      boxShape: s.boxShape,
                      outlineEnabled: s.outlineEnabled,
                      outlineColor: s.outlineColor,
                      outlineWidth: s.outlineWidth,
                      offsetXAss: s.offsetX,
                      offsetYAss: s.offsetY,
                      sampleText: captionText,
                      highlightWordIndex: highlightIdx,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
