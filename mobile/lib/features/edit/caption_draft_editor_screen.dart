import "package:flutter/material.dart";

import "../../core/edit/caption_draft_summary.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/models/quick_edit_models.dart";
import "widgets/caption_draft_segment_ui.dart";

/// Caption draft editor — full screen or embedded in a bottom sheet (Captions UX V3.1+).
class CaptionDraftEditorScreen extends StatefulWidget {
  const CaptionDraftEditorScreen({
    super.key,
    required this.initialSegments,
    required this.videoDurationSec,
    required this.onDraftChanged,
    this.embeddedInSheet = false,
    this.scrollController,
  });

  final List<CaptionDraftSegment> initialSegments;
  final double videoDurationSec;

  /// Live working-copy updates (no backend save).
  final ValueChanged<List<CaptionDraftSegment>> onDraftChanged;

  /// When true, omits full-screen chrome (used inside edit-screen bottom sheet).
  final bool embeddedInSheet;
  final ScrollController? scrollController;

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

  void _emitDraft() {
    widget.onDraftChanged(List<CaptionDraftSegment>.from(_segments));
  }

  void _updateSegment(
    String id, {
    required String text,
    required double startSec,
    required double endSec,
  }) {
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
    _emitDraft();
  }

  void _clearSegment(String id) {
    setState(() {
      _segments = [
        for (final s in _segments) s.id == id ? s.copyWith(text: '') : s,
      ];
    });
    _emitDraft();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = captionDraftSummaryLine(l10n, _segments);

    final list = ListView.separated(
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        widget.embeddedInSheet ? 4 : 8,
        16,
        24,
      ),
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
          onLiveChanged: (text, startSec, endSec) => _updateSegment(
            seg.id,
            text: text,
            startSec: startSec,
            endSec: endSec,
          ),
          onClear: () => _clearSegment(seg.id),
        );
      },
    );

    if (widget.embeddedInSheet) {
      return Material(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outline.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.editCaptionsV31ScreenTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          summary,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(child: list),
            SafeArea(
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
          ],
        ),
      );
    }

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
      body: list,
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
