import "package:flutter/material.dart";

import "../../core/edit/caption_draft_summary.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/quick_edit_models.dart";
import "widgets/caption_draft_segment_ui.dart";

/// Full-screen caption draft editor (Captions UX V3.1).
class CaptionDraftEditorScreen extends StatefulWidget {
  const CaptionDraftEditorScreen({
    super.key,
    required this.initialSegments,
    required this.videoDurationSec,
    required this.onSegmentUpdated,
    required this.onClearSegment,
  });

  final List<CaptionDraftSegment> initialSegments;
  final double videoDurationSec;
  final void Function(
    String segmentId, {
    required String text,
    required double startSec,
    required double endSec,
  }) onSegmentUpdated;
  final void Function(String segmentId) onClearSegment;

  @override
  State<CaptionDraftEditorScreen> createState() =>
      _CaptionDraftEditorScreenState();
}

class _CaptionDraftEditorScreenState extends State<CaptionDraftEditorScreen> {
  late List<CaptionDraftSegment> _segments;

  @override
  void initState() {
    super.initState();
    _segments = List<CaptionDraftSegment>.from(widget.initialSegments);
  }

  void _updateSegment(
    String id, {
    required String text,
    required double startSec,
    required double endSec,
  }) {
    widget.onSegmentUpdated(
      id,
      text: text,
      startSec: startSec,
      endSec: endSec,
    );
    setState(() {
      _segments = [
        for (final s in _segments)
          s.id == id
              ? s.copyWith(
                  text: text,
                  startSec: startSec,
                  endSec: endSec,
                )
              : s,
      ];
    });
  }

  void _clearSegment(String id) {
    widget.onClearSegment(id);
    setState(() {
      _segments = [
        for (final s in _segments) s.id == id ? s.copyWith(text: '') : s,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = captionDraftSummaryLine(l10n, _segments);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.editCaptionsV31ScreenTitle),
            Text(
              summary,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.editCaptionsV31Done),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _segments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final seg = _segments[i];
          return CaptionDraftSegmentRow(
            segment: seg,
            segmentIndex: i,
            allSegments: _segments,
            videoDurationSec: widget.videoDurationSec,
            editSemanticsLabel: l10n.editCaptionsDraftEditTitle,
            clearSemanticsLabel: l10n.editCaptionsDraftClearSegment,
            adjustedLabel: l10n.editCaptionsDraftTimingAdjusted,
            onSave: (text, startSec, endSec) => _updateSegment(
              seg.id,
              text: text,
              startSec: startSec,
              endSec: endSec,
            ),
            onClear: () => _clearSegment(seg.id),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(l10n.editCaptionsV31Done),
        ),
      ),
    );
  }
}
