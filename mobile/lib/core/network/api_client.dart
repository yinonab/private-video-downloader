import "dart:developer" as dev;
import "dart:io" show File, HttpHeaders, SocketException;
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:http_parser/http_parser.dart";
import "package:path/path.dart" as p;

import "../config/build_flags.dart";
import "../models/analyze_models.dart";
import "../models/api_error.dart";
import "../models/device_models.dart";
import "../models/download_models.dart";
import "../models/quick_edit_models.dart";
import "../models/upload_models.dart";
import "../storage/local_session.dart";

String _trimJoin(String base, String suffixPath) {
  var b = base.trimRight().replaceAll(RegExp(r"/+$"), "");
  final s = suffixPath.startsWith("/") ? suffixPath : "/$suffixPath";
  return "$b$s";
}

/// Result of streaming `GET /downloads/:jobId/file` to disk.
final class JobFileDownloadResult {
  const JobFileDownloadResult({
    required this.statusCode,
    required this.url,
    this.contentLength,
  });

  final int statusCode;
  final String url;

  /// Value of `Content-Length` when the server sends it (chunked responses omit it).
  final int? contentLength;
}

class ApiClient {
  ApiClient({required LocalSession session}) : _session = session {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 45),
        receiveTimeout: const Duration(seconds: 120),
        sendTimeout: const Duration(seconds: 120),
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

  String get _base => _session.effectiveApiBaseUrl;

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
    final payload = body.toJson();
    regDebugPrint("before POST /devices/register");
    regDebugPrint("request body keys=${payload.keys.join(",")}");
    try {
      final res = await _dio.post(uri, data: payload);
      regDebugPrint("register response status=${res.statusCode}");
      regDebugPrint("register response body=${res.data}");
      final data = res.data;
      return RegisterDeviceResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null);
    } on DioException catch (e, st) {
      regDebugPrint("register failed type=DioException");
      regDebugPrint("error message=$e");
      regDebugPrint("DioException type=${e.type}");
      regDebugPrint("DioException response status=${e.response?.statusCode}");
      regDebugPrint("DioException response body=${e.response?.data}");
      final cause = e.error;
      if (cause is SocketException) {
        regDebugPrint("SocketException=$cause");
      }
      regDebugPrint("stack=$st");
      throw ApiError.fromDio(e);
    } catch (e, st) {
      regDebugPrint("register failed type=${e.runtimeType}");
      regDebugPrint("error message=$e");
      regDebugPrint("stack=$st");
      rethrow;
    }
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

  /// Absolute HTTP URL for streaming the finished media file (logging / diagnostics).
  String downloadFileUrl(String jobId) => _trimJoin(_base, "/downloads/$jobId/file");

  /// Absolute HTTP URL for `GET /edits/:id/file`.
  String editFileUrl(String editJobId) => _trimJoin(_base, "/edits/$editJobId/file");

  /// Multipart upload (`field`: `file`). Streams from disk — does not load entire file into memory.
  ///
  /// Phase C3+ may pass [mimeType] / [filename] from pickers; omitted keys use file basename.
  Future<UploadVideoResponse> uploadVideo({
    required String filePath,
    String? filename,
    String? mimeType,
  }) async {
    final f = File(filePath);
    if (!await f.exists()) {
      throw ApiError(code: "BAD_REQUEST", message: "File not found");
    }
    final name = (filename != null && filename.trim().isNotEmpty)
        ? filename.trim()
        : p.basename(filePath);

    final mt = mimeType?.trim();
    final multipart = await MultipartFile.fromFile(
      filePath,
      filename: name,
      contentType: (mt != null && mt.isNotEmpty) ? MediaType.parse(mt) : null,
    );
    final formData = FormData.fromMap({"file": multipart});

    return _unwrap(
      _dio.post(
        _trimJoin(_base, "/uploads/videos"),
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 25),
          receiveTimeout: const Duration(seconds: 120),
        ),
      ),
      (data) => UploadVideoResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<CreateEditJobResponse> createEditJob(CreateEditJobRequest body) async {
    return _unwrap(
      _dio.post(_trimJoin(_base, "/edits"), data: body.toJson()),
      (data) => CreateEditJobResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  /// Long-running: synchronous server transcription over full trimmed timeline.
  Future<CaptionDraftResponse> generateCaptionsDraft(GenerateCaptionsDraftRequest body) async {
    return _unwrap(
      _dio.post(
        _trimJoin(_base, "/edits/captions/draft"),
        data: body.toJson(),
        options: Options(
          sendTimeout: const Duration(minutes: 35),
          receiveTimeout: const Duration(minutes: 35),
        ),
      ),
      (data) => CaptionDraftResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<EditJobDetailResponse> getEditJob(String editJobId) async {
    return _unwrap(
      _dio.get(_trimJoin(_base, "/edits/$editJobId")),
      (data) => EditJobDetailResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  Future<RetryEditJobResponse> retryEditJob(String editJobId) async {
    return _unwrap(
      _dio.post(_trimJoin(_base, "/edits/$editJobId/retry")),
      (data) => RetryEditJobResponse.fromJson(data is Map ? Map<String, dynamic>.from(data) : null),
    );
  }

  static int? _parseContentLength(Response<dynamic> response) {
    final raw = response.headers.value(HttpHeaders.contentLengthHeader) ??
        response.headers.value("content-length");
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  /// Streams authorized binary GET into [absolutePath] (works for `/downloads/…/file` and `/edits/…/file`).
  Future<JobFileDownloadResult> _downloadAuthorizedBinaryToPath({
    required String url,
    required String absolutePath,
    required String debugLabel,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final tokenExists = _session.deviceToken.trim().isNotEmpty;
    final bearer = tokenExists ? "Bearer ${_session.deviceToken.trim()}" : null;

    dev.log("dio_download: start url=$url savePath=$absolutePath label=$debugLabel");
    downloadDebugPrint(
      "$debugLabel baseUrl=$_base finalFileUrl=$url tokenExists=$tokenExists tempPartPath=$absolutePath",
    );

    Uint8List decodeBody(List<int>? body) {
      if (body == null) return Uint8List(0);
      if (body is Uint8List) return body;
      return Uint8List.fromList(body);
    }

    try {
      downloadDebugPrint("before GET bytes (manual save) url=$url");

      final response = await _dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(hours: 6),
          sendTimeout: const Duration(minutes: 30),
          followRedirects: true,
          validateStatus: (code) => code != null && code >= 200 && code < 300,
          headers: bearer != null ? <String, dynamic>{HttpHeaders.authorizationHeader: bearer} : null,
        ),
        onReceiveProgress: onReceiveProgress == null
            ? null
            : (received, total) {
                downloadDebugPrint("GET bytes progress received=$received total=$total");
                onReceiveProgress(received, total);
              },
      );

      final statusCode = response.statusCode ?? 0;
      final parsedCl = _parseContentLength(response);
      final bytes = decodeBody(response.data);
      final hdrMap = response.headers.map;
      final ct = response.headers.value(HttpHeaders.contentTypeHeader);
      final clHdrRaw = response.headers.value(HttpHeaders.contentLengthHeader);

      downloadDebugPrint(
        "diagnostic GET bytes statusCode=$statusCode headers=$hdrMap "
        "contentType=$ct contentLength=$clHdrRaw dataLength=${bytes.length}",
      );
      if (bytes.isEmpty) {
        downloadDebugPrint("firstBytes=(empty)");
      } else {
        final n = bytes.length < 16 ? bytes.length : 16;
        downloadDebugPrint("firstBytes=${bytes.sublist(0, n)}");
      }

      final out = File(absolutePath);
      await out.parent.create(recursive: true);
      await out.writeAsBytes(bytes, flush: true);

      downloadDebugPrint(
        "wrote part file path=$absolutePath bytesWritten=${bytes.length} "
        "(manual GET bytes, not Dio.download)",
      );

      final effectiveCl =
          (parsedCl != null && parsedCl > 0) ? parsedCl : (bytes.isNotEmpty ? bytes.length : null);

      dev.log(
        "dio_download: complete status=$statusCode contentLengthHeader=$parsedCl bytesWritten=${bytes.length} url=$url",
      );
      downloadDebugPrint(
        "manual download completed statusCode=$statusCode "
        "contentLengthHeader=$parsedCl bytesWritten=${bytes.length} url=$url",
      );

      return JobFileDownloadResult(
        statusCode: statusCode,
        url: url,
        contentLength: effectiveCl,
      );
    } on DioException catch (e, st) {
      downloadDebugPrint(
        "catch $debugLabel DioException type=${e.type} message=${e.message} "
        "responseStatus=${e.response?.statusCode} cancelTokenCancelled=${e.requestOptions.cancelToken?.isCancelled}",
      );
      downloadDebugStackTrace(debugLabel, st);
      throw ApiError(
        code: "DEVICE_FILE_DOWNLOAD",
        message: e.message ?? "${e.type}",
        hebrewSummary: "הורדת הקובץ למכשיר נכשלה. נסה שוב.",
        httpStatus: e.response?.statusCode,
      );
    }
  }

  /// Downloads job media to [absolutePath] via `GET …/file` with [ResponseType.bytes], then writes to disk.
  ///
  /// Avoids [Dio.download] here: a shared [Dio] with [BaseOptions.responseType] = JSON can yield HTTP 200 but
  /// 0 bytes written for binary endpoints on some platforms.
  Future<JobFileDownloadResult> downloadJobFileToPath({
    required String jobId,
    required String absolutePath,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final url = downloadFileUrl(jobId);
    return _downloadAuthorizedBinaryToPath(
      url: url,
      absolutePath: absolutePath,
      debugLabel: "downloadJobFileToPath jobId=$jobId",
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Downloads edited MP4 from `GET /edits/:editJobId/file`.
  Future<JobFileDownloadResult> downloadEditFileToPath({
    required String editJobId,
    required String absolutePath,
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final url = editFileUrl(editJobId);
    return _downloadAuthorizedBinaryToPath(
      url: url,
      absolutePath: absolutePath,
      debugLabel: "downloadEditFileToPath editJobId=$editJobId",
      onReceiveProgress: onReceiveProgress,
    );
  }
}
