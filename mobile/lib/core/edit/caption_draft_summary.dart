import "../../l10n/app_localizations.dart";
import "../models/quick_edit_models.dart";

int captionDraftAdjustedCount(List<CaptionDraftSegment> segments) =>
    segments.where((s) => s.hasTimingAdjustment).length;

String captionDraftSummaryLine(
  AppLocalizations l10n,
  List<CaptionDraftSegment> segments,
) {
  final count = segments.length;
  final adjusted = captionDraftAdjustedCount(segments);
  if (adjusted > 0) {
    return l10n.editCaptionsV31DraftSummaryCountAdjusted(count, adjusted);
  }
  return l10n.editCaptionsV31DraftSummaryCount(count);
}
