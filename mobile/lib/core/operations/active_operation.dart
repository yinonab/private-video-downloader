import "dart:convert";

/// V1 long-operation types with backend [backendJobId] resume support.
enum OperationType {
  sourceDownload,
  editExport,
}

enum OperationStatus {
  starting,
  running,
  waitingForServer,
  downloadingResult,
  savingToDevice,
  success,
  failed,
  cancelled,
}

/// Persisted in-flight download or edit/export job (one primary operation in V1).
final class ActiveOperation {
  const ActiveOperation({
    required this.localOperationId,
    required this.type,
    this.backendJobId,
    this.sourceTitle,
    this.sourceThumbnailUrl,
    required this.status,
    this.progressPercent,
    this.stage,
    this.errorCode,
    required this.startedAt,
    required this.updatedAt,
    this.screenToRestore,
    this.payload,
  });

  final String localOperationId;
  final OperationType type;
  final String? backendJobId;
  final String? sourceTitle;
  final String? sourceThumbnailUrl;
  final OperationStatus status;
  final int? progressPercent;
  final String? stage;
  final String? errorCode;
  final DateTime startedAt;
  final DateTime updatedAt;
  final String? screenToRestore;
  final Map<String, dynamic>? payload;

  bool get isNonTerminal =>
      status != OperationStatus.success &&
      status != OperationStatus.failed &&
      status != OperationStatus.cancelled;

  bool get hasBackendJobId =>
      backendJobId != null && backendJobId!.trim().isNotEmpty;

  ActiveOperation copyWith({
    String? localOperationId,
    OperationType? type,
    String? backendJobId,
    String? sourceTitle,
    String? sourceThumbnailUrl,
    OperationStatus? status,
    int? progressPercent,
    String? stage,
    String? errorCode,
    DateTime? startedAt,
    DateTime? updatedAt,
    String? screenToRestore,
    Map<String, dynamic>? payload,
    bool clearErrorCode = false,
  }) {
    return ActiveOperation(
      localOperationId: localOperationId ?? this.localOperationId,
      type: type ?? this.type,
      backendJobId: backendJobId ?? this.backendJobId,
      sourceTitle: sourceTitle ?? this.sourceTitle,
      sourceThumbnailUrl: sourceThumbnailUrl ?? this.sourceThumbnailUrl,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      stage: stage ?? this.stage,
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      screenToRestore: screenToRestore ?? this.screenToRestore,
      payload: payload ?? this.payload,
    );
  }

  Map<String, dynamic> toJson() => {
        "localOperationId": localOperationId,
        "type": type.name,
        "backendJobId": backendJobId,
        "sourceTitle": sourceTitle,
        "sourceThumbnailUrl": sourceThumbnailUrl,
        "status": status.name,
        "progressPercent": progressPercent,
        "stage": stage,
        "errorCode": errorCode,
        "startedAt": startedAt.toUtc().toIso8601String(),
        "updatedAt": updatedAt.toUtc().toIso8601String(),
        "screenToRestore": screenToRestore,
        "payload": payload,
      };

  factory ActiveOperation.fromJson(Map<String, dynamic> json) {
    try {
      return ActiveOperation(
        localOperationId: "${json["localOperationId"] ?? ""}",
        type: OperationType.values.byName("${json["type"]}"),
        backendJobId: json["backendJobId"]?.toString(),
        sourceTitle: json["sourceTitle"]?.toString(),
        sourceThumbnailUrl: json["sourceThumbnailUrl"]?.toString(),
        status: OperationStatus.values.byName("${json["status"]}"),
        progressPercent: json["progressPercent"] is num
            ? (json["progressPercent"] as num).round()
            : null,
        stage: json["stage"]?.toString(),
        errorCode: json["errorCode"]?.toString(),
        startedAt: DateTime.parse("${json["startedAt"]}").toUtc(),
        updatedAt: DateTime.parse("${json["updatedAt"]}").toUtc(),
        screenToRestore: json["screenToRestore"]?.toString(),
        payload: json["payload"] is Map
            ? Map<String, dynamic>.from(json["payload"] as Map)
            : null,
      );
    } catch (_) {
      throw const FormatException("invalid ActiveOperation json");
    }
  }

  static String encode(ActiveOperation op) => jsonEncode(op.toJson());

  static ActiveOperation? decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ActiveOperation.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
