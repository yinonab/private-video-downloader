import "package:flutter/foundation.dart";

import "../models/download_models.dart";
import "../storage/local_session.dart";

CreateDownloadRequest? createDownloadRequestFromRedownloadFields({
  required String sourceUrl,
  String? format,
  String? quality,
}) {
  final url = sourceUrl.trim();
  if (url.isEmpty) return null;
  final fmtRaw = (format ?? "").trim();
  final fmt = fmtRaw.isEmpty ? "best" : fmtRaw;
  final qRaw = (quality ?? "").trim();
  final q = qRaw.isEmpty ? fmt : qRaw;
  return CreateDownloadRequest(url: url, format: fmt, quality: q);
}

CreateDownloadRequest? createDownloadRequestFromDetail(DownloadDetailResponse d) {
  final u = d.sourceUrl?.trim();
  if (u == null || u.isEmpty) return null;
  return createDownloadRequestFromRedownloadFields(
    sourceUrl: u,
    format: d.requestedFormat,
    quality: d.requestedQuality,
  );
}

CreateDownloadRequest? createDownloadRequestFromListItem(DownloadItem item) {
  final u = item.sourceUrl?.trim();
  if (u == null || u.isEmpty) return null;
  return createDownloadRequestFromRedownloadFields(
    sourceUrl: u,
    format: item.requestedFormat,
    quality: item.requestedQuality,
  );
}

Future<void> backfillStoredCreateRequestIfAbsent(
  LocalSession session,
  String jobId,
  CreateDownloadRequest req,
) async {
  final id = jobId.trim();
  if (id.isEmpty) return;
  final existing = await session.storedCreateDownloadRequest(id);
  if (existing != null) return;
  await session.rememberDownloadCreateRequest(id, req);
}

Future<void> tryBackfillStoredRequestFromDetail(
  LocalSession session,
  DownloadDetailResponse d,
) async {
  final req = createDownloadRequestFromDetail(d);
  if (req == null) return;
  await backfillStoredCreateRequestIfAbsent(session, d.id, req);
}

Future<void> tryBackfillStoredRequestFromListItem(
  LocalSession session,
  DownloadItem item,
) async {
  final req = createDownloadRequestFromListItem(item);
  if (req == null) return;
  await backfillStoredCreateRequestIfAbsent(session, item.id, req);
}

/// Resolves [CreateDownloadRequest] for re-download after server-side source expiry.
///
/// Priority: local prefs → prefetched API shapes → `GET /downloads/:id`.
Future<CreateDownloadRequest?> resolveRedownloadRequestForJob({
  required LocalSession session,
  required Future<DownloadDetailResponse> Function(String jobId) fetchDetail,
  required String jobId,
  DownloadDetailResponse? prefetchedDetail,
  DownloadItem? prefetchedItem,
}) async {
  final id = jobId.trim();
  if (id.isEmpty) return null;

  final stored = await session.storedCreateDownloadRequest(id);
  if (stored != null) {
    assert(() {
      if (kDebugMode) debugPrint("redownload_resolve jobId=$id source=stored");
      return true;
    }());
    return stored;
  }

  if (prefetchedDetail != null && prefetchedDetail.id.trim() == id) {
    final req = createDownloadRequestFromDetail(prefetchedDetail);
    if (req != null) {
      await session.rememberDownloadCreateRequest(id, req);
      assert(() {
        if (kDebugMode) debugPrint("redownload_resolve jobId=$id source=prefetch_detail");
        return true;
      }());
      return req;
    }
  }

  if (prefetchedItem != null && prefetchedItem.id.trim() == id) {
    final req = createDownloadRequestFromListItem(prefetchedItem);
    if (req != null) {
      await session.rememberDownloadCreateRequest(id, req);
      assert(() {
        if (kDebugMode) debugPrint("redownload_resolve jobId=$id source=prefetch_list");
        return true;
      }());
      return req;
    }
  }

  try {
    final d = await fetchDetail(id);
    final req = createDownloadRequestFromDetail(d);
    if (req != null) {
      await session.rememberDownloadCreateRequest(id, req);
      assert(() {
        if (kDebugMode) debugPrint("redownload_resolve jobId=$id source=api_detail");
        return true;
      }());
      return req;
    }
  } catch (_) {
    assert(() {
      if (kDebugMode) debugPrint("redownload_resolve jobId=$id source=api_detail_failed");
      return true;
    }());
  }

  assert(() {
    if (kDebugMode) debugPrint("redownload_resolve jobId=$id source=missing");
    return true;
  }());
  return null;
}
