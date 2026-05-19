import "package:path/path.dart" as p;

import "../../l10n/app_localizations.dart";
import "local_edit_history_item.dart";

final RegExp _uuidFileBase = RegExp(
  r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
);

/// True when [filename] looks like a bare UUID used as the download/edit basename.
bool editHistoryOutputLooksLikeUuidFilename(String filename) {
  final base = p.basenameWithoutExtension(filename.trim());
  return _uuidFileBase.hasMatch(base);
}

/// Display title for Edits list (does not mutate metadata).
String resolveEditHistoryDisplayTitle(AppLocalizations l10n, LocalEditHistoryItem item) {
  final orig = item.originalSourceTitle?.trim();
  if (orig != null && orig.isNotEmpty) return orig;

  final srcFile = item.sourceDisplayFilename?.trim();
  if (srcFile != null && srcFile.isNotEmpty) return srcFile;

  final storedTitle = item.title.trim();
  if (storedTitle.isNotEmpty && !editHistoryOutputLooksLikeUuidFilename(storedTitle)) {
    return storedTitle;
  }

  final fromPath = p.basename(item.localFilePath.trim());
  if (fromPath.isNotEmpty && !editHistoryOutputLooksLikeUuidFilename(fromPath)) {
    return fromPath;
  }

  return l10n.editedVideoFallbackTitle;
}
