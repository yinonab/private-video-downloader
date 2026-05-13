import "../../l10n/app_localizations.dart";

/// User-visible path under Downloads (matches [MediaStore.appFolder] / file manager).
///
/// Wrapped with LRM so in RTL locales `>` stays **>** between Hebrew "הורדות" and Latin folder name.
class MediaExportDisplayPath {
  MediaExportDisplayPath._();

  /// Example: `\u200Eהורדות > PrivateVideoDownloader\u200E` or `\u200EDownloads > PrivateVideoDownloader\u200E`.
  static String downloadsThenFolder(AppLocalizations l10n, String folderName) {
    final d = l10n.mediaExportDownloadsWord.trim();
    final f = folderName.trim();
    return "\u200e$d > $f\u200e";
  }
}
