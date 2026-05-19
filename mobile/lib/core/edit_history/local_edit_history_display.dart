import "dart:io";

import "local_edit_history_item.dart";
import "local_edit_history_time_filter.dart";

/// ~500MB cap applies only to rows whose file still exists (display-only).
const int kEditHistoryDisplayMaxBytes = 500 * 1024 * 1024;

final class ResolvedEditHistoryRow {
  const ResolvedEditHistoryRow({
    required this.item,
    required this.fileExists,
    this.resolvedSizeBytes,
  });

  final LocalEditHistoryItem item;
  final bool fileExists;
  final int? resolvedSizeBytes;
}

/// Newest first; missing files included (no MB cost); existing files until ~500MB total.
Future<List<ResolvedEditHistoryRow>> resolveEditHistoryForDisplay({
  required List<LocalEditHistoryItem> items,
  required LocalEditHistoryTimeFilter timeFilter,
}) async {
  final cutoff = editHistoryFilterCutoff(timeFilter);
  var filtered = items;
  if (cutoff != null) {
    filtered = items.where((e) => !e.savedAt.isBefore(cutoff)).toList();
  }
  filtered.sort((a, b) => b.savedAt.compareTo(a.savedAt));

  final out = <ResolvedEditHistoryRow>[];
  var usedBytes = 0;

  for (final e in filtered) {
    final path = e.localFilePath.trim();
    if (path.isEmpty) continue;

    final exists = await File(path).exists();
    if (!exists) {
      out.add(ResolvedEditHistoryRow(item: e, fileExists: false));
      continue;
    }

    final sz = e.sizeBytes ?? await File(path).length();
    if (usedBytes + sz <= kEditHistoryDisplayMaxBytes) {
      out.add(ResolvedEditHistoryRow(item: e, fileExists: true, resolvedSizeBytes: sz));
      usedBytes += sz;
    }
  }

  return out;
}
