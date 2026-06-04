import "package:flutter/material.dart";

import "audio_edit_screen.dart";
import "launch_audio_download.dart";

/// Opens real audio edit, or fallback actions screen when source is unavailable.
Future<void> launchAudioEditForJob(
  BuildContext context, {
  required String jobId,
}) async {
  if (!context.mounted) return;
  try {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AudioEditScreen(jobId: jobId),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    await launchAudioDownloadForJob(context, jobId: jobId);
  }
}
