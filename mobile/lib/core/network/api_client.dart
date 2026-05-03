import "package:dio/dio.dart";

import "../models/analyze_models.dart";
import "../models/api_error.dart";
import "../models/device_models.dart";
import "../models/download_models.dart";
import "../storage/local_session.dart";

String _trimJoin(String base, String suffixPath) {
  var b = base.trimRight().replaceAll(RegExp(r"/+$"), "");
  final s = suffixPath.startsWith("/") ? suffixPath : "/$suffixPath";
  return "$b$s";
}

class ApiClient {
  ApiClient({required LocalSession session}) : _session = session {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 120),
        responseType: ResponseType.json,
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final uriStr = "${options.uri}";
          final isRegister = uriStr.endsWith("/devices/register") || uriStr.contains("/devices/register?");
          if (!isRegister && _session.deviceToken.trim().isNotEmpty) {
            options.headers.putIfAbsent("Authorization", () => "Bearer ${_session.deviceToken.trim()}");
          }
          return handler.next(options);
        },
      ),
    );
  }

  final LocalSession _session;
  late final Dio _dio;

  String get _base => _session.serverUrl.trim();

  Future<T> _unwrap<T>(
    Future<Response<dynamic>> future,
    T Function(dynamic data) map,
  ) async {
    try {
      final res = await future;
      return map(res.data);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  static String normalizeServerInput(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return "";
    final withScheme = (!s.startsWith("http://") && !s.startsWith("https://")) ? "http://$s" : s;
    var o = withScheme;
    while (o.endsWith("/")) {
      o = o.substring(0, o.length - 1);
    }
    return o;
  }

  Future<RegisterDeviceResponse> register(RegisterDeviceRequest body, String normalizedServerUrl) async {
    final b =
        normalizeServerInput(normalizedServerUrl).trimRight().replaceAll(RegExp(r"/+$"), "");
    final uri = "$b/devices/register";
    return _unwrap(
      _dio.post(uri, data: body.toJson()),
      (data) => RegisterDeviceResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<DeviceMeResponse> deviceMe() async {
    return _unwrap(
      _dio.get(_trimJoin(_base, "/devices/me")),
      (data) => DeviceMeResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<AnalyzeResponse> analyze(String url) async {
    return _unwrap(
      _dio.post(_trimJoin(_base, "/analyze"), data: {"url": url}),
      (data) => AnalyzeResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<DownloadsListResponse> listDownloads({int page = 1, int limit = 40}) async {
    return _unwrap(
      _dio.get(_trimJoin(_base, "/downloads?page=$page&limit=$limit")),
      (data) => DownloadsListResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<CreateDownloadResponse> createDownload(CreateDownloadRequest req) async {
    return _unwrap(
      _dio.post(_trimJoin(_base, "/downloads"), data: req.toJson()),
      (data) => CreateDownloadResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<DownloadDetailResponse> downloadDetail(String id) async {
    return _unwrap(
      _dio.get(_trimJoin(_base, "/downloads/$id")),
      (data) => DownloadDetailResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<void> deleteDownload(String id) async {
    try {
      await _dio.delete(_trimJoin(_base, "/downloads/$id"));
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }

  Future<CreateDownloadResponse> retryDownload(String id) async {
    return _unwrap(
      _dio.post(_trimJoin(_base, "/downloads/$id/retry")),
      (data) => CreateDownloadResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<void> downloadFileToDisk({
    required String jobId,
    required String absolutePath,
    void Function(int received, int total)? onProgress,
  }) async {
    final url = _trimJoin(_base, "/downloads/$jobId/file");
    try {
      await _dio.download(url, absolutePath, onReceiveProgress: onProgress);
    } on DioException catch (e) {
      throw ApiError.fromDio(e);
    }
  }
}
