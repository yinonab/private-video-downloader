import "dart:async";

import "package:flutter/material.dart";

import "../../core/app_scope.dart";
import "../../core/config/local_video_upload_constants.dart";
import "../../core/l10n/api_error_localizations.dart";
import "../../core/l10n/context_l10n.dart";
import "../../core/widgets/keep_app_open_hint.dart";
import "../../core/models/api_error.dart";
import "../../l10n/app_localizations.dart";
import "edit_video_screen.dart";
import "local_video/local_video_pickers.dart";
import "local_video/selected_local_video.dart";

bool _localVideoEditLaunchBusy = false;

/// Home banner → bottom sheet → pick → `POST /uploads/videos` → [EditVideoScreen.upload].
Future<void> launchLocalVideoEdit(BuildContext context) async {
  if (_localVideoEditLaunchBusy) return;
  _localVideoEditLaunchBusy = true;

  try {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);

    final choice = await showModalBottomSheet<LocalVideoPickKind>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.editLocalVideoSheetTitle,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.editLocalVideoLimitsNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading:
                      Icon(Icons.video_library_outlined, color: scheme.primary),
                  title: Text(l10n.editLocalVideoPickMedia),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(ctx, LocalVideoPickKind.mediaGallery),
                ),
                ListTile(
                  leading: Icon(Icons.folder_open_rounded, color: scheme.primary),
                  title: Text(l10n.editLocalVideoPickFiles),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () => Navigator.pop(ctx, LocalVideoPickKind.fileBrowser),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.homeCancel),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (choice == null) return;

    final SelectedLocalVideo? selected = switch (choice) {
      LocalVideoPickKind.mediaGallery => await pickFromDeviceMedia(),
      LocalVideoPickKind.fileBrowser => await pickFromFileBrowser(),
    };

    if (!context.mounted) return;
    if (selected == null) return;

    final sz = selected.sizeBytes;
    if (sz != null &&
        sz > 0 &&
        sz > LocalVideoUploadLimits.maxLocalVideoUploadBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorUploadFileTooLarge)),
      );
      return;
    }

    final uploadPath = await materializeSelectedLocalVideoPath(selected);
    if (!context.mounted) return;
    if (uploadPath == null || uploadPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorUploadFailed)),
      );
      return;
    }

    final rootNav = Navigator.of(context, rootNavigator: true);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) {
        final loc = AppLocalizations.of(dialogCtx);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        loc.editLocalVideoUploading,
                        style: Theme.of(dialogCtx).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                KeepAppOpenHint(loc.keepAppOpenUntilUploadFinished),
              ],
            ),
          ),
        );
      },
    ));

    try {
      final api = AppScope.read(context).api;
      final upload = await api.uploadVideo(
        filePath: uploadPath,
        filename: selected.displayName,
        mimeType: selected.mimeType,
      );
      if (context.mounted) rootNav.pop();

      if (!context.mounted) return;

      final lp = selected.localPreviewPath?.trim();
      final fp = selected.filePath?.trim();
      final previewPath =
          (lp != null && lp.isNotEmpty) ? lp : (fp != null && fp.isNotEmpty ? fp : null);

      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EditVideoScreen.upload(
            sourceUploadId: upload.uploadId,
            localPreviewPath: previewPath,
            title: upload.filename ?? selected.displayName,
            thumbnailUrl: upload.thumbnailUrl,
            durationSeconds: upload.durationSeconds,
            width: upload.width,
            height: upload.height,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) rootNav.pop();
      if (!context.mounted) return;
      final loc = context.l10n;
      final msg =
          e is ApiError ? localizedApiErrorMessage(loc, e) : loc.errorUploadFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  } finally {
    _localVideoEditLaunchBusy = false;
  }
}
