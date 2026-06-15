import "dart:math" as math;

import "../models/quick_edit_models.dart";
import "../../l10n/app_localizations.dart";

/// Resolved headline, subtitle, and progress for the edit/export working screen.
final class EditProgressDisplay {
  const EditProgressDisplay({
    required this.headline,
    required this.progress,
    required this.isEstimated,
    this.subtitle,
  });

  final String headline;
  final String? subtitle;

  /// 0.0–1.0 for [LinearProgressIndicator.value].
  final double progress;
  final bool isEstimated;
}

/// Maps backend job state + client download phase → user-facing progress UX.
EditProgressDisplay resolveEditProgressDisplay({
  required AppLocalizations l10n,
  required bool downloadingFile,
  required bool hasCaptions,
  required EditJobDetailResponse? job,
  required DateTime? workingStartedAt,
}) {
  if (downloadingFile) {
    return EditProgressDisplay(
      headline: l10n.editProgressStagePreparingPreview,
      subtitle: l10n.editProcessingSubtitle,
      progress: 0.96,
      isEstimated: false,
    );
  }

  final stage = (job?.stage ?? "").trim().toLowerCase();
  final backendPct = job?.progressPercent;
  final elapsedSec = workingStartedAt == null
      ? 0
      : DateTime.now().difference(workingStartedAt).inSeconds;

  final estimated = backendPct == null || backendPct <= 0;
  final progress = _resolveProgressFraction(
    backendPct: backendPct,
    stage: stage,
    elapsedSec: elapsedSec,
    downloadingFile: false,
  );

  final headline = _resolveHeadline(
    l10n: l10n,
    stage: stage,
    hasCaptions: hasCaptions,
    elapsedSec: elapsedSec,
    progress: progress,
  );

  return EditProgressDisplay(
    headline: headline,
    subtitle: l10n.editCreatingEditKeepOpen,
    progress: progress,
    isEstimated: estimated,
  );
}

double _resolveProgressFraction({
  required int? backendPct,
  required String stage,
  required int elapsedSec,
  required bool downloadingFile,
}) {
  if (downloadingFile) return 0.96;

  if (backendPct != null && backendPct > 0) {
    return (backendPct.clamp(5, 95)) / 100.0;
  }

  final stageFloor = switch (stage) {
    "validating_source" || "queued" => 0.05,
    "probing" => 0.08,
    "processing" => 0.12,
    "captions_prep" || "captions_transcription" => 0.48,
    "captions_encode" => 0.58,
    "finalizing" => 0.90,
    _ => 0.05,
  };

  // Slow asymptotic curve — not presented as exact backend progress.
  final timeCurve = 0.05 + (1 - math.exp(-elapsedSec / 90.0)) * 0.82;
  return math.min(0.94, math.max(stageFloor, timeCurve));
}

String _resolveHeadline({
  required AppLocalizations l10n,
  required String stage,
  required bool hasCaptions,
  required int elapsedSec,
  required double progress,
}) {
  if (stage == "finalizing") {
    return progress >= 0.92
        ? l10n.editProgressStageAlmostDone
        : l10n.editProgressStageFinalizing;
  }

  if (progress >= 0.88) {
    return l10n.editProgressStageAlmostDone;
  }

  if (_isCaptionStage(stage)) {
    if (hasCaptions) {
      return l10n.editProgressStageBurningCaptions;
    }
    return l10n.editProgressStageProcessing;
  }

  return switch (stage) {
    "validating_source" || "queued" || "probing" || "" =>
      l10n.editProgressStagePreparing,
    "processing" =>
      elapsedSec >= 24
          ? l10n.editProgressStageApplyingEdits
          : l10n.editProgressStageProcessing,
    _ => elapsedSec >= 48
        ? l10n.editProgressStageApplyingEdits
        : l10n.editProgressStageProcessing,
  };
}

bool _isCaptionStage(String stage) {
  return stage == "captions_prep" ||
      stage == "captions_transcription" ||
      stage == "captions_encode";
}
