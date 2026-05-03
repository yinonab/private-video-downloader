import "../core/models/download_models.dart";
import "../core/network/api_client.dart";

final class DownloadService {
  DownloadService(this._api);
  final ApiClient _api;

  Future<DownloadsListResponse> list({int page = 1, int limit = 40}) =>
      _api.listDownloads(page: page, limit: limit);

  Future<CreateDownloadResponse> create(CreateDownloadRequest body) => _api.createDownload(body);

  Future<DownloadDetailResponse> detail(String id) => _api.downloadDetail(id);

  Future<void> delete(String id) => _api.deleteDownload(id);

  Future<CreateDownloadResponse> retry(String id) => _api.retryDownload(id);
}
