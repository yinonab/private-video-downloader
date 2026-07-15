import "package:flutter/foundation.dart";

import "../config/build_flags.dart";
import "active_operation.dart";

/// Debug-only active operation tracing (no URLs, tokens, or caption text).
void operationDebugPrint(String message) {
  assert(() {
    if (kDebugMode) {
      downloadDebugPrint("active_operation: $message");
    }
    return true;
  }());
}

void operationDebugActive(String event, ActiveOperation? op) {
  if (op == null) {
    operationDebugPrint("$event op=null");
    return;
  }
  operationDebugPrint(
    "$event type=${op.type.name} status=${op.status.name} "
    "jobId=${op.backendJobId ?? "(none)"} progress=${op.progressPercent} "
    "stage=${op.stage ?? "-"} localId=${op.localOperationId.substring(0, 8)}",
  );
}
