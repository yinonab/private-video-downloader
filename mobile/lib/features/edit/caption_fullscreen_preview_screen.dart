import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";

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
    required this.speedFactor,
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
  final QuickEditSpeedFactor speedFactor;
  final String? thumbnailUrl;
  final List<CaptionDraftSegment>? draftSegments;
  final double initialPlaybackSec;

  @override
  State<CaptionFullscreenPreviewScreen> createState() =>
      _CaptionFullscreenPreviewScreenState();
}

class _CaptionFullscreenPreviewScreenState
    extends State<CaptionFullscreenPreviewScreen> {
  double _sourcePlaybackSec = 0;

  @override
  void initState() {
    super.initState();
    _sourcePlaybackSec = widget.initialPlaybackSec;
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
  }

  @override
  void dispose() {
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );
    super.dispose();
  }

  double get _editTimelinePlaybackSec => captionPreviewPlaybackOnEditTimeline(
        sourcePlaybackSec: _sourcePlaybackSec,
        trimStartSec: widget.trimStartSec,
        trimEndSec: widget.trimEndSec,
        videoDurationSec: widget.videoDurationSec,
        speedFactor: widget.speedFactor,
      );

  Widget? _buildCaptionOverlay(AppLocalizations l10n) {
    final cue = resolveCaptionPreviewCue(
      l10n: l10n,
      draftSegments: widget.draftSegments,
      playbackSec: _editTimelinePlaybackSec,
      allowSampleFallback: false,
    );
    if (!cue.hasText) return null;
    final highlightIdx = captionPreviewActiveWordIndex(
      text: cue.text!,
      draftSegments: widget.draftSegments,
      playbackSec: _editTimelinePlaybackSec,
    );
    final s = widget.look;
    return EditCaptionsPreviewOverlay(
      l10n: l10n,
      layout: CaptionPreviewLayout.fullscreen,
      showPreviewLabel: false,
      allowSampleFallback: false,
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
      sampleText: cue.text,
      highlightWordIndex: highlightIdx,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: true,
      child: Scaffold(
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
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
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
                    fit: EditVideoPreviewFit.expand,
                    clipBorderRadius: 0,
                    onDurationResolved: (_) {},
                    onPlaybackSeconds: (sec) {
                      if (!mounted) return;
                      setState(() => _sourcePlaybackSec = sec);
                    },
                    captionsPreviewOverlay: _buildCaptionOverlay(l10n),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
