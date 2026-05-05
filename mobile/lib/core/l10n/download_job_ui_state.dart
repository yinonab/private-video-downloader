import "package:flutter/foundation.dart";

import "../../l10n/app_localizations.dart";
import "download_status_localizations.dart";

/// Unified download job presentation for cards and status screen.
class DownloadJobUiState {
  const DownloadJobUiState({
    required this.effectiveStageKey,
    required this.statusChipLabel,
    required this.screenHeadline,
    this.screenHeadlineSubtitle,
    required this.progressStageTitle,
    this.progressStageSubtitle,
    required this.showDeterminateProgress,
    required this.showIndeterminateProgress,
    this.determinatePercent,
  });

  /// Backend stage after inference (snake_case keys).
  final String effectiveStageKey;

  /// Short label for list-card status chip.
  final String statusChipLabel;

  /// Primary headline on [DownloadStatusScreen] (under video title).
  final String screenHeadline;

  /// Extra explanation line (e.g. full transcode).
  final String? screenHeadlineSubtitle;

  /// Primary line above the branded progress bar.
  final String progressStageTitle;

  /// Secondary line under [progressStageTitle] inside the progress widget.
  final String? progressStageSubtitle;

  final bool showDeterminateProgress;
  final bool showIndeterminateProgress;

  /// 0–100 when [showDeterminateProgress] is true.
  final int? determinatePercent;
}

String _inferStageFromStatus(String status) {
  switch (status.trim()) {
    case "queued":
      return "queued";
    case "analyzing":
      return "preparing";
    case "running":
      return "downloading";
    case "done":
      return "done";
    case "failed":
    case "canceled":
      return "failed";
    default:
      return "queued";
  }
}

String _localizedPipelineStage(AppLocalizations l10n, String stage) {
  switch (stage) {
    case "queued":
      return l10n.stageQueued;
    case "preparing":
      return l10n.stagePreparing;
    case "downloading":
      return l10n.stageDownloading;
    case "checking_compatibility":
      return l10n.stageCheckingCompatibility;
    case "remuxing":
      return l10n.stageRemuxing;
    case "normalizing_audio":
      return l10n.stageNormalizingAudio;
    case "full_transcoding":
      return l10n.stageFullTranscoding;
    case "finalizing":
      return l10n.stageFinalizing;
    case "done":
      return l10n.stageDone;
    case "failed":
      return l10n.stageFailed;
    default:
      return l10n.downloadUnknownProgress;
  }
}

DownloadJobUiState mapDownloadJobUi(
  AppLocalizations l10n, {
  required String jobId,
  required String status,
  String? processingStage,
  int? progressPercent,
  String? requestedFormat,
  bool forDoneSavedLocallyHeadline = false,

  /// Home card: show long transcode hint under the progress bar. Status screen uses [screenHeadlineSubtitle] instead.
  bool compactProgressCard = false,

  /// Avoid duplicate debug lines when this mapper runs twice in one frame.
  bool debugLog = true,
}) {
  final st = status.trim().isEmpty ? "unknown" : status.trim();
  final terminal = {"done", "failed", "canceled"}.contains(st);
  final isDone = st == "done";
  final isFailed = st == "failed";
  final isCanceled = st == "canceled";

  final isTikTokJob = (requestedFormat ?? "").trim().toLowerCase() == "tiktok_ready";

  final rawStage = (processingStage ?? "").trim();
  final effectiveStage = rawStage.isNotEmpty ? rawStage : _inferStageFromStatus(st);

  var pct = progressPercent;
  if (!terminal && pct != null && pct <= 0) {
    pct = null;
  }

  final showDeterminate = !terminal && pct != null;
  final showIndeterminate = !terminal && pct == null;

  final pipelineTitle = _localizedPipelineStage(l10n, effectiveStage);
  final isFullTranscode = effectiveStage == "full_transcoding" && !terminal;

  String statusChipLabel;
  if (isDone) {
    statusChipLabel = l10n.stageDone;
  } else if (isFailed) {
    statusChipLabel = l10n.stageFailed;
  } else if (isCanceled) {
    statusChipLabel = l10n.downloadStatusCanceled;
  } else {
    statusChipLabel = isFullTranscode ? l10n.stageFullTranscoding : pipelineTitle;
  }

  String screenHeadline;
  String? screenHeadlineSubtitle;
  if (forDoneSavedLocallyHeadline) {
    screenHeadline = l10n.downloadStatusSavedOnDeviceTitle;
    screenHeadlineSubtitle = null;
  } else if (isDone) {
    screenHeadline = l10n.stageDone;
    screenHeadlineSubtitle = null;
  } else if (isFailed || isCanceled) {
    screenHeadline = localizedDownloadJobStatus(l10n, st);
    screenHeadlineSubtitle = null;
  } else if (isTikTokJob && !terminal) {
    screenHeadline = l10n.downloadPreparingTikTokReadyTitle;
    screenHeadlineSubtitle = l10n.downloadPreparingTikTokReadySubtitle;
  } else if (isFullTranscode) {
    screenHeadline = l10n.fullTranscodeTitle;
    screenHeadlineSubtitle = l10n.fullTranscodeSubtitle;
  } else {
    screenHeadline = pipelineTitle;
    screenHeadlineSubtitle = null;
  }

  String progressStageTitle;
  String? progressStageSubtitle;
  if (!terminal) {
    progressStageTitle = showDeterminate ? pipelineTitle : l10n.downloadUnknownProgress;
    if (isTikTokJob && compactProgressCard) {
      progressStageSubtitle = l10n.downloadPreparingTikTokReadySubtitle;
    } else if (isFullTranscode && compactProgressCard && !isTikTokJob) {
      progressStageSubtitle = l10n.fullTranscodeSubtitle;
    } else {
      progressStageSubtitle = null;
    }
  } else {
    progressStageTitle = pipelineTitle;
    progressStageSubtitle = null;
  }

  assert(() {
    if (debugLog && kDebugMode && jobId.isNotEmpty) {
      final mode = showDeterminate ? "determinate" : (showIndeterminate ? "indeterminate" : "none");
      debugPrint(
        "### JOB_STATUS_DEBUG ### jobId=$jobId apiStatus=$st processingStage=$processingStage "
        "progressPercent=$progressPercent requestedFormat=$requestedFormat mappedUiStage=$effectiveStage progressMode=$mode pctUsed=$pct",
      );
    }
    return true;
  }());

  return DownloadJobUiState(
    effectiveStageKey: effectiveStage,
    statusChipLabel: statusChipLabel,
    screenHeadline: screenHeadline,
    screenHeadlineSubtitle: screenHeadlineSubtitle,
    progressStageTitle: progressStageTitle,
    progressStageSubtitle: progressStageSubtitle,
    showDeterminateProgress: showDeterminate,
    showIndeterminateProgress: showIndeterminate,
    determinatePercent: pct,
  );
}
