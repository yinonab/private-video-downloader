import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";

import "local_edit_history_item.dart";

/// Persists edit-output metadata as JSON under app support dir (no MP4 duplication).
final class LocalEditHistoryStore extends ChangeNotifier {
  LocalEditHistoryStore();

  static const _fileName = "local_edit_history_v1.json";
  static const _schemaVersion = 1;
  static const _maxEntries = 500;

  List<LocalEditHistoryItem> _items = [];

  List<LocalEditHistoryItem> get items => List.unmodifiable(_items);

  Future<void> hydrate() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File("${dir.path}/$_fileName");
      if (!await file.exists()) {
        _items = [];
        notifyListeners();
        return;
      }
      final text = await file.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        _items = [];
      } else if (decoded["schemaVersion"] != _schemaVersion) {
        _items = [];
      } else {
        final rawList = decoded["items"];
        if (rawList is! List<dynamic>) {
          _items = [];
        } else {
          _items = rawList
              .whereType<Map>()
              .map((e) => LocalEditHistoryItem.fromJson(Map<String, dynamic>.from(e)))
              .where((e) => e.editJobId.isNotEmpty && e.localFilePath.trim().isNotEmpty)
              .toList();
        }
      }
    } catch (_) {
      _items = [];
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File("${dir.path}/$_fileName");
      final payload = <String, dynamic>{
        "schemaVersion": _schemaVersion,
        "items": _items.map((e) => e.toJson()).toList(),
      };
      await file.writeAsString(jsonEncode(payload));
    } catch (_) {}
  }

  Future<bool> _isUnderAppDocumentsEdits(String candidate) async {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) return false;
    final docs = await getApplicationDocumentsDirectory();
    final editsDir = p.normalize(p.join(docs.path, "edits"));
    final norm = p.normalize(trimmed);
    final sep = p.separator;
    final prefix = editsDir.endsWith(sep) ? editsDir : "$editsDir$sep";
    return norm == editsDir || norm.startsWith(prefix);
  }

  void _dedupeAndTrim() {
    final byId = <String, LocalEditHistoryItem>{};
    for (final e in _items) {
      final o = byId[e.editJobId];
      if (o == null || e.savedAt.isAfter(o.savedAt)) {
        byId[e.editJobId] = e;
      }
    }
    _items = byId.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (_items.length > _maxEntries) {
      _items = _items.sublist(0, _maxEntries);
    }
  }

  /// Call after [FileDownloadService.downloadEditedOutput] succeeds — file must exist.
  Future<void> recordCompletedEdit({
    required String editJobId,
    required String localFilePath,
    required String sourceKind,
    required String title,
    String? completedAtIso,
    int? sizeBytes,
    int? durationSeconds,
    int? width,
    int? height,
    String? originalSourceTitle,
    String? sourceDisplayFilename,
    String? platform,
  }) async {
    final id = editJobId.trim();
    final path = localFilePath.trim();
    if (id.isEmpty || path.isEmpty) return;

    final file = File(path);
    if (!await file.exists()) return;

    final len = sizeBytes ?? await file.length();
    if (len <= 0) return;

    var storedTitle = title.trim();
    if (storedTitle.isEmpty) {
      storedTitle = _basename(path);
    }

    final existingIdx = _items.indexWhere((e) => e.editJobId == id);
    final published = existingIdx >= 0 ? _items[existingIdx].publishedToPublicDownloads : false;

    String? thumbKeep;
    if (existingIdx >= 0) {
      final prev = _items[existingIdx].thumbnailPath?.trim();
      if (prev != null && prev.isNotEmpty && await File(prev).exists()) {
        thumbKeep = prev;
      }
    }

    final entry = LocalEditHistoryItem(
      editJobId: id,
      localFilePath: path,
      title: storedTitle,
      sourceKind: sourceKind.trim().isEmpty ? "unknown" : sourceKind.trim(),
      savedAt: DateTime.now(),
      completedAtIso: completedAtIso,
      sizeBytes: len,
      durationSeconds: durationSeconds,
      width: width,
      height: height,
      originalSourceTitle: originalSourceTitle,
      sourceDisplayFilename: sourceDisplayFilename,
      platform: platform,
      thumbnailPath: thumbKeep,
      publishedToPublicDownloads: published,
    );

    if (existingIdx >= 0) {
      _items[existingIdx] = entry;
    } else {
      _items.insert(0, entry);
    }

    _dedupeAndTrim();
    await _persist();
    notifyListeners();
  }

  String _basename(String path) {
    final normalized = path.replaceAll("\\", "/");
    final i = normalized.lastIndexOf("/");
    return i >= 0 ? normalized.substring(i + 1) : normalized;
  }

  Future<void> updateThumbnailPath(String editJobId, String thumbnailPath) async {
    final id = editJobId.trim();
    final tp = thumbnailPath.trim();
    if (id.isEmpty || tp.isEmpty) return;
    final idx = _items.indexWhere((e) => e.editJobId == id);
    if (idx < 0) return;
    final old = _items[idx];
    if (old.thumbnailPath?.trim() == tp) return;
    _items[idx] = LocalEditHistoryItem(
      editJobId: old.editJobId,
      localFilePath: old.localFilePath,
      title: old.title,
      sourceKind: old.sourceKind,
      savedAt: old.savedAt,
      completedAtIso: old.completedAtIso,
      sizeBytes: old.sizeBytes,
      durationSeconds: old.durationSeconds,
      width: old.width,
      height: old.height,
      originalSourceTitle: old.originalSourceTitle,
      sourceDisplayFilename: old.sourceDisplayFilename,
      platform: old.platform,
      thumbnailPath: tp,
      publishedToPublicDownloads: old.publishedToPublicDownloads,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> markPublishedToPublicDownloads(String editJobId) async {
    final id = editJobId.trim();
    if (id.isEmpty) return;
    final idx = _items.indexWhere((e) => e.editJobId == id);
    if (idx < 0) return;
    final old = _items[idx];
    _items[idx] = LocalEditHistoryItem(
      editJobId: old.editJobId,
      localFilePath: old.localFilePath,
      title: old.title,
      sourceKind: old.sourceKind,
      savedAt: old.savedAt,
      completedAtIso: old.completedAtIso,
      sizeBytes: old.sizeBytes,
      durationSeconds: old.durationSeconds,
      width: old.width,
      height: old.height,
      originalSourceTitle: old.originalSourceTitle,
      sourceDisplayFilename: old.sourceDisplayFilename,
      platform: old.platform,
      thumbnailPath: old.thumbnailPath,
      publishedToPublicDownloads: true,
    );
    await _persist();
    notifyListeners();
  }

  /// Deletes the app-private edited MP4 under `documents/edits/`, cached thumbnail, and metadata.
  /// Does not touch public Downloads / MediaStore exports.
  Future<void> deleteEditOutputFromApp(String editJobId) async {
    final id = editJobId.trim();
    if (id.isEmpty) return;
    final idx = _items.indexWhere((e) => e.editJobId == id);
    if (idx < 0) return;
    final item = _items[idx];

    final thumb = item.thumbnailPath?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      try {
        await File(thumb).delete();
      } catch (_) {}
    }

    final vp = item.localFilePath.trim();
    if (vp.isNotEmpty && await _isUnderAppDocumentsEdits(vp)) {
      try {
        await File(vp).delete();
      } catch (_) {}
    }

    _items.removeAt(idx);
    await _persist();
    notifyListeners();
  }

  Future<void> removeByEditJobId(String editJobId) async {
    final id = editJobId.trim();
    if (id.isEmpty) return;
    _items.removeWhere((e) => e.editJobId == id);
    await _persist();
    notifyListeners();
  }
}
