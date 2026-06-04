import "package:flutter/material.dart";

import "audio_download_screen.dart";

/// Opens the audio-only download actions screen (not video Quick Edit).
Future<void> launchAudioDownloadForJob(
  BuildContext context, {
  required String jobId,
}) async {
  if (!context.mounted) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute<void>(
      builder: (_) => AudioDownloadScreen(jobId: jobId),
    ),
  );
}
